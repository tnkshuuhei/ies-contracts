// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { VotingIESToken } from "../src/gov/VotingIESToken.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployVotingIESToken is BaseScript {
    function run() public broadcast returns (VotingIESToken token) {
        token = new VotingIESToken(admin, admin, admin);
    }
}
