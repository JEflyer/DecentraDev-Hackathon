pragma solidity ^0.8.7;

library MinterLib {

    uint16[] constant primes = [
        2909,
        2753,
        3593,
        3461.
        3797,
        4391,
        5647,
        4441,
        4621,
        5333,
    ] 

    function RNG(uint8 length, uint256 rand) internal returns(uint8[] memory random){
        for(uint8 i = 0; i < length; i++){
            random[i] = uint8((rand % primes[i])%150);
        }
    }

    //does this need an explanation?
    event PriceIncrease(uint newPrice);

    //uses bit manipulation to double the price
    function updatePrice(uint _price)internal returns(uint price) {
        price = _price *105/100;
        emit PriceIncrease(price);
    }

    //checks if the amount crosses a multiple of 1000 & returns a bool
    function crossesThreshold(uint8 _amount, uint16 _totalSupply) internal pure returns (bool){
        if(_totalSupply+_amount < 1000) return false;
        uint16 remainder = (_totalSupply + _amount) % 1000;
        if(remainder >= 0 && remainder < 10) {
            return true;
        } else {
            return false;
        }
    }

    //get amounts on each side of the 1k split
    //for example: amount 5, totalSupply 998
    //amountBefore 2, amountAfter 3
    function getAmounts(uint8 _amount, uint16 _totalSupply) internal pure returns(uint8 amountBefore, uint8 amountAfter){
        for (uint i = 0; i < _amount; i++){
            if (crossesThreshold(i+1,_totalSupply)){
                amountBefore = uint8(i +1);
                amountAfter = uint8(_amount-amountBefore);
                break;
            }
        }
    }

    //gets the price for a given amount, price & current Minted amount
    //checks to see if the amount + current minted amount crosses the a multiple of 1000
    //if so it gets the amounts on each side & calculates the price accordingly
    function getPrice(uint8 _amount, uint price, uint16 totalMintSupply) internal pure returns(uint256 givenPrice){
        require(_amount <= 10, "Err: Too high");
        bool answer = crossesThreshold(_amount,totalMintSupply);
        if(answer){
            (uint8 amountBefore, uint8 amountAfter) = getAmounts(_amount,totalMintSupply);
            givenPrice = (price*amountBefore) + (price * 105/100 * amountAfter);
        } else {
            givenPrice = price * _amount;
        }
    }

    function totalShares(uint16[] memory shares) internal pure returns(uint16 result ){
        result = 0;
        for(uint i=0; i< shares.length; i++){
            result += shares[i];
        }
    }

    function getTokens(uint8 amount, uint16 totalMinted) internal returns(uint16[] memory tokens){
        for(uint8 i = 1; i<= amount; i++){
            tokens[i] = totalMinted + i; 
        }
    }





}