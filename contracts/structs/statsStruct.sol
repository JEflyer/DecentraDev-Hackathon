//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

struct StatsStruct {
    uint8 health;

    uint8 noOfAttacks;
    
    uint8 attackOneDamage;
    
    uint8 attackTwoDamage;
    
    uint8 element;//0-7, 8 total elements
    uint8 strength;
    uint8 weakness;
    
    uint16 noOfUpgrades;
}