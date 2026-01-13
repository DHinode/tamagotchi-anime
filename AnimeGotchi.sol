// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface mise à jour pour le nouveau Token
interface IGotchiToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract AnimeGotchi is ERC721, Ownable {
    
    uint256 public tokenIds;
    IGotchiToken public foodToken; // Variable renommée pour faire propre

    // --- EVENTS (Logs professionnels) ---
    event GotchiBorn(uint256 indexed id, address owner, string name);
    event ActionPerformed(uint256 indexed id, string actionType);
    event DuelResult(uint256 indexed winnerId, uint256 indexed loserId, uint256 amountWon);
    event SystemCrash(uint256 indexed id, string reason);
    event SystemReboot(uint256 indexed id);

    struct GotchiStats {
        string name;
        uint256 level;
        uint256 strength;    
        uint256 hunger;      // 0-100 (100 = Crash)
        uint256 happiness;   // 0-100 (0 = Crash)
        uint256 lastInteraction; 
        bool isCrazy;        // Si TRUE = Ecran Bleu
    }

    mapping(uint256 => GotchiStats) public gotchis;

    // --- ECONOMIE (PRIX) ---
    uint256 constant TRAIN_COST = 10 * 10**18; 
    uint256 constant FEED_COST = 5 * 10**18;
    uint256 constant WORK_REWARD = 15 * 10**18; 
    uint256 constant THERAPY_COST = 100 * 10**18; 
    uint256 constant DUEL_COST = 50 * 10**18;     

    constructor(address _tokenAddress) ERC721("SonicGotchi", "SGT") Ownable(msg.sender) {
        foodToken = IGotchiToken(_tokenAddress);
    }

    // --- 1. CREATION ---
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
            isCrazy: false
        });

        emit GotchiBorn(tokenIds, msg.sender, _name);
    }

    // --- 2. MOTEUR INTERNE (Vitesse Demo) ---
    function _updateStatus(uint256 _tokenId) internal {
        GotchiStats storage g = gotchis[_tokenId];
        
        if (g.isCrazy) return; 

        uint256 timePassed = block.timestamp - g.lastInteraction;
        
        // VITESSE DEMO : 1 point toutes les 15 secondes
        uint256 statChange = timePassed / 15; 

        if (statChange > 0) {
            g.hunger += statChange;
            
            if (g.happiness > statChange) {
                g.happiness -= statChange;
            } else {
                g.happiness = 0;
            }
            g.lastInteraction = block.timestamp;
        }

        // Vérification Crash
        if (g.happiness == 0 || g.hunger >= 100) {
            if(g.hunger > 100) g.hunger = 100;
            g.isCrazy = true;
            emit SystemCrash(_tokenId, "Negligence fatale");
        }
    }

    modifier checkSanity(uint256 _tokenId) {
        if (!gotchis[_tokenId].isCrazy) {
             _updateStatus(_tokenId);
        }
        require(!gotchis[_tokenId].isCrazy, "CRASH SYSTEME : Utilise 'rebootSystem' !");
        _;
    }

    // --- 3. ACTIONS ---

    function work(uint256 _tokenId) public checkSanity(_tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Pas a toi");
        GotchiStats storage g = gotchis[_tokenId];
        
        // Burnout : Plus il a faim, plus ça coûte du bonheur
        uint256 burnOutRisk = 20 + (g.hunger / 2);

        if (g.happiness > burnOutRisk) {
            g.happiness -= burnOutRisk;
        } else {
            g.happiness = 0;
        }

        g.hunger += 10; 
        foodToken.mint(msg.sender, WORK_REWARD);
        
        if (g.happiness == 0 || g.hunger >= 100) {
            g.isCrazy = true;
            emit SystemCrash(_tokenId, "Burnout au travail");
        }
        
        emit ActionPerformed(_tokenId, "Work");
    }

    function train(uint256 _tokenId) public checkSanity(_tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Pas a toi");
        bool success = foodToken.transferFrom(msg.sender, address(this), TRAIN_COST);
        require(success, "Fonds insuffisants ou pas d'APPROVE");

        GotchiStats storage g = gotchis[_tokenId];
        g.strength += 5; 
        g.hunger += 20;  
        g.level++;
        
        if (g.hunger >= 100) {
            g.isCrazy = true;
            emit SystemCrash(_tokenId, "Surmenage physique");
        }

        emit ActionPerformed(_tokenId, "Train");
    }

    function feed(uint256 _tokenId) public checkSanity(_tokenId) {
        bool success = foodToken.transferFrom(msg.sender, address(this), FEED_COST);
        require(success, "Fonds insuffisants ou pas d'APPROVE");

        GotchiStats storage g = gotchis[_tokenId];
        g.hunger = 0;
        g.happiness = 100; 
        
        emit ActionPerformed(_tokenId, "Feed");
    }

    // --- 4. REPARATION ---
    function rebootSystem(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Pas a toi");
        
        // Force la mise à jour pour confirmer le crash
        _updateStatus(_tokenId);

        GotchiStats storage g = gotchis[_tokenId];
        require(g.isCrazy, "Le systeme fonctionne correctement, pas besoin de reboot.");

        bool success = foodToken.transferFrom(msg.sender, address(this), THERAPY_COST);
        require(success, "Pas assez d'argent");

        g.isCrazy = false;
        g.hunger = 0;      
        g.happiness = 100; 
        g.lastInteraction = block.timestamp;

        emit SystemReboot(_tokenId);
    }

    // --- 5. DUEL (PARI) ---
    function duel(uint256 _myId, uint256 _enemyId) public checkSanity(_myId) {
        require(ownerOf(_myId) == msg.sender, "Pas ton Gotchi");
        require(_myId != _enemyId, "Impossible contre soi-meme");
        
        bool betPlaced = foodToken.transferFrom(msg.sender, address(this), DUEL_COST);
        require(betPlaced, "Paiement de la mise refuse");

        _updateStatus(_enemyId); 
        GotchiStats storage myG = gotchis[_myId];
        GotchiStats storage enemyG = gotchis[_enemyId];

        require(!enemyG.isCrazy, "L'ennemi a crash.");

        uint256 myPower = myG.strength * myG.happiness / 100;
        uint256 enemyPower = enemyG.strength * enemyG.happiness / 100;
        
        uint256 luck = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 10; 
        
        if (myPower + luck >= enemyPower) {
            // VICTOIRE
            myG.level++;
            myG.strength += 2; 
            enemyG.happiness = (enemyG.happiness > 20) ? enemyG.happiness - 20 : 0;
            if (enemyG.happiness == 0) enemyG.isCrazy = true; 

            foodToken.transfer(msg.sender, DUEL_COST); 
            foodToken.mint(msg.sender, DUEL_COST);     
            
            emit DuelResult(_myId, _enemyId, DUEL_COST * 2);
        } else {
            // DEFAITE
            myG.happiness = (myG.happiness > 20) ? myG.happiness - 20 : 0;
            if (myG.happiness == 0) myG.isCrazy = true; 
            
            enemyG.level++;
            enemyG.strength += 2;

            address enemyOwner = ownerOf(_enemyId);
            foodToken.transfer(enemyOwner, DUEL_COST);

            emit DuelResult(_enemyId, _myId, DUEL_COST);
        }
    }

    // --- 6. TRESORERIE (Withdraw) ---
    function withdrawEarnings() external onlyOwner {
        uint256 balance = foodToken.balanceOf(address(this));
        require(balance > 0, "Rien a retirer");
        foodToken.transfer(msg.sender, balance);
    }

    // --- 7. AFFICHAGE ---
    function getStats(uint256 _tokenId) public view returns (string memory Nom, uint256 Force, uint256 Faim, uint256 Bonheur, uint256 Niveau, string memory Etat) {
        GotchiStats memory g = gotchis[_tokenId];
        
        if (!g.isCrazy) {
            uint256 timePassed = block.timestamp - g.lastInteraction;
            uint256 statChange = timePassed / 15; // Vitesse démo

            if (statChange > 0) {
                g.hunger += statChange;
                if (g.hunger > 100) g.hunger = 100;
                if (g.happiness > statChange) { g.happiness -= statChange; } else { g.happiness = 0; }
            }
        }
        string memory statusStr = (g.isCrazy || g.hunger >= 100 || g.happiness == 0) ? "CRASH SYSTEME" : "OPERATIONNEL";
        return (g.name, g.strength, g.hunger, g.happiness, g.level, statusStr);
    }
}
