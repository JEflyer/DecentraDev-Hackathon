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
        bool open;
    }

    struct playedCards {
        uint16[] player1Hand;
        uint16[] player1Deck;
        uint16[] player2Hand;
        uint16[] player2Deck;
        uint16[] player1KnockOut;
        uint16[] player2KnockOut;
        uint16[] player1PlayedCards;
        uint16[] player2PlayedCards;
        uint8[] player1HeldEnergy;
        uint8[] player2HeldEnergy;
        uint8[] player1DeckEnergy;
        uint8[] player2DeckEnergy;
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
    //how to do multiple actions with limited variables
    //First we need to check whether a player wants to complete an action, this could be done with 
    //a bool[] true for if action was completed false otherwise
    //then we need to check what card that action was happening to this could be using a uint8[] where the index is equal to the index of the bool[]
    //then we need to check what attack is being used, we ca use a uint8 for this, 0 = no attack, 1= attack1, 2 = attack2
    function takeTurn(
        uint256 _gameId,
        bool[] memory actions,
        uint8[] memory commands
    ) external {
        //check that the game is open to having a turn submitted
        require(gameVariables[_gameId].open);

        bool player;//false/0 means msg.sender == player1, true/1 means msg.sender == player2
        //check that for gameId it is msg.sender's turn
        if(gameVariables[_gameId].player1 == msg.sender){
            require(gameVariables[_gameId].currentTurn == 1);
            player = false;
        } else if(gameVariables[_gameId].player2 == msg.sender){
            require(gameVariables[_gameId].currentTurn == 2);
            player = true;
        }else {
            revert();
        }

        //take actions
        for(uint8 i=0; i< actions.length; i++){
            if(actions[i]){
                if(i == 0){//place monster card - auto choose whether on bench or main
                    //commands[i] is the index of the monster card in hands being placed
                    if(player){//player1
                        //insert chosen card into played cards
                        cardsPlayed[_gameId].player1PlayedCards = GameLib.getNewPlayedCards(
                            cardsPlayed[_gameId].player1PlayedCards, 
                            cardsPlayed[_gameId].player1Hand[commands[i]]
                            );

                        //remove chosen card from hand
                        cardsPlayed[_gameId].player1Hand = GameLib.getNewHandMinus(
                            cardsPlayed[_gameId].player1Hand,
                            commands[i]
                        );

                    }else {//player2
                        //insert chosen card into played cards
                        cardsPlayed[_gameId].player2PlayedCards = GameLib.getNewPlayedCards(
                            cardsPlayed[_gameId].player2PlayedCards, 
                            cardsPlayed[_gameId].player2Hand[commands[i]]
                            );

                        //remove chosen card from hand
                        cardsPlayed[_gameId].player2Hand = GameLib.getNewHandMinus(
                            cardsPlayed[_gameId].player2Hand,
                            commands[i]
                        );
                    }
                }
                if(i == 1){//switch monster card between main to bench
                    //commands[i] is the index of the card on bench beign switched to main position
                    if(player){//player1
                        cardsPlayed[_gameId].player1PlayedCards = GameLib.switchCard(
                            cardsPlayed[_gameId].player1PlayedCards,
                            commands[i]
                        );

                        //reorganise the energy array


                    }else {//player2
                        cardsPlayed[_gameId].player2PlayedCards = GameLib.switchCard(
                            cardsPlayed[_gameId].player2PlayedCards,
                            commands[i]
                        );

                        //reorganise the energy array

                    }
                }
                if(i == 2){//place energy card
                    //commands[i] is the index of the card in energy hand being placed
                    //commands[5] is the index of the card on field having the energy attached 
                    if(player){//player1
                        //assign energy to card
                        cardsPlayed[_gameId].player1AssignedEnergy = GameLib.AssignEnergy(
                            commands[5],
                            commands[i],
                            cardsPlayed[_gameId].player1AssignedEnergy
                        );

                        //remove card from the held energy
                        cardsPlayed[_gameId].player1HeldEnergy = GameLib.RemoveEnergy(
                            commands[i],
                            cardsPlayed[_gameId].player1HeldEnergy
                        );

                    }else {//player2
                        //assign energy to card
                        cardsPlayed[_gameId].player2AssignedEnergy = GameLib.AssignEnergy(
                            commands[5],
                            commands[i],
                            cardsPlayed[_gameId].player2AssignedEnergy
                        );

                        //remove card from the held energy
                        cardsPlayed[_gameId].player2HeldEnergy = GameLib.RemoveEnergy(
                            commands[i],
                            cardsPlayed[_gameId].player2HeldEnergy
                        );
                    }
                }
                if(i == 3){//switch energy card from one card to another card
                    //commands[i] is the index of the card having the energy removed
                    //commands[6] is the index of the card having the energy added to
                    if(player){//player1
                        //change energy count for relevant cards
                        cardsPlayed[_gameId].player1AssignedEnergy = GameLib.changeEnergy(
                            commands[i],
                            commands[6],
                            cardsPlayed[_gameId].player1AssignedEnergy
                        );
                    }else {//player2
                        //change energy count for relevant cards
                        cardsPlayed[_gameId].player2AssignedEnergy = GameLib.changeEnergy(
                            commands[i],
                            commands[6],
                            cardsPlayed[_gameId].player2AssignedEnergy
                        );
                    }
                }
                if(i == 4){//attack
                    //commands[i] is this will either be 0 - no attack, 1 - attack1, 2 - attack2 
                    if(player){//player1
                        //get attack stat for attacking card

                        //find out attack factor

                        //adjust current health stat for attacked card
                    }else {//player2
                        //get attack stat for attacking card

                        //find out attack factor

                        //adjust current health stat for attacked card
                    }
                }

                //VRF Request
                getRandForTurn(_gameId);
            }
        }

    }

    // struct playedCards {
    //     uint16[] player1Hand;
    //     uint16[] player1Deck;
    //     uint16[] player2Hand;
    //     uint16[] player2Deck;
    //     uint16[] player1KnockOut;
    //     uint16[] player2KnockOut;
    //     uint8[] player1HeldEnergy;
    //     uint8[] player2HeldEnergy;
    //     uint8[] player1DeckEnergy;
    //     uint8[] player2DeckEnergy;
    //     uint16[] player1PlayedCards;
    //     uint8[] player1AssignedEnergy;
    //     uint8[] player2AssignedEnergy;
    // }

    //this function is used for preturn actions
    function setupTurn(
        uint256 _gameId,
        uint16[] memory rand
    ) internal {
        if(gameVariables[_gameId].currentTurn == 1){
            //choose the card from the deck & assign to the players hand - p1
            uint8 chosenCardIndex = rand[1] % cardsPlayed[_gameId].player1Deck.length;
            uint16 chosenCard = cardsPlayed[_gameId].player1Deck[chosenCardIndex];

            cardsPlayed[_gameId].player1Deck = GameLib.getNewDeck(cardsPlayed[_gameId].player1Deck,chosenCardIndex);
            cardsPlayed[_gameId].player1Hand = GameLib.getNewHand(cardsPlayed[_gameId].player1Hand,chosenCard);

            //choose 1 energy from the energyDeck & assign to player
            uint8 chosenEnergyIndex = rand[2] % cardsPlayed[_gameId].player1DeckEnergy.length;
            uint8 chosenEnergy = cardsPlayed[_gameId].player1Deck[chosenEnergyIndex];
            cardsPlayed[_gameId].player1HeldEnergy = GameLib.getNewEnergyHand(cardsPlayed[_gameId].player1HeldEnergy, chosenEnergy);
            cardsPlayed[_gameId].player1DeckEnergy = GameLib.getNewEnergyDeck(cardsPlayed[_gameId].player1DeckEnergy, chosenEnergyIndex);
        } else {
            //choose the card from the deck & assign to the players hand - p2
            uint8 chosenCardIndex = rand[1] % cardsPlayed[_gameId].player2Deck.length;
            uint16 chosenCard = cardsPlayed[_gameId].player2Deck[chosenCardIndex];

            cardsPlayed[_gameId].player2Deck = GameLib.getNewDeck(cardsPlayed[_gameId].player2Deck,chosenCardIndex);
            cardsPlayed[_gameId].player2Hand = GameLib.getNewHand(cardsPlayed[_gameId].player2Hand,chosenCard);

            //choose 1 energy from the energyDeck & assign to player
            uint8 chosenEnergyIndex = rand[2] % cardsPlayed[_gameId].player2DeckEnergy.length;
            uint8 chosenEnergy = cardsPlayed[_gameId].player2Deck[chosenEnergyIndex];
            cardsPlayed[_gameId].player2HeldEnergy = GameLib.getNewEnergyHand(cardsPlayed[_gameId].player2HeldEnergy, chosenEnergy);
            cardsPlayed[_gameId].player2DeckEnergy = GameLib.getNewEnergyDeck(cardsPlayed[_gameId].player2DeckEnergy, chosenEnergyIndex);
        }

        

        //open turn for the next player 
        gameVariables[_gameId].open = true;

    }


    //surrender function to allow games to be quit mid game aslong as 1 side wants to quit, the opponent is by default the winner
    function surrender(uint256 _gameId) external {
        if(msg.sender == gameVariables[_gameId].player1){
            //register the user that wants to surrender
            gameVariables[_gameId].active = false;
            split(_gameId, gameVariables[_gameId].player2);
            
        }
        else if(msg.sender == gameVariables[_gameId].player2){
            gameVariables[_gameId].active = false;
            split(_gameId, gameVariables[_gameId].player1);
            //register the user that wants to surrender
        } else {
            revert();
        }
    }

    //split funds between winner & community wallet
    function split(uint256 _gameId, address winner) internal payable {
        //calclulates the split 95% to winner, 5% to a community wallet
        (uint256 _winnerPayout, uint256 _communityPayout) = GameLib.getPayouts(gameVariables[_gameId].pot);
        payable(winner).transfer(_winnerPayout);
        payable(community).transfer(_communityPayout);
    }

    //vrf request for random number
    function getRandForStart(uint256 _gameId) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= oracleFee);
        
        bytes32 requestId = requestRandomness(keyHash, oracleFee);
        requests2GameId[requestId] = _gameId;
        order[requestId] = 1;
    }

    //turn end VRF call
    function getRandForTurn(uint256 _gameId) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= oracleFee);
        
        bytes32 requestId = requestRandomness(keyHash, oracleFee);
        gameVariables[_gameId].open = false;
        requests2GameId[requestId] = _gameId;
        order[requestId] = 2;
    }
    
    //game end VRF call
    function getRandForWinner(uint256 _gameId, address winner) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= oracleFee);
        
        bytes32 requestId = requestRandomness(keyHash, oracleFee);
        requests[requestId]._gameId = _gameId;
        requests[requestId].winner = winner;
        order[requestId] = 3;
        gameVariables[_gameId].open = false;
        
    }

    //this function is the first function that is called by the oracle after a random number request has been made
    function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external override{
        require(msg.sender == vrfCoordinator, "Only VRFCoordinator can fulfill");
        fulfillRandomness(requestId, randomness);
    }

    //this function is called by the VRF oracle & the job will be completed according to the order set
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        if(order[requestId] == 1) {
            uint256 _gameId = requests2GameId[requestId];
            gameVariables[_gameId].currentTurn = uint8((randomness % 2)+1);
            uint16[] memory rand = GameLib.expand(randomness, primes);
            cardsPlayed[_gameId].player1Hand = GameLib.getHand(gameVariables[_gameId].p1Cards, rand);
            cardsPlayed[_gameId].player2Hand = GameLib.getHand(gameVariables[_gameId].p2Cards, rand);
            cardsPlayed[_gameId].player1HeldEnergy = GameLib.getEnergy(gameVariables[_gameId].p1Energy, rand);
            cardsPlayed[_gameId].player2HeldEnergy = GameLib.getEnergy(gameVariables[_gameId].p2Energy, rand);
            cardsPlayed[_gameId].player1DeckEnergy = GameLib.getDeckEnergy(gameVariables[_gameId].p1Energy, cardsPlayed[_gameId].player1HeldEnergy);
            cardsPlayed[_gameId].player2DeckEnergy = GameLib.getDeckEnergy(gameVariables[_gameId].p2Energy, cardsPlayed[_gameId].player2HeldEnergy);
            gameVariables[_gameId].open = true;
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
    }
}