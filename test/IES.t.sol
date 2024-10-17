// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { BaseTest } from "./Base.t.sol";
import { console2 } from "forge-std/console2.sol";

import "../src/IES.sol";
import "../src/gov/VotingIESToken.sol";
import "eas-contracts/IEAS.sol";
import { IHats } from "hats-protocol/interfaces/IHats.sol";

contract IESTest is BaseTest {
    IES internal ies;
    VotingIESToken internal voteToken;
    IEAS internal eas;
    IHats internal hats;

    address internal constant MOCK_EAS = address(0x1);
    address internal constant MOCK_SCHEMA_REGISTRY = address(0x2);
    address internal constant MOCK_HATS = address(0x3);
    address internal constant MOCK_SPLITS_TOKEN = address(0x4);

    function setUp() public virtual {
        // Deploy VotingIESToken
        voteToken = new VotingIESToken(owner, owner, owner);

        // Deploy mock contracts
        vm.mockCall(MOCK_EAS, abi.encodeWithSignature("attest(AttestationRequest)"), abi.encode(bytes32(0)));
        vm.mockCall(
            MOCK_SCHEMA_REGISTRY, abi.encodeWithSignature("register(string,address,bool)"), abi.encode(bytes32(0))
        );
        vm.mockCall(MOCK_HATS, abi.encodeWithSignature("mintTopHat(address,string,string)"), abi.encode(uint256(1)));

        // Deploy IES contract
        ies = new IES(
            owner,
            treasury,
            address(0), // governor address, set to 0 for simplicity
            address(voteToken),
            MOCK_EAS,
            MOCK_SCHEMA_REGISTRY,
            MOCK_HATS,
            "https://example.com/image.png",
            MOCK_SPLITS_TOKEN
        );

        // Set up interfaces
        eas = IEAS(MOCK_EAS);
        hats = IHats(MOCK_HATS);
    }

    function testDeploy() external view {
        assertNotEq(address(ies), address(0), "IES should be deployed");
    }

    function testInitialState() external view {
        assertEq(ies.treasury(), treasury, "Treasury address should be set correctly");
        assertEq(address(ies.voteToken()), address(voteToken), "VoteToken address should be set correctly");
        assertEq(address(ies.eas()), MOCK_EAS, "EAS address should be set correctly");
        assertEq(address(ies.hats()), MOCK_HATS, "Hats address should be set correctly");
        assertEq(address(ies.splitsToken()), MOCK_SPLITS_TOKEN, "SplitsToken address should be set correctly");
        assertEq(ies.MIN_DEPOSIT(), 1000, "MIN_DEPOSIT should be set to 1000");
    }

    function testRegisterProject() external {
        string memory name = "Test Project";
        string memory imageURL = "https://example.com/project.png";
        string memory metadata = "ipfs://QmTest";

        vm.mockCall(
            MOCK_HATS,
            abi.encodeWithSignature("createHat(uint256,string,uint32,address,address,bool,string)"),
            abi.encode(uint256(2))
        );
        vm.mockCall(MOCK_HATS, abi.encodeWithSignature("mintHat(uint256,address)"), abi.encode(true));

        bytes32 profileId;
        vm.prank(alice);
        profileId = ies.registerProject(name, imageURL, metadata, alice);

        assertNotEq(profileId, bytes32(0), "ProfileId should not be zero");

        (bytes32 id, uint256 hatId, string memory storedName, string memory storedMetadata, address storedOwner,) =
            ies.profilesById(2);

        assertEq(id, profileId, "Profile ID should match");
        assertEq(hatId, 2, "Hat ID should be 2");
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
