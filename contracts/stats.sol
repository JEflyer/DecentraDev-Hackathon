//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import stats struct
import "./structs/statsStruct.sol";

//import stats library
import "./libraries/statLib.sol";

//import chainlink API call client
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract Stats is ChainlinkClient{

    event StatChange(string stat, uint difference);
    event NewAdmin(address newAdmin);

    using Chainlink for Chainlink.Request;

    //oracle vars
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    //keep track of admin wallet
    address private admin;

    //keep track of the game address
    address private game;

    //keep track of the minter address
    address private minter;
    
    //mapping for keeping a track of the base stats for each card  0 -149
    mapping(uint8 => StatsStruct) private baseStats;

    //mapping for keeping a track of a tokens current stats
    mapping(uint16 => StatsStruct) private currentStats;

    //mapping for keeping a track of the cardtype
    mapping(uint16 => uint8) private card;

    //for making different calls to the metadata
    string[] private statCategories = [
        "health",
        "noOfAttacks",
        "attackOneDamage",
        "attackOneEnergyCost",
        "attackTwoDamage",
        "attackTwoEnergyCost",
        "element"
    ];

    //define struct for reuest data
    struct data {
        uint8 statBeingUpdated;
        uint8 cardBeingUpdated;
    }

    //mapping to keep track of the request ID => stat being assigned
    mapping(bytes32 => data) private requests;

    constructor(
        address _game,
        address _minter,
        address _oracle,
        bytes32 _jobId,
        uint256 _fee
    ) {
        game = _game;
        minter = _minter;

        //setting up oracle
        setPublicChainlinkToken();
        oracle = _oracle;
        jobId = _jobId;
        fee = _fee;
    }

    modifier onlyAdmin{
        require(msg.sender == admin);
        _;
    }

    modifier onlyGame {
        require(msg.sender == game);
        _;
    }

    modifier onlyMinter{
        require(msg.sender == minter);
        _;
    }

    function setBaseStats(uint16[] memory ids, uint8[] memory rands) external onlyMinter returns(bool){
        for(uint i = 0; i< ids.length; i++){
            currentStats[ids[i]] = baseStats[rands[i]];
            card[ids[i]] = rands[i];
        }
        return true;
    }

    function callBaseStats(uint8 from, uint8 to) external onlyAdmin{
        for(uint8 i = from; i<= to; i++){
            _callBaseStats(i);
        }
    }

    function _callBaseStats(uint8 num) internal {
        for(uint8 i =0; i< 7; i++){
            //build request
            Chainlink.Request memory request = buildChainlinkRequest(jobId,address(this),this.fulfill.selector);
            
            //declare the link being called
            request.add("get", string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/SOME_HASH_HERE/",string(abi.encodePacked(num)), ".JSON")));
            
            //declaring navigation path throguh json file
            string memory pathToStat = string(abi.encodePacked("stats.",statCategories[i]));
            request.add("path",pathToStat);

            //send request get request id
            bytes32 id = sendChainlinkRequestTo(oracle, request, fee);

            //log data
            requests[id].statBeingUpdated = i;
            requests[id].cardBeingUpdated = num;

        }
    }

    function fulfill(bytes32 _requestId, uint8 _stat) public recordChainlinkFulfillment(_requestId){
        data memory info = requests[_requestId];
        
        //the card that is having it's stat upgraded
        baseStats[info.cardBeingUpdated];

        // if statements to define course of action 
        if (info.statBeingUpdated == 0){
            baseStats[info.cardBeingUpdated].health = _stat;
        }
        if (info.statBeingUpdated == 1){
            baseStats[info.cardBeingUpdated].noOfAttacks = _stat;
        }
        if (info.statBeingUpdated == 2){
            baseStats[info.cardBeingUpdated].attackOneDamage = _stat;
        }
        if (info.statBeingUpdated == 3){
            baseStats[info.cardBeingUpdated].attackOneEnergyCost = _stat;
        }
        if (info.statBeingUpdated == 4){
            baseStats[info.cardBeingUpdated].attackTwoDamage = _stat;
        }
        if (info.statBeingUpdated == 5){
            baseStats[info.cardBeingUpdated].attackTwoEnergyCost = _stat;
        }
        if (info.statBeingUpdated == 6){
            baseStats[info.cardBeingUpdated].element = _stat;
            baseStats[info.cardBeingUpdated].strength = statsLib.getStrength(_stat);
            baseStats[info.cardBeingUpdated].weakness = statsLib.getWeakness(_stat);
        }
    }

    function updateAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function updateGameContract(address _game) external onlyAdmin {
        game = _game;
    }

    function updateMinterContract(address _minter) external onlyAdmin {
        minter = _minter;
    }

    //getter functions
    function getHP(uint16 token) external view returns(uint8){
        return currentStats[token].health;
    }

    function getNoOfAttacks(uint16 token) external view returns(uint8){
        return currentStats[token].noOfAttacks;
    }

    function getAttackDamage(bool which, uint16 token) external view returns(uint8){
        if(which){//if true get attack 1 DMG
            return currentStats[token].attackOneDamage;
        } else {
            return currentStats[token].attackTwoDamage;
        }
    }

    function getAttackEnergyCost(bool which, uint16 token) external view returns (uint8){
        if(which){//if true get attack 1 EC
            return currentStats[token].attackOneEnergyCost;
        }else{
            return currentStats[token].attackTwoEnergyCost;
        }
    }

    function getElement(uint16 token) external view returns(uint8){
        return currentStats[token].element;
    }

    function getStrength(uint16 token) external view returns(uint8){
        return currentStats[token].strength;
    }

    function getWeakness(uint16 token) external view returns(uint8){
        return currentStats[token].weakness;
    }

    function getBaseStats(uint8 _card) external view returns(StatsStruct memory) {
        return baseStats[_card];
    }

    function getCurrentStats(uint16 token) external view returns(StatsStruct memory) {
        return currentStats[token];
    }

    //upgrade functions
    function upgradeHp(uint16 token,uint8 amount) external onlyGame returns(bool){
        require(currentStats[token].health + amount <= 255);
        currentStats[token].health += amount;
        currentStats[token].noOfUpgrades +=1;
        return true;
    }

    function upgradeAttackDamage(uint16 token, bool which, uint8 amount)external onlyGame returns(bool){
        if(which) {//attack 1
            require(currentStats[token].attackOneDamage + amount <= 255);  
            currentStats[token].noOfUpgrades +=1;
            currentStats[token].attackOneDamage += amount;
            return true;
        }else {//attack 2
            require(currentStats[token].attackTwoDamage + amount <= 255);
            currentStats[token].noOfUpgrades +=1;
            currentStats[token].attackTwoDamage += amount;
            return true;
        }
    }

}