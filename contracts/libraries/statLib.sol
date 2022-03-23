//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library statsLib {

    //for a given stat this function returns the element it is strong against
    function getStrength(uint8 _stat) internal pure returns(uint8 stat){
        if(_stat == 0){//Fire
            stat = 4;
        }
        if(_stat == 1){//Water
            stat = 0;
        }
        if(_stat == 2){//Electric
            stat = 1;
        }
        if(_stat == 3){//Land
            stat = 2;
        }
        if(_stat == 4){//Grass
            stat = 3;
        }
        if(_stat == 5){//Shadow
            stat = 6;
        }
        if(_stat == 6){//Flying
            stat = 7;
        }
        if(_stat == 7){//Poison
            stat = 5;
        }
    }

    //for a given stat this function returns the stat it is weakest against
    function getWeakness(uint _stat) internal pure returns(uint8 stat){
        if(_stat == 0){//Fire
            stat = 1;
        }
        if(_stat == 1){//Water
            stat = 2;
        }
        if(_stat == 2){//Electric
            stat = 3;
        }
        if(_stat == 3){//Land
            stat = 4;
        }
        if(_stat == 4){//Grass
            stat = 0;
        }
        if(_stat == 5){//Shadow
            stat = 7;
        }
        if(_stat == 6){//Flying
            stat = 5;
        }
        if(_stat == 7){//Poison
            stat = 6;
        }
    }
}