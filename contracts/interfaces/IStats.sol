pragma solidity ^0.8.7;

interface IStats {
    function setBaseStats(uint16[] ids, uint8[] rands) external returns(bool);
}