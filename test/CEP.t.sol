// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { BaseTest } from "./Base.t.sol";
import { console2 } from "forge-std/console2.sol";

import "../src/CEP.sol";

contract CEPTest is BaseTest {
    CEP internal cep;

    VotingCEPToken internal voteToken;
    CEPGovernor internal governor;
    IEAS internal eas;

    function setUp() public virtual {
        voteToken = new VotingCEPToken(owner, owner, owner);
    }

    function testDeploy() external view {
        vm.assertFalse(address(cep) != address(0), "CEP should be deployed");
    }
}
