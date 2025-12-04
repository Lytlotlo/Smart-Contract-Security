// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Imports
import { IRouterClient } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
// FIX: Changed from deep Chainlink vendor paths to standard OpenZeppelin paths
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract CCIPTokenSender is Ownable {
    using SafeERC20 for IERC20;

    // State Variables (Sepolia Addresses)
    // In a real audit, these should be immutable or updateable!
    IRouterClient private constant CCIP_ROUTER = IRouterClient(0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59);
    IERC20 private constant LINK_TOKEN = IERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789);
    IERC20 private constant USDC_TOKEN = IERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    
    // Base Sepolia Chain Selector
    uint64 private constant DESTINATION_CHAIN_SELECTOR = 10344971235874465080;

    // Custom Errors
    error CCIPTokenSender__InsufficientBalance(address token, uint256 balance, uint256 required);
    error CCIPTokenSender__NothingToWithdraw();

    // Event
    event USDCTransferred(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        uint256 amount,
        uint256 fees
    );

    // 🛠️ Explicitly passing msg.sender to Ownable for clarity and version compatibility
    constructor() Ownable(msg.sender) {} 

    // 🌉 The Main Function
    function transferTokens(
        address _receiver,
        uint256 _amount
    ) external returns (bytes32 messageId) {
        
        // 1. Check User Balance
        if (_amount > USDC_TOKEN.balanceOf(msg.sender)) {
            revert CCIPTokenSender__InsufficientBalance(address(USDC_TOKEN), USDC_TOKEN.balanceOf(msg.sender), _amount);
        }

        // 2. Prepare Token Amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(USDC_TOKEN),
            amount: _amount
        });

        // 3. Build Message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "", // Token only, no extra data
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0}) // No code execution on destination
            ),
            feeToken: address(LINK_TOKEN)
        });

        // 4. Calculate & Approve Fees
        uint256 ccipFee = CCIP_ROUTER.getFee(DESTINATION_CHAIN_SELECTOR, message);
        
        if (ccipFee > LINK_TOKEN.balanceOf(address(this))) {
            revert CCIPTokenSender__InsufficientBalance(address(LINK_TOKEN), LINK_TOKEN.balanceOf(address(this)), ccipFee);
        }
        
        LINK_TOKEN.approve(address(CCIP_ROUTER), ccipFee);

        // 5. Pull USDC from User -> Contract
        USDC_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        
        // 6. Approve Router to take USDC from Contract
        USDC_TOKEN.approve(address(CCIP_ROUTER), _amount);

        // 7. Send!
        messageId = CCIP_ROUTER.ccipSend(DESTINATION_CHAIN_SELECTOR, message);

        emit USDCTransferred(messageId, DESTINATION_CHAIN_SELECTOR, _receiver, _amount, ccipFee);
    }

    // Emergency Withdraw
    function withdrawToken(address _beneficiary) public onlyOwner {
        uint256 amount = IERC20(USDC_TOKEN).balanceOf(address(this));
        if (amount == 0) revert CCIPTokenSender__NothingToWithdraw();
        IERC20(USDC_TOKEN).transfer(_beneficiary, amount);
    }
}
