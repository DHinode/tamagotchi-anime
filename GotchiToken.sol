// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GotchiToken is ERC20, Ownable {
    mapping(address => bool) public controllers;

    constructor() ERC20("GotchiFood", "FOOD") Ownable(msg.sender) {
        _mint(msg.sender, 1000 * 10 ** decimals()); 
    }

    // Fonction pour autoriser le contrat du Jeu
    function addController(address _controller) external onlyOwner {
        controllers[_controller] = true;
    }

    function mint(address to, uint256 amount) external {
        require(controllers[msg.sender] || msg.sender == owner(), "Non autorise");
        _mint(to, amount);
    }
}
