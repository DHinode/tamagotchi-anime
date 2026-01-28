# Battle Game on Blockchain (IoB Project)

This project implements a system of digital creatures (Gotchis) on the blockchain, inspired by Tamagotchis and Pokémon. Each creature is a living NFT whose statistics (Hunger, Happiness, Strength) evolve over time and require active management from the owner.

**Authors:** Emilie LIN & Massyl BENGANA
**Context:** Master Informatique - UE IoB (Sorbonne Université)

---

## Repository Content

The project consists of two main Smart Contracts:
1. **`GotchiToken.sol`**: The ERC20 token ("FOOD") used for the game economy.
2. **`AnimeGotchi.sol`**: The main ERC721 contract managing game logic, creature lifecycles, and duels.

---

## Deployment and Testing Instructions

To test the application, we recommend using **Remix IDE** (https://remix.ethereum.org/). Follow these precise steps to deploy and interact with the contracts.

### 1. Setup and Compilation
1. Open Remix IDE in your browser.
2. Create two files: `GotchiToken.sol` and `AnimeGotchi.sol`.
3. Copy the provided source code into the respective files.
4. Go to the **"Solidity Compiler"** tab (on the left) and click **Compile**.
   * *Ensure the compiler version is `0.8.20` or higher.*

### 2. Deployment
1. Go to the **"Deploy & Run Transactions"** tab.
2. Select the environment **Remix VM (Cancun)**.
3. **Deploy GotchiToken**:
   * Select `GotchiToken` from the "Contract" dropdown.
   * Click **Deploy**.
   * Copy the address of the deployed contract (copy icon next to the contract at the bottom left).
4. **Deploy AnimeGotchi**:
   * Select `AnimeGotchi` from the "Contract" dropdown.
   * Paste the `GotchiToken` address into the `_tokenAddress` field (constructor).
   * Click **Deploy**.

### 3. Configuration (Critical Step)
For the game to work (work rewards, duel victories), the game contract must have permission to mint tokens.

1. Expand the deployed `GotchiToken` contract menu.
2. Find the **`addController`** function.
3. Paste the **AnimeGotchi** contract address.
4. Click **transact**.

### 4. Playing: Test Scenario
Follow this order to test all functionalities:

#### A. Create a creature
* In `AnimeGotchi`, find the `mintGotchi` function.
* Enter a name (e.g., "Pikachu") and click **transact**.
* This creates Token ID `1`.

#### B. Approve Spending (Mandatory)
Before feeding or training your creature (paid actions), you must authorize the game contract to spend your tokens.
* In `GotchiToken`, find the **`approve`** function.
* **Spender**: Address of the `AnimeGotchi` contract.
* **Amount**: `1000000000000000000000` (a very large number to be safe).
* Click **transact**.

#### C. Basic Interactions
* **Work**: Use `work(1)` to earn tokens (Watch out for burnout!).
* **Feed**: Use `feed(1)` to reset hunger (Cost: 5 tokens).
* **Train**: Use `train(1)` to level up (Cost: 10 tokens). *Watch out for the hunger spike!*

#### D. Simulate Time
* The contract uses a "Lazy Evaluation" system. Wait **15 to 30 seconds** between actions to see the statistics (Hunger/Happiness) degrade automatically.

#### E. Duel
To test dueling, you need a second creature.
1. Call `mintGotchi` a second time to create Token ID `2` (the opponent).
2. In the **`duel`** function, enter:
   * `_myId`: **1** (Your fighter)
   * `_enemyId`: **2** (The target)
3. Click **transact**.
4. Check the logs in the Remix console (`DuelResult`):
   * If your ID is first in the event: Victory (Level + Money).
   * If the enemy ID is first: Defeat (Happiness drop).

---

## Technical Stack
* **Language**: Solidity 0.8.20
* **Standards**: ERC721 (NFT), ERC20 (Token), Ownable
* **Library**: OpenZeppelin
