pragma solidity ^0.8.7;

//import stats struct
import "./structs/statsStruct.sol";

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
        "stuff here",
        "More stuff",
    ]

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
        string memory _jobId,
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

    function setBaseStats(uint16[] ids, uint8[] rands) external onlyMinter returns(bool){
        for(uint i = 0; i< ids.length; i++){
            currentStats[ids[i]] = baseStats[rands[i]];
        }
        return true;
    }

    function callBaseStats(uint8 from, uint8 to) external onlyAdmin{
        for(uint i = from; i<= to; i++){
            _callBaseStats(i);
        }
    }

    function _callBaseStats(uint8 num) internal {
        for(uint i =0; i< statCategories.length; i++){
            //build request
            Chainlink.Request memory request = buildChainlinkRequest(jobId,address(this),this.fulfill.selector);
            
            //declare the link being called
            request.add("get", abi.encodePacked("https://gateway.pinata.cloud/ipfs/",CID,string(abi.encodePacked(num)), ".JSON"));
            
            //declaring navigation path throguh json file
            string pathToStat = string(abi.encodePacked("stats.",statCategories[i]));
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
        baseStats[info.cardBeingUpdated]

        // if statements to define course of action 
    }


}