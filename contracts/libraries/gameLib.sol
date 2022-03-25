//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import IMinter
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//import IERC1155
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

//import IStats
import "../interfaces/IStats.sol";

library GameLib {

    //check that each token is owned by the owner
    function ownsAllCards(uint16[20] memory cards, address minter) internal view returns (bool) {
        for(uint8 i = 0; i< 20; i++){
            require(IERC721(minter).ownerOf(cards[i]) == msg.sender);
        }
        return true;
    }

    //count the amounts of each type of energy
    //check that the user owns a higher than or equal balance of the energy requesting to be used
    function ownsEnergyCards(uint8[10] memory cards, address energy) internal view returns (bool) {
        uint8[] memory counts = new uint8[](8);
        uint8 i = 0;
        for(i = 0; i < 10; i++){
            counts[cards[i]] +=1;
        }

        uint16[] memory owned = new uint16[](8);

        for (i = 0 ; i<8 ; i++){
            owned[i] = uint16(IERC1155(energy).balanceOf(msg.sender, i));
        }

        for(i=0; i < 8; i++) {
            require(owned[i] >= counts[i]);
        }

        return true;

    }

    function expand(uint256 rand, uint16[] memory primes) internal pure returns (uint16[] memory answers){
        for(uint8 i = 0; i< primes.length; i++) {
            answers[i] = uint16(rand % primes[i]);
        }
    }

    function upgradeCard(uint16 token, address stats,uint8 choice, bool choice2) internal {

        if(choice == 1){
            IStats(stats).upgradeAttackDamage(token, choice2, 1);
        }else {
            IStats(stats).upgradeHp(token, 2);
        }

    }
    
    //this is bugged, no track for cards already in the player hand - STILL TO DO
    function getHand(uint16[20] memory cards, uint16[] memory rand) internal pure returns(uint16[] memory hand){
        for(uint8 i=0; i< rand.length; i++){
            hand[i] = cards[rand[i] %20];
        }
    }

    //bugged the same as above - STILL TO DO
    function getEnergy(uint8[10] memory cards, uint16[] memory rand) internal pure returns(uint8[] memory hand){
        for(uint8 i =0; i<4; i++) {
            hand[i] = cards[rand[i] %10];
        }
    }

    function getDeck(uint16[20] memory cards, uint16[] memory hand) internal pure returns(uint16[] memory deck) {
        bool check;
        uint8 counter;
        for(uint8 i = 0; i< cards.length; i++){
            if(check){check = false;}
            for(uint8 j =0; j < hand.length; j++){
                if(cards[i] == hand[j]){
                    check = true;
                }
            }
            if(!check){
                deck[counter] = cards[i];
                counter +=1;
            }

        }
    }

    function getPayouts(uint256 amount) internal pure returns(uint256 winner, uint256 community){
        winner = amount*95/100;
        community = amount - winner;
    }
}