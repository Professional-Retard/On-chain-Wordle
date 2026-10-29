// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OnChainWordle
 * @notice Gas-optimized on-chain Wordle with owner-only controls and round reset.
 */
contract OnChainWordle {
    address public owner;
    bytes5 private solution;
    uint256 public currentRound;
    uint8 public constant MAX_ATTEMPTS = 6;

    struct GuessRecord {
        string word;
        uint8[5] feedback;
    }

    mapping(uint256 => mapping(address => GuessRecord[])) private playerGuesses;
    mapping(uint256 => mapping(address => bool)) public hasWon;

    event GuessSubmitted(
        address indexed player,
        uint256 indexed round,
        string word,
        uint8[5] feedback,
        bool isWinner,
        uint8 attemptNumber
    );

    event NewRoundStarted(uint256 indexed newRound);
    event GameResetToRoundOne(uint256 indexed round);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    constructor(string memory _initialSolution) {
        owner = msg.sender;
        _setSolution(_initialSolution, 1);
    }

    function setNewWord(string memory _newSolution) external onlyOwner {
        _setSolution(_newSolution, currentRound + 1);
    }

    /**
     * @notice Resets the round counter back to 1 and sets a fresh secret word.
     * @param _newSolution A new 5-letter word for Round #1.
     */
    function resetToRoundOne(string memory _newSolution) external onlyOwner {
        _setSolution(_newSolution, 1);
        emit GameResetToRoundOne(1);
    }

    function submitGuess(string memory _guess) external returns (uint8[5] memory feedback) {
        require(!hasWon[currentRound][msg.sender], "You have already solved this round!");
        require(
            playerGuesses[currentRound][msg.sender].length < MAX_ATTEMPTS,
            "No attempts remaining for this round!"
        );

        bytes5 normalizedGuess = _normalizeAndValidate(_guess);
        bytes5 target = solution;

        bool[5] memory solutionUsed;
        bool[5] memory guessMatched;
        uint8 correctCount = 0;

        // Pass 1: Green matches
        for (uint8 i = 0; i < 5; i++) {
            if (normalizedGuess[i] == target[i]) {
                feedback[i] = 2;
                solutionUsed[i] = true;
                guessMatched[i] = true;
                correctCount++;
            }
        }

        // Pass 2: Yellow matches
        for (uint8 i = 0; i < 5; i++) {
            if (!guessMatched[i]) {
                for (uint8 j = 0; j < 5; j++) {
                    if (!solutionUsed[j] && normalizedGuess[i] == target[j]) {
                        feedback[i] = 1;
                        solutionUsed[j] = true;
                        break;
                    }
                }
            }
        }

        string memory upperGuess = _bytes5ToString(normalizedGuess);

        playerGuesses[currentRound][msg.sender].push(
            GuessRecord({word: upperGuess, feedback: feedback})
        );

        bool won = (correctCount == 5);
        if (won) {
            hasWon[currentRound][msg.sender] = true;
        }

        emit GuessSubmitted(
            msg.sender,
            currentRound,
            upperGuess,
            feedback,
            won,
            uint8(playerGuesses[currentRound][msg.sender].length)
        );

        return feedback;
    }

    function getPlayerState(address _player)
        external
        view
        returns (
            string[] memory words,
            uint8[5][] memory feedbacks,
            bool won,
            uint8 attemptsUsed,
            uint256 round
        )
    {
        GuessRecord[] storage records = playerGuesses[currentRound][_player];
        uint256 len = records.length;

        words = new string[](len);
        feedbacks = new uint8[5][](len);

        for (uint256 i = 0; i < len; i++) {
            words[i] = records[i].word;
            feedbacks[i] = records[i].feedback;
        }

        won = hasWon[currentRound][_player];
        attemptsUsed = uint8(len);
        round = currentRound;
    }

    function _setSolution(string memory _word, uint256 _targetRound) internal {
        solution = _normalizeAndValidate(_word);
        currentRound = _targetRound;
        emit NewRoundStarted(currentRound);
    }

    function _normalizeAndValidate(string memory _str) internal pure returns (bytes5) {
        bytes memory b = bytes(_str);
        require(b.length == 5, "Word must be exactly 5 letters long");

        bytes memory normalized = new bytes(5);
        for (uint8 i = 0; i < 5; i++) {
            uint8 charCode = uint8(b[i]);
            if (charCode >= 97 && charCode <= 122) {
                charCode -= 32;
            }
            require(charCode >= 65 && charCode <= 90, "Word must contain only A-Z letters");
            normalized[i] = bytes1(charCode);
        }

        bytes5 result;
        assembly {
            result := mload(add(normalized, 32))
        }
        return result;
    }

    function _bytes5ToString(bytes5 _b) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(5);
        for (uint8 i = 0; i < 5; i++) {
            bytesArray[i] = _b[i];
        }
        return string(bytesArray);
    }
}