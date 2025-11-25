// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Imports
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { Ownable } from "@openzeppelin/contracts@4.6.0/access/Ownable.sol";
import { MyERC20 } from "./MyERC20.sol"; // Importing your Token Contract

contract TokenShop is Ownable {
    
    // State Variables
    AggregatorV3Interface internal immutable i_priceFeed;
    MyERC20 public immutable i_token;
    
    // Constants
    uint256 public constant TOKEN_DECIMALS = 18;
    // We set the price of 1 AISEC Token = $2.00 USD
    uint256 public constant TOKEN_USD_PRICE = 2 * 10 ** 18; 

    // Errors
    error TokenShop__ZeroETHSent();
    error TokenShop__CouldNotWithdraw();

    // Constructor
    // We pass in the address of the AISEC Token we deployed earlier
    constructor(address tokenAddress) {
        i_token = MyERC20(tokenAddress);
        
        // Sepolia ETH/USD Price Feed Address
        i_priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    // The "Buy Button" (Receive Function)
    // This runs automatically when someone sends ETH to this contract
    receive() external payable {
        if (msg.value == 0) {
            revert TokenShop__ZeroETHSent();
        }
        
        // 1. Calculate how many tokens they get
        uint256 amount = amountToMint(msg.value);
        
        // 2. Mint the tokens to them
        // NOTE: This contract needs MINTER_ROLE on the MyERC20 contract to work!
        i_token.mint(msg.sender, amount);
    }

    // The Math Engine
    function amountToMint(uint256 amountInETH) public view returns (uint256) {
        // 1. Get ETH price from Chainlink (e.g., $3000.00000000)
        uint256 ethUsd = uint256(getChainlinkDataFeedLatestAnswer());
        
        // 2. Convert everything to 18 decimals for precision
        // Chainlink returns 8 decimals, so we multiply by 10^10 to get to 18.
        uint256 ethPriceIn18Decimals = ethUsd * 10 ** 10;
        
        // 3. Calculate value of ETH sent in USD
        uint256 ethAmountInUSD = (amountInETH * ethPriceIn18Decimals) / 10 ** 18;
        
        // 4. Calculate how many tokens that buys ($Total / $PricePerToken)
        uint256 amountOfTokens = (ethAmountInUSD * 10 ** TOKEN_DECIMALS) / TOKEN_USD_PRICE;
        
        return amountOfTokens;
    }

    // Helper to talk to Chainlink
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = i_priceFeed.latestRoundData();
        return price;
    }

    // Withdraw Function (So you can take the ETH earnings)
    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        if (!success) {
            revert TokenShop__CouldNotWithdraw();
        }
    }
}
