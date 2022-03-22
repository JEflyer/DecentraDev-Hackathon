//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import IMinter
import "./interfaces/IMinter.sol";

contract DealMinter{
    
    //for keeping track of the cards that can be minted in a particular deal & whether or not the deal is still active
    struct Deal {
        uint8[] cards;
        bool active;
    }

    //store address for minter
    address private minter;

    //store admin wallet
    address private admin;

    //store dealNo. => Deal
    mapping(uint8 => Deal) private deals;

    //keeps a track of the current deal number
    uint8 private dealNo;

    constructor(
        address _minter
    ){
        minter = _minter;
        admin = msg.sender;
        dealNo = 0;
    }

    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }

    //allows the admin to update the minter contract address
    function updateMinter(address _new) external onlyAdmin{
        minter = _new;
    }

    //allows the admin to add a new set of cards as mintable
    function addDeal(uint8[] memory cards) external onlyAdmin{
        require(dealNo < 100);
        dealNo +=1;
        deals[dealNo].cards = cards;
        deals[dealNo].active = true;
    }

    //allows the admin to end a deal
    function endDeal(uint8 _dealNo) external onlyAdmin{
        deals[_dealNo].active = false;
    }

    //allows a used to buy a specific set of cards
    function buyDeal(uint8 _dealNo) external payable {
        require(_dealNo <= dealNo && _dealNo > 0);
        require(deals[_dealNo].active == true);
        
        uint8 amount = uint8(deals[_dealNo].cards.length);
        
        uint256 price = IMinter(minter).getPrice(amount);
        
        require(msg.value == price);
        
        bool success = IMinter(minter).mintSpecificFor{value: msg.value}(
                            amount,
                            deals[_dealNo].cards,
                            msg.sender);
        require(success);
    }

}