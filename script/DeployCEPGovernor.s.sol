// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";
import { CEPGovernor } from "../src/gov/CEPGovernor.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployCEPGovernor is Script {
    address public admin = 0xc3593524E2744E547f013E17E6b0776Bc27Fc614;

    function run() public {
        vm.startBroadcast();
        address token = 0xFD48e7f4c8EE34109607bb1EB1A6779A21884A03;

        CEPGovernor governor = CEPGovernor(payable(token));

        console.log("Deployed CEPGovernor at:", address(governor));
        vm.stopBroadcast();
    }
}
