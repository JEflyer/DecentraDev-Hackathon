//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library energyLib {

    function sum(uint256[] memory data) internal pure returns(uint8 value){
        for(uint i=0; i< data.length; i++){
            value += uint8(data[i]);
        }
    }

    function totalShares(uint16[] memory shares) internal pure returns(uint16 result ){
        result = 0;
        for(uint i=0; i< shares.length; i++){
            result += shares[i];
        }
    }
}