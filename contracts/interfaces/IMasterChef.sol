// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IMasterChef {
    function pantherPerBlock() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function canHarvest(uint256 _pid, address vault)
        external
        view
        returns (bool);

    function poolInfo(uint256 _pid)
        external
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accpantherPerShare
        );

    function userInfo(uint256 _pid, address _account)
        external
        view
        returns (uint256 amount, uint256 rewardDebt);

    function poolLength() external view returns (uint256);

    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _referrer
    ) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;

    function enterStaking(uint256 _amount) external;

    function leaveStaking(uint256 _amount) external;
}
