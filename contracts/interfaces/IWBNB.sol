// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";


interface IWBNB is IBEP20 {
    function withdraw(uint mintAmount) external;
    function deposit() external payable;
}
