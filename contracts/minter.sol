//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import Enumerable extension
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

//import VRFConsumerBase
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

//import IStats Interface
import "./interfaces/IStats.sol";

//import LINK interface
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

//import minterLib
import "./libraries/minterLib.sol";

contract Minter is ERC721Enumerable, VRFConsumerBase {

    event NewAdmin(address newAdmin);
    event PriceIncrease(uint256 newPrice);
    event Mint(uint16 tokenId);

    //used for splitting 1 random number into upto 10 different random numbers
    uint16[] primes = [
        2909,
        2753,
        3593,
        3461,
        3797,
        4391,
        5647,
        4441,
        4621,
        5333
    ];

    //as it says on the tin
    address[] private paymentsTo;
    uint16[] private shares;

    //keeps track of permissioned wallet & the admin
    address private admin;

    //keeps track of the price 
    uint256 private price;

    //bool used to keep track of if sale is active or not
    bool private active;

    //metadata URI vars
    string private baseURI = "https://gateway.pinata.cloud/ipfs/";
    string private ciD = "Some CID/";
    string private extension = ".JSON";
    string private notRevealed = "NotRevealed Hash";

    //for keeping track of oracle requests
    //request ID => tokenIds Minted
    mapping(bytes32 => uint16[]) requests;

    //requestId => receiver
    mapping(bytes32 => address) mintTo;

    //for keeping track of details needed to make a oracle VRF request
    bytes32 private keyHash;
    uint256 private oracleFee;
    address private vrfCoordinator;
    address private linkToken;

    //current minted amount
    uint16 private totalMinted = 0;

    //total amount of mints allowed
    uint16 private totalLimit = 10000;

    //for keeping track of the stat Contract Address
    address private statsAddress;

    //for keeping track of the deal contract address
    address private dealAddress;

    //tokenId => 0-149 card no.
    mapping(uint16 => uint8) cardType;

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _oracleFee,
        address[] memory _to,
        uint16[] memory _shares,
        uint256 _price
    ) ERC721("Name","Symbol") VRFConsumerBase(_vrfCoordinator, _linkToken){
        require(_to.length == _shares.length);
        linkToken = _linkToken;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        oracleFee = _oracleFee;
        active = false;
        admin = _msgSender();
        paymentsTo = _to;
        shares = _shares;
        price = _price;
    }

    //allow only admin
    modifier onlyAdmin{
        require(_msgSender() == admin);
        _;
    }

    //pause & unpause the minting on demand
    function flipSaleState() external onlyAdmin {
        active = !active;
    }

    //allow admin to change admin wallet
    function updateAdmin(address _new) external onlyAdmin{
        admin = _new;
    }

    //allow the admin to update the payments & shares
    function updatePayments(address[] memory _to, uint16[] memory _shares) external onlyAdmin {
        require(_to.length == _shares.length);
        paymentsTo = _to;
        shares = _shares;
    }

    //calls the minter library & calculates the price
    function getPrice(uint8 amount) public view returns(uint256){
        return MinterLib.getPrice(amount, totalMinted, price);
    }

    //allows the admin to update the stat contract address
    function updateStatsContract(address _contract) external onlyAdmin {
        statsAddress = _contract;
    }

    //allows the admin to update the deal contract address
    function updateDealContract(address _contract) external onlyAdmin{
        dealAddress = _contract;
    }

    //automatically splits funds between designated wallets
    function splitFunds(uint256 fundsToSplit) public payable {
        uint16 totalShares = MinterLib.totalShares(shares);

        for(uint i=0; i<shares.length; i++){
            require(payable(paymentsTo[i]).send(fundsToSplit * shares[i]/totalShares));
        }
    }

    //passed the msg.value to the above function
    receive() external payable {
        splitFunds(msg.value);
    }

    //no, you don't get a description
    function mint(uint8 amount) external payable{
        require(active);
        require(amount <=10 && amount >0);
        require(amount +totalMinted <= totalLimit);
        require(msg.value == getPrice(amount));


        splitFunds(msg.value);

        uint16[] memory tokens = MinterLib.getTokens(amount, totalMinted);

        if(MinterLib.crossesThreshold(amount, totalMinted)){
            MinterLib.updatePrice(price);
        }

        for(uint8 i =1; i<=amount; i++){
            totalMinted +=1;
            _mint(msg.sender, totalMinted);
            emit Mint(totalMinted);
        }

        getRandomNumber(tokens);
    }

    //this function calls with a preassignd set of cards, this function can only be called by the deals contract
    function mintSpecificFor(uint8 amount,uint8[] memory cards, address to) external payable returns(bool){
        require(amount == cards.length);
        require(active);
        require(amount <=10 && amount >0);
        require(amount +totalMinted <= totalLimit);
        require(msg.value == getPrice(amount));
        require(msg.sender == dealAddress);

        uint16[] memory ids;
        for(uint8 i =0; i<cards.length; i++){
            totalMinted +=1;
            ids[i] = totalMinted;
            _mint(to, cards[i]);
            emit Mint(cards[i]);
            cardType[totalMinted] = cards[i];

        }

        //send this to stat contract
        bool success = IStats(statsAddress).setBaseStats(ids, cards);
        require(success);
        return true;

    }

    //this function is the first function that is called by the oracle after a random number request has been made
    function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external override{
        require(_msgSender() == vrfCoordinator, "Only VRFCoordinator can fulfill");
        fulfillRandomness(requestId, randomness);
    }

    //our internal function for making the request & storing the data required for the function return
    function getRandomNumber(uint16[] memory tokenIds) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= oracleFee);
        
        bytes32 requestId = requestRandomness(keyHash, oracleFee);
        mintTo[requestId] = _msgSender();
        requests[requestId] = tokenIds;
    }

   
    //first we gather the information from before our request
    //then we use the library function RNG to split 1 random number into ids.length^th of times
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint16[] memory ids = requests[requestId];
        address to = mintTo[requestId];
    
        uint8[] memory randNums = MinterLib.RNG(uint8(ids.length), randomness, primes);

        for(uint8 i =0; i<ids.length; i++){
            cardType[ids[i]] = randNums[i];

        }

        //send this to stat contract
        bool success = IStats(statsAddress).setBaseStats(ids, randNums);
        require(success);

    }


    //returns an array of tokens held by a wallet
    function walletOfOwner(address _wallet) external view  returns(uint16[] memory ids){
        uint16 ownerTokenCount = uint16(balanceOf(_wallet));
        ids = new uint16[](ownerTokenCount);
        for(uint16 i = 0; i< ownerTokenCount; i++){
            ids[i] = uint16(tokenOfOwnerByIndex(_wallet, i));
        }
    }

    //checks if token exists
    //if unrevealed returns unrevealed NFT API link
    //otherwise converts tokenId to string & concatenates all parts together
    function tokenURI(uint16 _tokenId) public view virtual returns(string memory uri){
        require(_exists(_tokenId));

        if(totalMinted < 2000) {uri = string(abi.encodePacked(baseURI, notRevealed));}
        else{uri = string(abi.encodePacked(baseURI, ciD, string(abi.encodePacked(cardType[_tokenId])), extension));}

    }

    //allows the admin to change the base URI
    function setBase(string memory _base) external onlyAdmin {
        baseURI = _base;
    }

    //allows the admin to change the CID hash
    function setCID(string memory _ciD) external onlyAdmin {
        ciD = _ciD;
    }

    //allows the admin to change the notRevealed hash
    function setNot(string memory _not) external onlyAdmin {
        notRevealed = _not;
    }

    //allows the admin to change the extension default ".JSON"
    function setExt(string memory _ext) external onlyAdmin {
        extension = _ext;
    }

}