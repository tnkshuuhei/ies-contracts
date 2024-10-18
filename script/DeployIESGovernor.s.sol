// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";
import { IESGovernor } from "../src/gov/IESGovernor.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployIESGovernor is Script {
    address public admin = 0xc3593524E2744E547f013E17E6b0776Bc27Fc614;
    //sepolia
    address public votingToken = 0x527B739C24339c1621D9bE1F9fcdC9Adad1E883b;

    function run() public {
        vm.startBroadcast();
        new IESGovernor(IVotes(votingToken));
        vm.stopBroadcast();
    }
}
