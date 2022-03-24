//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import library
import "./libraries/gameLib.sol";

//import interfaces
import "./interfaces/IMinter.sol";
import "./interfaces/IStats.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

//import VRFConsumerBase
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

//import reentrancy guard
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract game is VRFConsumerBase, ReentrancyGuard{

    //define a struct for a games vars
    //this should include: 
    //players addresses
    //pot = entry fee * 2
    //player 1 tokens
    //player 1 energy
    //player 2 tokens
    //player 2 energy
    //bool openForPlayer2
    //bool gameActive
    //anything else?
    struct GameVars {
        address player1;
        address player2;
        uint256 pot;
        uint16[20] p1Cards;
        uint8[10] p1Energy;
        uint16[20] p2Cards;
        uint8[10] p2Energy;
        bool openForPlayer2;
        bool active;
        uint8 currentTurn;// 0 = inactive, 1 = p1, 2 = p2
    }

    struct playedCards {
        uint16[] player1Hand;
        uint16[] player1Deck;
        uint16[] player2Hand;
        uint16[] player2Deck;
        uint16[] player1KnockOut;
        uint16[] player2KnockOut;
        uint8[] player1HeldEnergy;
        uint8[] player2HeldEnergy;
        uint16[] player1PlayedCards;
        uint8[] player1AssignedEnergy;
        uint8[] player2AssignedEnergy;
    }
    
    //define a mapping to store gameId => playedCards
    mapping(uint256 => playedCards) private cardsPlayed;

    //define a mapping to store gameId => gameVars
    mapping(uint256 => GameVars) private gameVariables;

    //store the addresses of:
    //the admin & community wallet 
    //the minter, energy & stats contracts 
    address private admin;
    address private community;
    address private minter;
    address private energy;
    address private stats;

    //oracle data
    bytes32 private keyHash;
    uint256 private oracleFee;
    address private vrfCoordinator;
    address private linkToken;
    
    struct RequestData{
        uint256 _gameId;
        address winner;
    }

    //requestId -> requestData & gameId
    mapping(bytes32 => RequestData) private requests;
    mapping(bytes32 => uint256) private requests2GameId;

    //requestId => command
    mapping(bytes32 => uint8) private order;

    //bool for checking whether games are open or not
    bool private active;

    //counter for all games
    uint256 public gameId;

    //primes for splitting rand number up
    uint16[] private primes= [
        6491,
        6863,
        7333,
        6701,
        6343
    ];

    //constructor
    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _oracleFee,
        address _community,
        address _minter,
        address _stats,
        address _energy
    ) VRFConsumerBase(_vrfCoordinator, _linkToken){
        active = false;
        vrfCoordinator = _vrfCoordinator;
        linkToken = _linkToken;
        keyHash = _keyHash;
        oracleFee = _oracleFee;
        community = _community;
        minter = _minter;
        stats = _stats;
        energy = _energy;
        admin = msg.sender;
        gameId = 0;
    }

    //player 1 initiates a open room game & sets the entry price
    //the player must submit the tokens they would like to enter
    //each card must be checked that the player entering the cards, owns those cards
    //the player must deposit the amount the player would like to wager
    //create the game vars using the build vars function
    function makeRoom(uint16[20] memory cards, uint8[10] memory energyCards) external payable {
        require(msg.value > 0);
        require(GameLib.ownsAllCards(cards, minter));
        require(GameLib.ownsEnergyCards(energyCards, energy));

        gameId +=1;

        gameVariables[gameId].player1 = msg.sender;
        gameVariables[gameId].pot = msg.value;
        gameVariables[gameId].p1Cards = cards;
        gameVariables[gameId].p1Energy = energyCards;
        gameVariables[gameId].openForPlayer2 = true;
        gameVariables[gameId].active = true;
        gameVariables[gameId].currentTurn = 0;
    }


    //player 2 joins a room that has a set price
    //check that the gameID exists & is open to be joined
    //the player must submit the tokens they would like to enter
    //each card must be checked that the player entering the cards, owns those cards
    //the player must deposit the amount the player would like to wager
    //edit the gamevars    

    function joinRoom(uint256 _gameId, uint16[20] memory cards, uint8[10] memory energyCards) external payable {
        require(gameVariables[_gameId].active);
        require(msg.value == gameVariables[_gameId].pot);
        require(GameLib.ownsAllCards(cards, minter));
        require(GameLib.ownsEnergyCards(energyCards, energy));

        gameVariables[_gameId].player2 = msg.sender;
        gameVariables[_gameId].pot += msg.value;
        gameVariables[_gameId].p2Cards = cards;
        gameVariables[_gameId].p2Energy = energyCards;
        gameVariables[_gameId].openForPlayer2 = false;
        getRandForStart(_gameId);
    }

    //player 1 can end the game with no consequences if there is no player 2
    //possible reentrancy vulnerability, add reentrancy guard & finish all state changes before transferring the funds back to the caller
    function cancelGame(uint256 _gameId) external nonReentrant {
        require(gameVariables[_gameId].player1 == msg.sender);
        require(gameVariables[_gameId].openForPlayer2 == true);
        gameVariables[_gameId].active = false;
        uint256 amount = gameVariables[_gameId].pot;
        gameVariables[_gameId].pot = 0;
        payable(msg.sender).transfer(amount); 
    }

    //player 1 & 2 take turns here
    //the player must be able to switch a energy card from one played card to another if the element type is the same
    //the player must be able to choose a card to place into the main fight section or on the bench
    //the player must be able to choose what attack they will use
    //the player must be able to choose if they wants to skip an attack
    function takeTurn(
        uint256 _gameId
    ) external {

    }

    function setupTurn(
        uint256 _gameId,
        uint16[] memory rand
    ) internal {

    }


    //surrender function to allow games to be quit mid game aslong as 1 side wants to quit, the opponent is by default the winner
    function surrender(uint256 _gameId) external {

    }

    //split funds between winner & community wallet
    function split(uint256 _gameId) external {

    }

    //vrf request for random number
    function getRandForStart(uint256 _gameId) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= oracleFee);
        
        bytes32 requestId = requestRandomness(keyHash, oracleFee);
        requests2GameId[requestId] = _gameId;
        order[requestId] = 1;
    }

    function getRandForTurn(uint256 _gameId) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= oracleFee);
        
        bytes32 requestId = requestRandomness(keyHash, oracleFee);
        requests2GameId[requestId] = _gameId;
        order[requestId] = 2;
    }
    
    function getRandForWinner(uint256 _gameId, address winner) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= oracleFee);
        
        bytes32 requestId = requestRandomness(keyHash, oracleFee);
        requests[requestId]._gameId = _gameId;
        requests[requestId].winner = winner;
        order[requestId] = 3;
    }

    //this function is the first function that is called by the oracle after a random number request has been made
    function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external override{
        require(msg.sender == vrfCoordinator, "Only VRFCoordinator can fulfill");
        fulfillRandomness(requestId, randomness);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        if(order[requestId] == 1) {
            uint256 _gameId = requests2GameId[requestId];
            gameVariables[_gameId].currentTurn = uint8((randomness % 2)+1);
        }
        if(order[requestId] == 2){
            uint256 _gameId = requests2GameId[requestId];
            uint16[] memory rand = GameLib.expand(randomness, primes);
            setupTurn(_gameId, rand);
        }
        if(order[requestId] == 3) {
            uint256 _gameId = requests[requestId]._gameId;
            address winner = requests[requestId].winner;
            uint8 chosenCard = uint8(randomness % 20) + 1;
            uint8 choice = uint8(randomness % 2);
            bool choice2 = ((randomness % primes[choice]) % 2 == 0) ? (true) : (false) ;
            if(winner == gameVariables[_gameId].player1){
                uint16 card = gameVariables[_gameId].p1Cards[chosenCard];
                GameLib.upgradeCard(card,stats,choice,choice2);
            }else {
                uint16 card = gameVariables[_gameId].p2Cards[chosenCard];
                GameLib.upgradeCard(card,stats,choice,choice2);
            }
        }
        else{
            "We've got a fookin problem";
        }
    }



}