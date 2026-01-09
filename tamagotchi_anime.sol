// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AnimeGotchi is ERC721, Ownable {
    
    uint256 public tokenIds;

    struct GotchiStats {
        string name;
        uint256 level;
        uint256 hunger;      
        uint256 happiness;   
        uint256 lastInteraction; 
        string stage;        
        bool isAlive;
    }

    mapping(uint256 => GotchiStats) public gotchis;

    // --- PARAMÈTRES AJUSTÉS (Plus facile) ---
    uint256 constant HUNGER_PER_SECOND = 1; 
    uint256 constant HAPPINESS_LOSS_PER_SECOND = 1;
    uint256 constant XP_TO_EVOLVE = 5; 

    constructor() ERC721("SonicGotchi", "SGT") Ownable(msg.sender) {}

    function mintGotchi(string memory _name) public {
        tokenIds++;
        uint256 newId = tokenIds;
        _mint(msg.sender, newId);

        gotchis[newId] = GotchiStats({
            name: _name,
            level: 1,
            hunger: 0,        // CORRECTION : On commence le ventre plein (0 faim)
            happiness: 100,   // CORRECTION : On commence très heureux
            lastInteraction: block.timestamp,
            stage: "OEUF",
            isAlive: true
        });
        // Tu as maintenant 100 secondes (1min40) avant qu'il ne meure.
    }

    function _calculateCurrentStats(uint256 _tokenId) internal view returns (uint256, uint256, bool) {
        GotchiStats memory g = gotchis[_tokenId];
        
        // S'il est déjà mort dans la base de données, on renvoie mort
        if (!g.isAlive) return (100, 0, false);

        uint256 timePassed = block.timestamp - g.lastInteraction;
        
        uint256 newHunger = g.hunger + (timePassed * HUNGER_PER_SECOND);
        
        // Calcul du bonheur
        uint256 newHappiness = 0;
        if (g.happiness > (timePassed * HAPPINESS_LOSS_PER_SECOND)) {
            newHappiness = g.happiness - (timePassed * HAPPINESS_LOSS_PER_SECOND);
        }

        // Plafond faim
        if (newHunger > 100) newHunger = 100;
        
        // Si la faim atteint 100, il meurt
        bool alive = newHunger < 100;

        return (newHunger, newHappiness, alive);
    }

    function _syncStats(uint256 _tokenId) internal {
        (uint256 currentHunger, uint256 currentHappy, bool alive) = _calculateCurrentStats(_tokenId);
        
        gotchis[_tokenId].hunger = currentHunger;
        gotchis[_tokenId].happiness = currentHappy;
        gotchis[_tokenId].isAlive = alive;
        gotchis[_tokenId].lastInteraction = block.timestamp;
    }

    function feed(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Pas ton Gotchi");
        _syncStats(_tokenId); 
        
        GotchiStats storage g = gotchis[_tokenId];
        require(g.isAlive, "Il est mort... Utilise revive() !"); // Nouveau message

        g.hunger = 0;        
        g.happiness = 100;   
        
        g.level++;           
        _checkEvolution(_tokenId);
    }

    function play(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Pas ton Gotchi");
        _syncStats(_tokenId);

        GotchiStats storage g = gotchis[_tokenId];
        require(g.isAlive, "Il est mort... Utilise revive() !");

        g.happiness = 100;   
        g.hunger += 10;      
        if (g.hunger >= 100) g.isAlive = false; // Correction petite faille

        g.level++;
        _checkEvolution(_tokenId);
    }

    // --- NOUVELLE FONCTION : REVIVE ---
    // Permet de ressusciter ton Gotchi (normalement ça devrait être payant, mais gratuit pour le test)
    function revive(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Pas ton Gotchi");
        GotchiStats storage g = gotchis[_tokenId];
        require(!g.isAlive, "Il est encore vivant !");

        g.isAlive = true;
        g.hunger = 0;        // Ventre plein
        g.happiness = 100;   // Heureux
        g.lastInteraction = block.timestamp; // Reset du temps
    }

    function _checkEvolution(uint256 _tokenId) internal {
        GotchiStats storage g = gotchis[_tokenId];
        if (g.level >= XP_TO_EVOLVE && keccak256(bytes(g.stage)) == keccak256(bytes("OEUF"))) {
            g.stage = "BEBE";
        } else if (g.level >= (XP_TO_EVOLVE * 2) && keccak256(bytes(g.stage)) == keccak256(bytes("BEBE"))) {
            g.stage = "ADULTE";
        }
    }

    function getLiveStats(uint256 _tokenId) public view returns (
        string memory Nom, 
        string memory Stade, 
        uint256 Faim, 
        uint256 Bonheur, 
        uint256 Niveau, 
        string memory Etat
    ) {
        (uint256 currHunger, uint256 currHappy, bool alive) = _calculateCurrentStats(_tokenId);
        GotchiStats memory g = gotchis[_tokenId];

        string memory statusText = alive ? "VIVANT" : "MORT";
        return (g.name, g.stage, currHunger, currHappy, g.level, statusText);
    }
}
