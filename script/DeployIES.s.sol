// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { IES } from "../src/IES.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployIES is BaseScript {
    // Sepolia
    address public treasury = 0x6630135B16769bf599947a5113F617be4feC781b;
    address public governor = 0x43e090616677b6ff8f86875c27e34855E252c9fB;
    address public votingToken = 0x527B739C24339c1621D9bE1F9fcdC9Adad1E883b;
    address public ls1155 = 0x2395eb2307EDb377B40779C880341DB28e239f65;
    address public eas = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address public schemaRegistry = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;
    address public hats = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
    string public imageurl = "ipfs://QmaUeuCCPvyViz8fBQM3BRuqsSPYPWYUAiD6Ai76q2P9ok";

    function run() public broadcast {
        new IES(admin, treasury, governor, votingToken, eas, schemaRegistry, hats, imageurl, ls1155);
    }
}
