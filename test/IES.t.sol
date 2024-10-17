// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { BaseTest } from "./Base.t.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";
import { SchemaResolver } from "eas-contracts/resolver/SchemaResolver.sol";
import { ISchemaResolver } from "eas-contracts/resolver/ISchemaResolver.sol";
import { IHats } from "hats-protocol/interfaces/IHats.sol";
import { console } from "forge-std/console.sol";

import "../src/IES.sol";
import "../src/gov/VotingIESToken.sol";
import "../src/LiquidSplits1155.sol";

contract IESTest is BaseTest {
    IES internal ies;
    VotingIESToken internal voteToken;
    IEAS internal eas;
    ISchemaRegistry internal schemaRegistry;
    IHats internal hats;
    LiquidSplits1155 lsToken;
    address splitsMain;

    address internal constant MOCK_EAS = address(0x1);
    address internal constant MOCK_SCHEMA_REGISTRY = address(0x2);
    address internal constant MOCK_HATS = address(0x3);
    address internal constant MOCK_SPLITS_TOKEN = address(0x4);

    function configureChain() public {
        if (block.chainid == 11_155_111) {
            //sepolia
            eas = IEAS(0xC2679fBD37d54388Ce493F1DB75320D236e1815e);
            schemaRegistry = ISchemaRegistry(0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0);
            hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
            splitsMain = 0x54E4a6014D36c381fC43b7E24A1492F556139a6F;
            lsToken = new LiquidSplits1155(splitsMain, initialMinter, initialAllocation, 10, admin, admin, admin);
        } else if (block.chainid == 10) {
            // optimism
            eas = IEAS(0x4200000000000000000000000000000000000021);
            schemaRegistry = ISchemaRegistry(0x4200000000000000000000000000000000000020);
            hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
            splitsMain = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;
            lsToken = new LiquidSplits1155(splitsMain, initialMinter, initialAllocation, 10, admin, admin, admin);
        } else {
            eas = IEAS(MOCK_EAS);
            schemaRegistry = ISchemaRegistry(MOCK_SCHEMA_REGISTRY);
            hats = IHats(MOCK_HATS);
            // Deploy mock contracts
            vm.mockCall(MOCK_EAS, abi.encodeWithSignature("attest(AttestationRequest)"), abi.encode(bytes32(0)));
            vm.mockCall(
                MOCK_SCHEMA_REGISTRY, abi.encodeWithSignature("register(string,address,bool)"), abi.encode(bytes32(0))
            );
            vm.mockCall(MOCK_HATS, abi.encodeWithSignature("mintTopHat(address,string,string)"), abi.encode(uint256(1)));
            vm.mockCall(MOCK_SPLITS_TOKEN, abi.encodeWithSignature("mint(address,uint256,uint256)"), abi.encode(true));
        }
    }

    address[] public initialMinter = [owner, admin];
    uint32[] public initialAllocation = [50, 50];

    function setUp() public virtual {
        configureChain();
        // Deploy VotingIESToken
        voteToken = new VotingIESToken(owner, owner, owner);

        // Deploy IES contract
        ies = new IES(
            owner,
            treasury,
            address(0), // governor address, set to 0 for simplicity
            address(voteToken),
            address(eas),
            address(schemaRegistry),
            address(hats),
            "https://example.com/image.png",
            address(lsToken)
        );
    }

    function testDeploy() external view {
        assertNotEq(address(ies), address(0), "IES should be deployed");
    }

    function testInitialState() external view {
        assertEq(ies.treasury(), treasury, "Treasury address should be set correctly");
        assertEq(address(ies.voteToken()), address(voteToken), "VoteToken address should be set correctly");
        assertEq(address(ies.eas()), address(eas), "EAS address should be set correctly");
        assertEq(address(ies.hats()), address(hats), "Hats address should be set correctly");
        assertEq(address(ies.splitsToken()), address(lsToken), "SplitsToken address should be set correctly");
        assertEq(ies.MIN_DEPOSIT(), 1000, "MIN_DEPOSIT should be set to 1000");
    }

    function testRegisterProject() external {
        string memory name = "Test Project";
        string memory imageURL = "https://example.com/project.png";
        string memory metadata = "ipfs://QmTest";

        vm.prank(alice);
        (bytes32 profileId, uint256 projectHatId /* hatId */ ) = ies.registerProject(name, imageURL, metadata, alice);

        assertNotEq(profileId, bytes32(0), "ProfileId should not be zero");

        (bytes32 id, uint256 hatId, string memory storedName, string memory storedMetadata, address storedOwner,) =
            ies.profilesById(projectHatId);

        assertEq(id, profileId, "Profile ID should match");
        assertEq(hatId, projectHatId, "Hats ID should match");
        assertEq(storedName, name, "Project name should match");
        assertEq(storedMetadata, metadata, "Project metadata should match");
        assertEq(storedOwner, alice, "Project owner should be Alice");
    }

    function testChangeMinDeposit() external {
        uint256 newMinDeposit = 2000;

        vm.prank(owner);
        ies.changeMinDeposit(newMinDeposit);

        assertEq(ies.MIN_DEPOSIT(), newMinDeposit, "MIN_DEPOSIT should be updated");
    }

    function testChangeMinDepositNotAdmin() external {
        uint256 newMinDeposit = 2000;

        vm.prank(alice);
        vm.expectRevert("IES: caller is not an admin");
        ies.changeMinDeposit(newMinDeposit);
    }

    function testUpdateTreasury() external {
        address payable newTreasury = payable(address(0x123));

        vm.prank(owner);
        ies.updateTreasury(newTreasury);

        assertEq(ies.treasury(), newTreasury, "Treasury address should be updated");
    }

    function testUpdateTreasuryNotAdmin() external {
        address payable newTreasury = payable(address(0x123));

        vm.prank(alice);
        vm.expectRevert("IES: caller is not an admin");
        ies.updateTreasury(newTreasury);
    }

    function bobChangeMinDeposit() external prankception(bob) {
        ies.changeMinDeposit(4000);
    }

    function ownerChangeMinDeposit() external prankception(owner) {
        ies.changeMinDeposit(3000);
    }
}
