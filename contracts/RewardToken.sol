// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {
    // Define the initial supply of tokens (e.g., 1 million tokens)
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;  // 1 million tokens with 18 decimals

    // Constructor to initialize the token with its name and symbol
    constructor(address initialAddress) Ownable(initialAddress) ERC20("Authorship Reward Token", "ART") {
        // Mint the initial supply and assign it to the owner (creator of the contract)
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // Function for the owner (admin) to mint more tokens if needed
    function mint(address to, uint256 amount) public onlyOwner {
        // Mint the specified amount of tokens to the given address
        _mint(to, amount);
    }

    // Function to allow the owner to burn tokens (reduce supply)
    function burn(uint256 amount) public onlyOwner {
        // Burn the specified amount of tokens from the owner's balance
        _burn(msg.sender, amount);
    }
}