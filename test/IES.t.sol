// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { BaseTest } from "./Base.t.sol";
import { console2 } from "forge-std/console2.sol";

import "../src/IES.sol";

contract IESTest is BaseTest {
    IES internal ies;

    VotingIESToken internal voteToken;
    IESGovernor internal governor;
    IEAS internal eas;

    function setUp() public virtual {
        voteToken = new VotingIESToken(owner, owner, owner);
    }

    function testDeploy() external view {
        vm.assertFalse(address(ies) != address(0), "IES should be deployed");
    }
}
