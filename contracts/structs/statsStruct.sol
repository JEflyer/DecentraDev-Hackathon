pragma solidity ^0.8.7;

struct StatsStruct {
    uint16 health;

    uint8 noOfAttacks;
    
    uint16 attackOneDamage;
    uint8 attackOneEnergyCost;
    
    uint16 attackTwoDamage;
    uint8 attackTwoEnergyCost;
    
    uint8 element;//0-10, 11 total elements
    uint8 strength;//2x more effective against
    uint8 weakness;//50% less effective against
    
    uint16 noOfUpgrades;
}