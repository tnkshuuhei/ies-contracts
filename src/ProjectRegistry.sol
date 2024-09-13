// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { Metadata } from "./libraries/Metadata.sol";
import "./libraries/Errors.sol";

contract ProjectRegistry is Initializable, AccessControlUpgradeable, Errors {
    bytes32 public constant CEP_OWNER = keccak256("CEP_OWNER");
    mapping(bytes32 => Profile) public profilesById;

    struct Profile {
        bytes32 id;
        uint256 nonce;
        string name;
        Metadata metadata;
        address owner;
    }

    event ProfileCreated(bytes32 indexed id, uint256 nonce, string name, Metadata metadata, address owner);

    function initialize(address _owner) external initializer {
        // Make sure the owner is not 'address(0)'
        if (_owner == address(0)) revert ZERO_ADDRESS();
        // Grant the role to the owner
        _grantRole(CEP_OWNER, _owner);
    }

    function createProfile(
        uint256 _nonce,
        string memory _name,
        Metadata memory _metadata,
        address _owner,
        address[] memory _members
    )
        external
        returns (bytes32)
    {
        // Generate a profile ID using a nonce and the msg.sender
        bytes32 profileId = _generateProfileId(_nonce, _owner);

        // Make sure the owner is not the zero address
        if (_owner == address(0)) revert ZERO_ADDRESS();

        // Create a new Profile instance, also generates the anchor address
        Profile memory profile =
            Profile({ id: profileId, nonce: _nonce, name: _name, metadata: _metadata, owner: _owner });

        profilesById[profileId] = profile;

        // Assign roles for the profile members
        uint256 memberLength = _members.length;

        // Only profile owner can add members
        if (memberLength > 0 && _owner != msg.sender) {
            revert UNAUTHORIZED();
        }

        for (uint256 i; i < memberLength;) {
            address member = _members[i];

            // Will revert if any of the addresses are a zero address
            if (member == address(0)) revert ZERO_ADDRESS();

            // Grant the role to the member and emit the event for each member
            _grantRole(profileId, member);
            unchecked {
                ++i;
            }
        }

        // Emit the event that the profile was created
        emit ProfileCreated(profileId, profile.nonce, profile.name, profile.metadata, profile.owner);

        // Return the profile ID
        return profileId;
    }

    function _generateProfileId(uint256 _nonce, address _owner) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_nonce, _owner));
    }
}
