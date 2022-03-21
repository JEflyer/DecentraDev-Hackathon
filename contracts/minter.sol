pragma solidity 0.8.7;

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
    event Revealed();
    event Mint(uint16 tokenId);

    //as it says on the tin
    address[] private paymentsTo;
    uint16[] private shares;

    //keeps track of permissioned wallet & the admin
    address private admin;
    address private permissionedWallet;

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
    
    //keeps track of if the NFT image is revealed or not
    bool private revealed;

    //for keeping track of the stat Contract Address
    address private statsAddress;

    //tokenId => 0-149 card no.
    mapping(uint16 => uint8) cardType;

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _oracleFee,
        address[] memory _to,
        uint16[] memory _shares,
        uint256 _price,
    ) ERC721("Name","Symbol") VRFConsumerBase(_vrfCoordinator, _linkToken){
        require(_to.length == _shares.length);
        linkToken = _linkToken;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        oracleFee = _oracleFee;
        active = false;
        revealed = false;
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

    //allow only permissioned or admin
    modifier onlyAllowed{
        require(_msgSender() == admin || _msgSender() == permissionedWallet);
        _;
    }

    function flipSaleState() external onlyAdmin {
        active = !active;
    }

    //change admin wallet
    function updateAdmin(address _new) external onlyAdmin{
        admin = _new;
    }

    //update payments
    function updatePayments(address[] memory _to, uint16[] memory _shares) external onlyAdmin {
        require(_to.length == _shares.length);
        paymentsTo = _to;
        shares = _shares;
    }

    function getPrice(uint8 amount) public view returns(uint256){
        return MinterLib.getPrice(amount, totalMinted, price);
    }

    function updateStatsContract(address _contract) external onlyAdmin {
        statsAddress = _contract;
    }

    //automatically splits funds between designated wallets
    function splitFunds(uint256 fundsToSplit) public payable {
        uint16 totalShares = MinterLib.totalShares(shares);

        for(uint i=0; i<shares.length; i++){
            require(payable(paymentsTo[i]).transfer(fundsToSplit * shares[i]/totalShares));
        }
    }

    //passed the msg.value to the above function
    receive() external payable {
        splitFunds(msg.value);
    }

    function mint(uint8 amount) external payable{
        require(active);
        require(amount <=10 && amount >0);
        require(amount +totalMinted <= totalLimit);
        require(msg.value == getPrice(amount));


        splitFunds(msg.value);

        uint16[] tokens = MinterLib.getTokens(amount, totalMinted);

        if(MinterLib.crossesThreshold(amount, totalMinted)){
            MinterLib.updatePrice(price);
        }

        if(totalMinted+amount > totalLimit*20/100){
            revealed = true;
        }

        totalMinted +=amount;

        getRandomNumber(tokens);
    }

    function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external override{
        require(_msgSender() == vrfCoordinator, "Only VRFCoordinator can fulfill");
        fulfillRandomness(requestId, randomness);
    }

    function getRandomNumber(uint16[] tokenIds) internal {
        require(LinkTokenInterface(linkToken).balanceOf(address(this)) >= fee);
        
        bytes32 requestId = requestRandomness(keyHash, fee);
        mintTo[requestId] = _msgSender();
        requests[requestId] = tokenIds;
    }

   

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint16[] ids = requests[requestId];
        address to = mintTo[requestId];
    
        uint8[ids.length] randNums = MinterLib.RNG(ids.length, randomness);

        for(uint8 i =0; i<ids.length; i++){
            _mint(to, ids[i]);
            emit mint(ids[i]);
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

        if(!revealed) {uri = string(abi.encodePacked(baseURI, notRevealed));}
        else{uri = string(abi.encodePacked(baseURI, ciD, string(abi.encodePacked(cardType[_tokenId])), extension));}

    }


    function setBase(string memory _base) external onlyAdmin {
        baseURI = _base;
    }

    function setCID(string memory _ciD) external onlyAdmin {
        ciD = _ciD;
    }

    function setNot(string memory _not) external onlyAdmin {
        notRevealed = _not;
    }

    function setExt(string memory _ext) external onlyAdmin {
        extension = _ext;
    }

}