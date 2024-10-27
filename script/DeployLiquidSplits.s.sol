// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "../src/LiquidSplits1155.sol";

import { BaseScript } from "./Base.s.sol";
/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting

contract DeployLiquidSplits1155 is BaseScript {
    address[] public accounts = [0xc3593524E2744E547f013E17E6b0776Bc27Fc614, 0x63b1EfC5602C0023BBb373F2350Cf34c2E5F8669];
    uint32[] public initialAllocation = [1, 1];

    function run() public broadcast {
        new LiquidSplits1155(
            0x54E4a6014D36c381fC43b7E24A1492F556139a6F,
            accounts,
            initialAllocation,
            10,
            0xc3593524E2744E547f013E17E6b0776Bc27Fc614,
            0xc3593524E2744E547f013E17E6b0776Bc27Fc614,
            0xc3593524E2744E547f013E17E6b0776Bc27Fc614
        );
    }
}
