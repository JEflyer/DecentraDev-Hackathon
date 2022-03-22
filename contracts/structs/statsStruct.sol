//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

struct StatsStruct {
    uint8 health;

    uint8 noOfAttacks;
    
    uint8 attackOneDamage;
    uint8 attackOneEnergyCost;
    
    uint8 attackTwoDamage;
    uint8 attackTwoEnergyCost;
    
    uint8 element;//0-10, 11 total elements
    uint8 strength;//2x more effective against
    uint8 weakness;//50% less effective against
    
    uint16 noOfUpgrades;
}