// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAnimeFood is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract AnimeGotchi is ERC721, Ownable {
    
    uint256 public tokenIds;
    IAnimeFood public foodToken;

    struct GotchiStats {
        string name;
        uint256 level;
        uint256 strength;    
        uint256 hunger;      // 0-100
        uint256 happiness;   // 0-100 
        uint256 lastInteraction; 
        bool isCrazy;        // Si TRUE = Crash du système (Besoin de réparation)
    }

    mapping(uint256 => GotchiStats) public gotchis;

    // --- ECONOMIE ---
    uint256 constant TRAIN_COST = 10 * 10**18; 
    uint256 constant FEED_COST = 5 * 10**18;
    uint256 constant WORK_REWARD = 15 * 10**18; 
    uint256 constant THERAPY_COST = 100 * 10**18; // Le prix pour réparer le crash

    // --- TEMPS ---
    uint256 constant HUNGER_PER_SEC = 1; 
    uint256 constant HAPPY_LOSS_PER_SEC = 1;

    constructor(address _foodTokenAddress) ERC721("SonicGotchi", "SGT") Ownable(msg.sender) {
        foodToken = IAnimeFood(_foodTokenAddress);
    }

    // --- CREATION (IMMORTEL) ---
    function mintGotchi(string memory _name) public {
        tokenIds++;
        _mint(msg.sender, tokenIds);

        gotchis[tokenIds] = GotchiStats({
            name: _name,
            level: 1,
            strength: 10,     
            hunger: 0,
            happiness: 100,
            lastInteraction: block.timestamp,
            isCrazy: false // Tout va bien au début
        });
    }

    // --- MOTEUR INTERNE ---
    function _updateStatus(uint256 _tokenId) internal {
        GotchiStats storage g = gotchis[_tokenId];
        
        // Si le système a déjà crashé, le temps ne change rien, il faut réparer.
        if (g.isCrazy) return; 

        uint256 timePassed = block.timestamp - g.lastInteraction;
        
        // Calcul Faim
        g.hunger += (timePassed * HUNGER_PER_SEC);
        
        // Calcul Bonheur
        if (g.happiness > (timePassed * HAPPY_LOSS_PER_SEC)) {
            g.happiness -= (timePassed * HAPPY_LOSS_PER_SEC);
        } else {
            g.happiness = 0;
        }

        // --- NOUVELLE LOGIQUE : PAS DE MORT, MAIS CRASH ---
        
        // 1. Dépression totale (Bonheur = 0) -> CRASH
        if (g.happiness == 0) {
            g.isCrazy = true;
        }

        // 2. Faim extrême (Faim >= 100) -> CRASH (Au lieu de mourir)
        if (g.hunger >= 100) {
            g.hunger = 100; // Plafond
            g.isCrazy = true; // Le système s'arrête par manque d'énergie
        }

        g.lastInteraction = block.timestamp;
    }

    // Modifier pour bloquer les actions si le PC/Gotchi a "crashé"
    modifier checkSanity(uint256 _tokenId) {
        // On met à jour avant de vérifier
        if (!gotchis[_tokenId].isCrazy) {
             _updateStatus(_tokenId);
        }
        
        // S'il est fou APRES la mise à jour, on bloque
        require(!gotchis[_tokenId].isCrazy, "ERREUR SYSTEME : CRASH (Faim ou Depression). Utilise 'rebootSystem' !");
        _;
    }

    // --- ACTIONS ---

    function work(uint256 _tokenId) public checkSanity(_tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Pas a toi");
        GotchiStats storage g = gotchis[_tokenId];
        
        g.happiness = (g.happiness > 20) ? g.happiness - 20 : 0; 
        g.hunger += 10; 
        
        foodToken.mint(msg.sender, WORK_REWARD);
        
        // Vérification post-action
        if (g.happiness == 0 || g.hunger >= 100) g.isCrazy = true;
    }

    function train(uint256 _tokenId) public checkSanity(_tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Pas a toi");
        
        bool success = foodToken.transferFrom(msg.sender, address(this), TRAIN_COST);
        require(success, "Fonds insuffisants");

        GotchiStats storage g = gotchis[_tokenId];
        g.strength += 5; 
        g.hunger += 20;  
        g.level++;
        
        if (g.hunger >= 100) g.isCrazy = true;
    }

    function feed(uint256 _tokenId) public checkSanity(_tokenId) {
        bool success = foodToken.transferFrom(msg.sender, address(this), FEED_COST);
        require(success, "Fonds insuffisants");

        GotchiStats storage g = gotchis[_tokenId];
        g.hunger = 0;
        g.happiness = 100; 
    }

    // --- REPARATION (Remplacant de Revive) ---
    function rebootSystem(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Pas a toi");
        GotchiStats storage g = gotchis[_tokenId];
        
        // On ne peut rebooter que si ça a crashé
        require(g.isCrazy, "Le systeme fonctionne deja correctement.");

        // Ça coûte cher de redémarrer le système
        bool success = foodToken.transferFrom(msg.sender, address(this), THERAPY_COST);
        require(success, "Pas assez d'argent pour le reboot systeme");

        g.isCrazy = false;
        g.hunger = 0;      // On remet tout à neuf
        g.happiness = 100; 
        g.lastInteraction = block.timestamp;
    }

    // --- LE DUEL ---
    function duel(uint256 _myId, uint256 _enemyId) public checkSanity(_myId) {
        require(ownerOf(_myId) == msg.sender, "Ce n'est pas ton combattant");
        require(_myId != _enemyId, "Tu ne peux pas te battre contre toi-meme");
        
        // On met à jour l'ennemi aussi pour voir ses vraies stats
        _updateStatus(_enemyId);

        GotchiStats storage myG = gotchis[_myId];
        GotchiStats storage enemyG = gotchis[_enemyId];

        // On ne peut pas attaquer un ennemi qui a déjà crashé (trop facile)
        require(!enemyG.isCrazy, "L'ennemi a deja crash (Ecran Bleu), impossible de combattre.");

        uint256 myPower = myG.strength * myG.happiness / 100;
        uint256 enemyPower = enemyG.strength * enemyG.happiness / 100;

        uint256 luck = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 10; 
        
        if (myPower + luck >= enemyPower) {
            // VICTOIRE
            myG.level++;
            myG.strength += 2; 
            
            enemyG.happiness = (enemyG.happiness > 20) ? enemyG.happiness - 20 : 0;
            if (enemyG.happiness == 0) enemyG.isCrazy = true; 
        } else {
            // DEFAITE
            myG.happiness = (myG.happiness > 20) ? myG.happiness - 20 : 0;
            if (myG.happiness == 0) myG.isCrazy = true; 
            
            enemyG.level++;
            enemyG.strength += 2;
        }
    }

    // --- HUD LABELISÉ ---
    // Les variables retournées ont maintenant des noms pour l'affichage Remix
    function getStats(uint256 _tokenId) public view returns (
        string memory Nom, 
        uint256 Force, 
        uint256 Faim, 
        uint256 Bonheur, 
        uint256 Niveau, 
        string memory Etat_Systeme
    ) {
        // On simule l'état actuel sans modifier la blockchain
        GotchiStats memory g = gotchis[_tokenId];
        
        if (!g.isCrazy) {
            uint256 timePassed = block.timestamp - g.lastInteraction;
            
            // Simulation Faim
            g.hunger += (timePassed * HUNGER_PER_SEC);
            if (g.hunger > 100) g.hunger = 100;

            // Simulation Bonheur
            if (g.happiness > (timePassed * HAPPY_LOSS_PER_SEC)) {
                g.happiness -= (timePassed * HAPPY_LOSS_PER_SEC);
            } else {
                g.happiness = 0;
            }
        }

        // Détermination de l'état (texte)
        string memory status;
        if (g.isCrazy || g.hunger >= 100 || g.happiness == 0) {
            status = "CRITICAL FAILURE (CRASH)";
        } else {
            status = "OPERATIONNEL";
        }

        return (g.name, g.strength, g.hunger, g.happiness, g.level, status);
    }
}
