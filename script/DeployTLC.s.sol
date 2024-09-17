// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { TLC } from "../src/TLC.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployTLC is BaseScript {
    address[] proposers = [admin];
    address[] executors = [admin];

    function run() public broadcast returns (TLC tlc) {
        // tlc = new TLC(1 days, proposers, executors, admin);
        tlc = new TLC();
    }
}
