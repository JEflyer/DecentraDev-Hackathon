// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// import the OZ 1155 standard and ownable contract 

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//import library
import "./libraries/energyLib.sol";

// initialize our contract
contract EnergyCards is ERC1155, Ownable {

  // currentMinted mapping for tokenIDs
  mapping (uint256 => uint256) private currentMinted;

  //as it says on the tin
  address[] private paymentsTo;
  uint16[] private shares;

  // pause or unpause contract
  bool public paused = false;

  //keeps track of the price
  uint256 private price;

  // set TokenIds
  uint8 public constant Fire = 1;
  uint8 public constant Water = 2;
  uint8 public constant Electric = 3;
  uint8 public constant Land = 4;
  uint8 public constant Grass = 5;
  uint8 public constant Shadow = 6;
  uint8 public constant Flying = 7;
  uint8 public constant Poison = 8;

  // constructor
  constructor(
    uint16[] memory _shares,
    address[] memory _paymentsTo,
    string memory uri,
    uint256 _price
  ) ERC1155 (uri) {
    paymentsTo = _paymentsTo;
    shares = _shares;
    price = _price;
  }

  // only owner functions

  //allows the admin to change the addresses being paid & the shares being paid out
  function updatePayments(address[] memory _to, uint16[] memory _shares) external onlyOwner {
    require(_to.length == _shares.length);
    paymentsTo = _to;
    shares = _shares;
  }

  //allows the admin to pause or unpause the contract
  function pause(bool _state) public onlyOwner {
    paused = _state;
  }

  //allows the admin to change the URI/CID hash
  function setUri(string memory newUri) public onlyOwner {
    _setURI(newUri);
  }

  //mint a energy card
  function mint(address _to, uint256 _tokenID, uint256 _amount) public payable {
    require(!paused, "Contract is currently paused"); // Checks to make sure contract isnt paused
    require(_amount > 0, "You must enter an amount to mint");
    require(_amount >= 10);
    require(_amount + currentMinted[_tokenID] <= 500, "This energy card is sold out");
    require(msg.value == _amount*price);
    splitFunds(msg.value);
    currentMinted[_tokenID] += _amount;
    _mint(_to, _tokenID, _amount, "");
  }

  //mint multiple energy cards but with mixed amounts & ids
  //this mint still has a max of 10 mints
  function mintBatch(address _to, uint256[] memory _tokenIDs, uint256[] memory _amounts) public payable {
    require(!paused, "Contract is currently paused");
    uint8 sum = energyLib.sum(_amounts);
    require(sum > 0, "You must enter a valid amount to mint" );
    require(sum <= 10, "Amounts cannot exceed 10");
    require(msg.value == sum*price);
    splitFunds(msg.value);

    
    for(uint i = 0; i < _amounts.length; i++){
        require(_amounts[i] + currentMinted[_tokenIDs[i]] <= 500, "One or more of these energy cards is sold out!");
        currentMinted[_tokenIDs[i]] += _amounts[i];
    }
    
    
    _mintBatch(_to, _tokenIDs, _amounts, "");
  }

  //automatically splits funds between designated wallets
  function splitFunds(uint256 fundsToSplit) public payable {
    uint16 totalShares = energyLib.totalShares(shares);

    for(uint i=0; i<shares.length; i++){
        require(payable(paymentsTo[i]).send(fundsToSplit * shares[i]/totalShares));
    }
  }

  //passed the msg.value to the above function
  receive() external payable {
    splitFunds(msg.value);
  }

}