// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import "../src/CEP.sol";

contract CEPTest is Test {
    CEP internal cep;
    address owner = makeAddr("owner");
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address treasury = makeAddr("treasury");

    VotingCEPToken internal voteToken;
    CEPGovernor internal governor;
    IEAS internal eas;

    function setUp() public virtual {
        voteToken = new VotingCEPToken(owner, owner, owner);
    }
}
