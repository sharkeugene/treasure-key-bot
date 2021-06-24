// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IStakingRewards {
    function notifyRewardAmount(uint256 reward) external;
}