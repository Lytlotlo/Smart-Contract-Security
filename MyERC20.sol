// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//Importing OpenZeppelin Standards
import { ERC20 } from "@openzeppelin/contracts@4.6.0/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts@4.6.0/access/AccessControl.sol";

//AI Security Audit Token
// Implements Role-Based Access Control (RBAC) to prevent unauthorized minting.
contract MyERC20 is ERC20, AccessControl {
    
    // Role Identifier: Hashed constant for the Minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Constructor: Sets up the token details and grants initial permissions
    constructor() ERC20("AI Security Token", "AISEC") {
        // Grant the "Admin" role to the deployer (You)
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Grant the "Minter" role to the deployer
        _grantRole(MINTER_ROLE, msg.sender);    
    }

    // Protected by the 'onlyRole' modifier to prevent privilege escalation exploits.
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
