// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/governance/TimelockController.sol";

// https://docs.openzeppelin.com/defender/guide/timelock-roles
contract Timelock is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    )
        TimelockController(minDelay, proposers, executors, msg.sender)
    { }
}
