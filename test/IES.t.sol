// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { BaseTest } from "./Base.t.sol";
import { console2 } from "forge-std/console2.sol";

import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";
import { SchemaResolver } from "eas-contracts/resolver/SchemaResolver.sol";
import { ISchemaResolver } from "eas-contracts/resolver/ISchemaResolver.sol";
import { IHats } from "hats-protocol/interfaces/IHats.sol";
import { console } from "forge-std/console.sol";

import { IES } from "../src/IES.sol";
import "../src/gov/VotingIESToken.sol";
import "../src/gov/IESGovernor.sol";
import { LiquidSplits1155 } from "../src/LiquidSplits1155.sol";

contract IESTest is BaseTest {
    IES internal ies;
    VotingIESToken internal voteToken;
    IESGovernor internal governor;
    IEAS internal eas;
    ISchemaRegistry internal schemaRegistry;
    IHats internal hats;
    LiquidSplits1155 lsToken;
    address splitsMain;

    address internal constant MOCK_EAS = address(0x1);
    address internal constant MOCK_SCHEMA_REGISTRY = address(0x2);
    address internal constant MOCK_HATS = address(0x3);
    address internal constant MOCK_SPLITS_TOKEN = address(0x4);

    event ImpactReportCreated(uint256 indexed projectHatId, uint256 indexed reportHatId, uint256 indexed proposalId);
    event Initialized(
        address indexed owner,
        address indexed treasury,
        address indexed governor,
        address token,
        bytes32 schemaUID,
        uint256 topHatId
    );
    event EvaluationCreated(uint256 indexed id, address indexed evaluation);
    event TreasuryUpdated(address treasury);
    event PoolFunded(uint256 indexed id, uint256 amount);
    event ProfileCreated(bytes32 indexed id, uint256 hatId, string name, string metadata, address owner);
    event RoleCreated(
        uint256 indexed projectHatid,
        uint256 reportHatId,
        uint256 roleHatId,
        address[] wearers,
        string metadata,
        string imageURL
    );
    event MinimumDepositChanged(uint256 indexed minDeposit);

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

        uint256 delay = 1 days;
        uint256 period = 1 weeks;
        // Deploy VotingIESToken
        voteToken = new VotingIESToken(owner, owner, owner);
        // Deploy IESGovernor
        governor = new IESGovernor(IVotes(address(voteToken)), delay, period);

        // Mint voteToken to owner, alice, bob, charlie
        __mintVoteToken(owner, 1_000_000);
        __mintVoteToken(alice, 1_000_000);
        __mintVoteToken(bob, 1_000_000);
        __mintVoteToken(charlie, 1_000_000);

        // Deploy IES contract
        ies = new IES(
            owner,
            treasury,
            address(governor),
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

    function testCreateReport() external {
        // alice should approve to spend voteToken
        __approveVoteToken(alice, address(ies), 1000);

        // alice create the project
        (, uint256 projectHatId) =
            __registerProject("Test Project", "https://example.com/project.png", "ipfs://QmTest", alice);

        // create bytes[] _roleData, roleData is encoded HatsRole[] struct
        bytes[] memory roleData = __createRoleData(projectHatId);

        address[] memory contributors = new address[](3);
        contributors[0] = alice;
        contributors[1] = bob;
        contributors[2] = charlie;

        vm.startPrank(alice);

        string[] memory links = new string[](2);
        links[0] = "ipfs://QmReport";
        links[1] = "ipfs://QmYRmop52xSAmUC5J5squPrkyu6HtGwQc6yqQNze5q5S8v";

        // Create the report
        (uint256 reportHatsId, uint256 poolId,) = ies.createReport(
            projectHatId,
            contributors,
            "ipfs://QmReport",
            "ipfs://QmYRmop52xSAmUC5J5squPrkyu6HtGwQc6yqQNze5q5S8v",
            "ipfs://QmYRmop52xSAmUC5J5squPrkyu6HtGwQc6yqQNze5q5S8v",
            links,
            alice,
            roleData
        );

        (string memory details, uint32 maxSupply, uint32 supply,,, string memory imageURI,,,) =
            hats.viewHat(reportHatsId);

        assertEq(poolId, 0, "Pool ID should be 0");

        // check hats
        assertEq(details, "[Impact Report] #1", "Details should match");
        assertEq(maxSupply, 1, "Max supply should be 1");
        assertEq(supply, 1, "Supply should be 1");
        assertEq(imageURI, "ipfs://QmYRmop52xSAmUC5J5squPrkyu6HtGwQc6yqQNze5q5S8v", "Image URI should match");

        vm.stopPrank();
    }

    function __createRoleData(uint256 projectHatId) internal view returns (bytes[] memory) {
        // create address[] _contributors with bob, charlie
        address[] memory role1_contributors = new address[](2);
        role1_contributors[0] = bob;
        role1_contributors[1] = charlie;

        address[] memory role2_contributors = new address[](3);
        role2_contributors[0] = alice;
        role2_contributors[1] = bob;
        role2_contributors[2] = charlie;

        IES.HatsRole memory role1 = IES.HatsRole({
            parentHatId: projectHatId, // hatsId for Commons:
                // 16553408899135050155131589418399235790963711658175777136977480041627648
            metadata: "ipfs://QmQh48H7yrw6i5PQANXbSTyC4D7WLLUUn5V4Pv1Hwo2M68",
            name: "Researcher",
            description: "Researcher role",
            wearers: role1_contributors,
            imageURL: "ipfs://QmTRGCnTfwHhyr64aSNZqpP68ABFNQu9W9TJZEo4vL3FRu"
        });

        IES.HatsRole memory role2 = IES.HatsRole({
            parentHatId: projectHatId,
            metadata: "ipfs://Qma89Row648R7vpPzis2qpz3a9SZAmTR5pEGCYPM2FXH9J",
            name: "Developer",
            description: "Developer role",
            wearers: role2_contributors,
            imageURL: "ipfs://QmRZ9ULzLKC1uzAvLyxAAhYoXyQMS413zPviGLu6vG4Bzw"
        });
        bytes[] memory roleData = new bytes[](2);
        roleData[0] = abi.encode(role1);
        roleData[1] = abi.encode(role2);
        return roleData;
    }

    function __registerProject(
        string memory name,
        string memory imageURL,
        string memory metadata,
        address owner
    )
        internal
        prankception(owner)
        returns (bytes32 profileId, uint256 projectHatId)
    {
        (profileId, projectHatId /* hatId */ ) = ies.registerProject(name, imageURL, metadata, owner);
    }

    function __mintVoteToken(address to, uint256 amount) internal prankception(owner) {
        voteToken.mint(to, amount);
    }

    function __approveVoteToken(address caller, address spender, uint256 amount) internal prankception(caller) {
        voteToken.approve(spender, amount);
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
