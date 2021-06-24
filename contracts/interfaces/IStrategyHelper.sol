// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IStrategyHelper {
    function tokenPriceInBNB(address _token) view external returns(uint);
    function pantherPriceInBNB() view external returns(uint);
    function bnbPriceInUSD() view external returns(uint);

    function flipPriceInBNB(address _flip) view external returns(uint);
    function flipPriceInUSD(address _flip) view external returns(uint);

    function profitOf(address minter, address _flip, uint amount) external view returns (uint _usd, uint _pirate, uint _bnb);

    function tvl(address _flip, uint amount) external view returns (uint);
    function tvlInBNB(address _flip, uint amount) external view returns (uint);   
    function apy(address minter, uint pid) external view returns(uint _usd, uint _pirate, uint _bnb);
    function compoundingAPY(uint pid, uint compoundUnit) view external returns(uint);
}