// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { VotingCEPToken } from "../src/veCEP.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployVotingCEPToken is BaseScript {
    function run() public broadcast returns (VotingCEPToken token) {
        token = new VotingCEPToken(admin, admin, admin);
    }
}
