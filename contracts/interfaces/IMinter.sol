//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IMinter{
    function walletOfOwner(address _wallet) external view  returns(uint16[] memory ids);

    function mintSpecificFor(uint8 amount,uint8[] memory cards, address to) external payable returns(bool);

    function getPrice(uint8 amount) external view returns(uint256);
}