// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import "forge-std/console.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Script } from "forge-std/Script.sol";
import "../src/CEPGovernor.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployCEPGovernor is Script {
    address admin = 0xc3593524E2744E547f013E17E6b0776Bc27Fc614;

    function run() public {
        vm.startBroadcast();
        address token = 0xFD48e7f4c8EE34109607bb1EB1A6779A21884A03;
        TimelockControllerUpgradeable tlc =
            TimelockControllerUpgradeable(payable(0x7d5F0FCf8Fff3f8F2fA7Ee6F3FfF3FFF3fFf3FFf));

        address proxy = Upgrades.deployTransparentProxy(
            "CEPGovernor.sol",
            admin,
            abi.encodeCall(CEPGovernor.initialize, (IVotes(token), TimelockControllerUpgradeable(tlc)))
        );
        CEPGovernor governor = CEPGovernor(payable(proxy));
        console.log("Deployed proxy at:", proxy);
        console.log("Deployed CEPGovernor at:", address(governor));
        vm.stopBroadcast();
    }
}
