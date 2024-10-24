// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { IES } from "../src/IES.sol";
import { VotingIESToken } from "../src/gov/VotingIESToken.sol";
import { IESGovernor } from "../src/gov/IESGovernor.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";

import { console } from "forge-std/console.sol";
import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployIES is BaseScript {
    // Sepolia
    address public treasury = 0x6630135B16769bf599947a5113F617be4feC781b;
    address public votingToken;
    address public governor;
    address public ls1155 = 0x8b16442143B38D8a7b0d116c6860a241Abf98788;
    address public eas = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address public schemaRegistry = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;
    address public hats = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
    string public imageurl = "ipfs://QmaUeuCCPvyViz8fBQM3BRuqsSPYPWYUAiD6Ai76q2P9ok";

    uint256 public delay = 10 minutes;
    uint256 public period = 20 minutes;

    function run() public broadcast {
        votingToken = address(new VotingIESToken(admin, admin, admin));
        governor = address(new IESGovernor(IVotes(votingToken), delay, period));

        address ies =
            address(new IES(admin, treasury, governor, votingToken, eas, schemaRegistry, hats, imageurl, ls1155));
        console.log("VotingIESToken deployed at: ", votingToken);
        console.log("IESGovernor deployed at: ", governor);
        console.log("IES deployed at: ", ies);
    }
}
