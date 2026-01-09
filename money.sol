// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AnimeFood is ERC20, Ownable {
    // Mapping pour autoriser des contrats (comme le jeu) à mint des tokens
    mapping(address => bool) public controllers;

    constructor() ERC20("AnimeFood", "FOOD") Ownable(msg.sender) {
        _mint(msg.sender, 1000 * 10 ** decimals()); // 1000 tokens pour toi au début
    }

    function addController(address _controller) external onlyOwner {
        controllers[_controller] = true;
    }

    function mint(address to, uint256 amount) external {
        require(controllers[msg.sender] || msg.sender == owner(), "Non autorise");
        _mint(to, amount);
    }
}
