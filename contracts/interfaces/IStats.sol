//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../structs/statsStruct.sol";

interface IStats {
    function setBaseStats(uint16[] memory ids, uint8[] memory rands) external returns(bool);

    function callBaseStats(uint8 from, uint8 to) external;

    function updateAdmin(address _admin) external;

    function updateGameContract(address _game) external;

    function updateMinterContract(address _minter) external;

    function getHP(uint16 token) external view returns(uint8);

    function getNoOfAttacks(uint16 token) external view returns(uint8);

    function getAttackDamage(bool which, uint16 token) external view returns(uint8);

    function getAttackEnergyCost(bool which, uint16 token) external view returns (uint8);

    function getElement(uint16 token) external view returns(uint8);

    function getStrength(uint16 token) external view returns(uint8);

    function getWeakness(uint16 token) external view returns(uint8);

    function getBaseStats(uint8 _card) external view returns(StatsStruct memory);

    function getCurrentStats(uint16 token) external view returns(StatsStruct memory);

    function upgradeAttackDamage(uint16 token, bool which, uint8 amount)external returns(bool);

    function upgradeHp(uint16 token,uint8 amount) external returns(bool);

}