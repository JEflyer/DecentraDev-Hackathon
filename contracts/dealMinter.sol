//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import IMinter
import "./interfaces/IMinter.sol";

contract DealMinter{
    
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

    function updateMinter(address _new) external onlyAdmin{
        minter = _new;
    }

    function addDeal(uint8[] memory cards) external onlyAdmin{
        require(dealNo < 100);
        dealNo +=1;
        deals[dealNo].cards = cards;
        deals[dealNo].active = true;
    }

    function endDeal(uint8 _dealNo) external onlyAdmin{
        deals[_dealNo].active = false;
    }

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