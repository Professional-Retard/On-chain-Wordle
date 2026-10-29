# On-chain-Wordle

1. SYSTEM EXECUTIVE SUMMARY

This document specifies the technical design, deployment mechanics, and state evaluation logic for an on-chain adaptation of the five-letter word puzzle game Wordle. Built for Ethereum Virtual Machine (EVM) execution environments and verified on the Sepolia testnet, the system delegates all validation, feedback computation, and round progression to an autonomous smart contract.

Traditional web implementations maintain the secret word on a centralized server or evaluate player input directly within client-side JavaScript. This structure introduces attack vectors, allows client-side reverse engineering via browser developer tools, and provides no immutable audit trail for competitive play.

By migrating the game logic to an immutable ledger, every attempt constitutes an cryptographically signed transaction. The resulting solution guarantees deterministic execution, tamper-proof round tracking, and transparent verification without reliance on an off-chain referee.

2. ARCHITECTURAL OVERVIEW

The application comprises two discrete layers: a deterministic on-chain settlement layer and an asynchronous client-side interface layer.

On-Chain Protocol Layer
The core protocol is implemented in Solidity (version 0.8.20). The contract manages the global state machine, enforces input length and alphabet constraints, executes the scoring algorithm, and isolates user attempt histories across independent rounds.

Client Application Layer
The interface is structured as an uncompiled, lightweight single-page application leveraging modern HTML5, native CSS, and the Ethers.js library (v6). It establishes a direct Remote Procedure Call (RPC) connection to the user's browser extension wallet, deserializes contract state into a reactive six-by-five tile matrix, and handles chain ID validation to ensure network alignment.

3. CORE TECHNICAL INNOVATIONS AND OPTIMIZATIONS

EVM Storage Efficiency via Fixed Bytes
Dynamic string types in Solidity impose substantial gas overheads due to heap allocations, pointer indirection, and multi-word storage slot allocations. Because the game strictly mandates five-character inputs, the contract validates and downcasts inputs into the fixed-size primitive bytes5. This allows the target solution to be stored within a single 32-byte storage slot, drastically reducing SSTORE and SLOAD gas consumption during execution.

Deterministic Two-Pass Evaluation Algorithm
A common issue in naive Wordle implementations involves incorrect color scoring for duplicate letters. For example, if the solution contains a single instance of a letter and the user inputs two instances, standard single-pass iterative searches often mark both as present.

To ensure exact parity with official tournament rules, the smart contract utilizes an isolated two-pass algorithm:

Pass One (Exact Positional Matches): The algorithm traverses indices 0 through 4, identifying characters that match both value and index position. These positions are flagged as Correct (State 2), incrementing the positional match counter and marking the corresponding indices as consumed within a localized boolean tracker.

Pass Two (Permutational Matches): The algorithm traverses remaining unmatched characters to identify if the letter exists elsewhere in the target word. A tile is flagged as Present (State 1) strictly if an unconsumed duplicate exists in the solution tracker. If all occurrences of that letter are exhausted, the tile defaults to Absent (State 0).

On-Chain Character Normalization
To prevent invalid transactions and wasted gas resulting from mixed user input cases, the smart contract processes raw byte representations directly. ASCII lowercase values (integers 97 through 122) are converted to their uppercase counterparts (integers 65 through 90) via arithmetic offset adjustments prior to evaluation. Submissions containing non-alphabetic characters are reverted before triggering state alterations.

Nested Multi-Tenant State Isolation
Player histories are segmented using a double-layered mapping: currentRound mapped to playerAddress, pointing to an array of guess structures. This architecture guarantees that multiple concurrent players interact with the active round simultaneously without shared state contamination or race conditions.

Dynamic Role-Based Access Control
The smart contract implements a custom modifier enforcing that critical state transitions—such as advancing the global round or invoking an absolute reset to Round 1—can only be triggered by the contract deployer (owner). The frontend queries the owner variable upon wallet connection, rendering administrative controls solely for authorized addresses and removing them entirely from third-party players.

4. SMART CONTRACT INTERFACE AND FUNCTION SPECIFICATIONS

submitGuess(string guess) external returns (uint8[5])
State modifying method that accepts a five-character string. Reverts if the player has already achieved a winning state or if six attempts have been exhausted for the active round. Calculates the two-pass scoring array, stores the uppercase word and feedback record in contract storage, and emits a GuessSubmitted event containing indexed game data.

getPlayerState(address player) external view returns (string[], uint8[5][], bool, uint8, uint256)
Gas-free view method designed for client consumption. Consolidates a player's complete historical board for the active round—including all attempted words, color feedback matrices, win status, used attempt count, and the active round number—into a single RPC payload.

setNewWord(string newSolution) external
Owner-restricted state transition method. Validates and packs a new five-letter target word into the solution slot, increments the currentRound counter by one, and emits the NewRoundStarted event, presenting all network players with a clean board.

resetToRoundOne(string newSolution) external
Owner-restricted recovery method. Overwrites the active solution with a new five-letter target word, sets the currentRound counter explicitly back to 1, and emits the GameResetToRoundOne event.

5. USER INTERACTION WORKFLOW

Step One: Cryptographic Authentication
The user navigates to the web application and selects Connect Wallet. MetaMask initiates an account handshake, verifying that the provider is routed to the Sepolia testnet (Chain ID 11155111). If an alternative network is detected, the application requests an automated chain-switch RPC call.

Step Two: State Deserialization
Upon establishing the provider connection, the application queries getPlayerState. If the caller address matches the contract owner, administrative controls are unhidden. The six-by-five CSS grid renders completed attempts with their respective color feedback, calculates remaining attempts, and sets the submission button state accordingly.

Step Three: Transaction Broadcasting and Settlement
