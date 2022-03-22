//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library energyLib {

    //used for iterating through an array & calculating the sum of the values found
    function sum(uint256[] memory data) internal pure returns(uint8 value){
        for(uint8 i=0; i< data.length; i++){
            value += uint8(data[i]);
        }
    }

    //the exact same thing as the function above but with different data types in inputs & outputs
    function totalShares(uint16[] memory shares) internal pure returns(uint16 result ){
        result = 0;
        for(uint i=0; i< shares.length; i++){
            result += shares[i];
        }
    }
}