// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "../src/gov/TLC.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployTLC is BaseScript {
    address[] public proposers = [admin];
    address[] public executors = [admin];

    function run() public broadcast returns (Timelock tlc) {
        tlc = new Timelock(1 days, proposers, executors);
    }
}
