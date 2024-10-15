// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";
import { SchemaResolver } from "eas-contracts/resolver/SchemaResolver.sol";
import { ISchemaResolver } from "eas-contracts/resolver/ISchemaResolver.sol";
import { IHats } from "hats-protocol/src/interfaces/IHats.sol";
import { console } from "forge-std/console.sol";

import "./gov/IESGovernor.sol";
import "./gov/VotingIESToken.sol";
import "./Evaluation.sol";
import "./libraries/Errors.sol";
import "./libraries/Metadata.sol";
import "./eas/AttesterResolver.sol";
import { IHypercertToken } from "./interfaces/IHypercerts.sol";

// Comprehensive Evaluation Protocol
contract IES is AccessControl, Errors, IERC1155Receiver {
    // Constants
    bytes32 private constant POOL_MANAGER_ROLE_PREFIX = "POOL_MANAGER_ROLE_";
    bytes32 private constant POOL_CONTRIBUTOR_ROLE_PREFIX = "POOL_CONTRIBUTOR_ROLE_";
    string private constant DEFAULT_TOP_HAT_NAME = "Impact Evaluation DAO";
    string private constant REPORT_HAT_PREFIX = "[Impact Report] #";

    // State variables
    address payable public treasury;
    uint256 public topHatId;
    uint256 public evaluationCount;
    bytes32 public schemaUID;

    IESGovernor public governor;
    VotingIESToken public voteToken;
    IEAS public eas;
    AttesterResolver public resolver;
    IHats public hats;
    IHypercertToken public hypercerts;

    // Structs
    struct EvaluationPool {
        bytes32 profileId;
        uint256 projectHatId;
        address evaluation;
        address token;
        uint256 amount;
        Metadata metadata;
        address[] contributors;
    }

    struct Profile {
        bytes32 id;
        uint256 hatId;
        string name;
        Metadata metadata;
        address owner;
        string imageURL;
    }

    // Mappings
    // poolId => EvaluationPool
    mapping(uint256 => EvaluationPool) public evaluations;

    // hatId => Evaluation address
    mapping(uint256 => address) public evaluationAddrByHatId;
    // hatId => Profile
    mapping(uint256 => Profile) public profilesById;

    // Events
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
        uint256 indexed projectHatid, uint256 roleHatId, address[] wearers, string metadata, string imageURL
    );
    // Modifiers

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    /**
     * @dev Initializes the CEP contract
     * @param _owner the owner of the contract
     * @param _treasury the treasury address
     * @param _gonernor the governor contract address
     * @param _token the voting token address
     * @param _eas the EAS contract address
     * @param _schemaRegistry the EAS schema registry address
     * @param _hats the hats contract address
     * @param _hypercerts the hypercerts contract address
     * @param _imageURL the image URL of the top hat
     */
    constructor(
        address _owner,
        address _treasury,
        IESGovernor _gonernor,
        address _token,
        IEAS _eas,
        address _schemaRegistry,
        address _hats,
        address _hypercerts,
        string memory _imageURL
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        _updateTreasury(payable(_treasury));

        governor = _gonernor;
        voteToken = VotingIESToken(_token);

        resolver = new AttesterResolver(_eas, address(this));

        // TODO: define proper schema
        bytes32 _schemaUID = ISchemaRegistry(_schemaRegistry).register(
            "bytes32 profileId, address[] contributors, string proposal, string metadataUID, address proposer",
            ISchemaResolver(address(resolver)),
            true
        );

        schemaUID = _schemaUID;
        hats = IHats(_hats);

        // mint topHat
        uint256 hatId = IHats(_hats).mintTopHat(
            address(this), // target: Tophat's wearer address. The address that will be granted the hat.
            "Impact Evaluation DAO", // name
            _imageURL
        );
        topHatId = hatId;
        hypercerts = IHypercertToken(_hypercerts);

        emit Initialized(_owner, _treasury, address(_gonernor), address(_token), _schemaUID, hatId);
    }

    /////////////////////////////////// EXTERNAL FUNCTIONS //////////////////////////////////////

    // TODO: get tokenId from the hypercerts contract and store it
    /**
     * @dev Create hypercerts
     * @param account the creator of the hypercerts
     * @param units the amount of hypercerts to be created. default is 100_000_000
     * @param _uri the metadata CID that points to the metadata of the hypercerts
     * @param _restrictions the transfer restrictions of the hypercerts
     */
    function createHypercerts(
        address account,
        uint256 units,
        string memory _uri,
        IHypercertToken.TransferRestrictions _restrictions
    )
        external
        onlyAdmin
    {
        _createHypercerts(account, units, _uri, _restrictions);
        // TODO: make this claimable
    }

    /**
     * @dev Register a new project
     * @param _name The name of the project
     * @param _imageURL The image URL for the hats that represent the project
     * @param _metadata The metadata of the project
     * @param _owner The owner of the project
     * @param _parentHatId The parent hatId of the project
     * @return profileId The unique identifier of the project
     */
    function registerProject(
        string memory _name,
        string memory _imageURL,
        Metadata memory _metadata, // data : { name: "Project Name", description: "Project description" }
        address _owner,
        uint256 _parentHatId
    )
        external
        returns (bytes32 profileId)
    {
        // Make sure the owner is not the zero address
        require(_owner != address(0), ZERO_ADDRESS());

        // create a new hat for the project, that represents the project itself
        uint256 hatId = hats.createHat(
            _parentHatId,
            _metadata.pointer, // should be the project name
            1, // Max supply is 1 for the project
            0x0000000000000000000000000000000000004A75, // eligibility module address on sepolia
            0x0000000000000000000000000000000000004A75, // toggle module address on sepolia
            true,
            _imageURL
        );

        // mint the hat to the owner
        hats.mintHat(hatId, _owner);

        // Generate a profile ID using a nonce and the msg.sender
        profileId = _generateProfileId(hatId, _owner, _name);

        // Create a new Profile instance, also generates the anchor address
        Profile memory profile = Profile({
            id: profileId,
            hatId: hatId,
            name: _name,
            metadata: _metadata,
            owner: _owner,
            imageURL: _imageURL
        });

        // store the profile in the profilesById mapping
        profilesById[hatId] = profile;

        // Emit the event that the profile was created
        emit ProfileCreated(profileId, hatId, _name, _metadata.pointer, _owner);

        // Return the profile ID
        return profileId;
    }

    /**
     * @dev Create a new Impact Report
     * @param _hatId // the hatId of the project that the report is created for
     * @param _contributors // the addresses of the contributors
     * @param _description // the description of the report
     * @param _imageURL // the image URL for hats that represent the report
     * @param _amount // the amount of token to be deposited
     * @param _proposor // the address of the proposor
     */
    function createReport(
        uint256 _hatId,
        address[] calldata _contributors,
        string memory _description,
        string memory _imageURL,
        uint256 _amount, // amount of token to be deposited
        address _proposor // the address of the proposor
    )
        external
    {
        require(_proposor == msg.sender, UNAUTHORIZED());
        require(_proposor != address(0), ZERO_ADDRESS());
        require(_proposor == profilesById[_hatId].owner, UNAUTHORIZED());
        require(_contributors.length > 0, INVALID());
        require(_amount > 0, INVALID());

        Profile memory profile = profilesById[_hatId];

        // create a new hat for the report
        uint256 reportHatsId = hats.createHat(
            _hatId,
            string(abi.encodePacked("[Impact Report] #", block.timestamp)),
            1,
            address(0),
            address(0),
            true,
            _imageURL
        );

        (, Evaluation evaluation) =
            _createEvaluationWithPool(profile.id, reportHatsId, _amount, profile.metadata, _proposor, _contributors);

        evaluationAddrByHatId[reportHatsId] = address(evaluation);

        // mint the hat to the evaluation contract
        hats.mintHat(reportHatsId, address(evaluation));

        EvaluationPool memory pool = evaluations[evaluation.getPoolId()];

        // check if the msg.sender is the owner of the evaluation contract
        evaluation.checkOwner(msg.sender);

        // transfer the amount to the evaluation contract
        ERC20 token = ERC20(pool.token);
        // need approval from the msg.sender to this contract
        // TODO: decide whitch token should be used for deposit
        // TODO: decide how many token should be deposited, should be the pre-defined amount or the amount that is
        // passed as an argument
        require(token.transferFrom(msg.sender, address(evaluation), _amount), "Token transfer failed");

        // create array of calldatas, targets, and values
        bytes[] memory calldatas;
        address[] memory targets;
        uint256[] memory values;

        // calldata1: send back the token from evaluation contract to the owner address
        calldatas[0] =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", address(evaluation), _proposor, _amount);

        // calldata2: attest the proposal with the contributors
        calldatas[1] = abi.encodeWithSignature(
            "attest(bytes32,address[],string,string,address)",
            pool.profileId,
            _contributors,
            _description,
            pool.metadata.pointer,
            _proposor
        );

        // TODO: give hypercerts to contributors if proposal has passed

        // target1: token address
        targets[0] = address(token);
        // target2: address(this)
        targets[1] = address(this);

        values[0] = 0;
        values[1] = 0;

        // call the proposeImpactReport() on Evaluation
        uint256 proposalId = evaluation.proposeImpactReport(_contributors, targets, values, calldatas, _description);

        emit ImpactReportCreated(_hatId, reportHatsId, proposalId);
    }

    /**
     * @dev Create a new role for the Impact Report
     * @param _poolId // the poolId of the evaluation contract
     * @param _metadata // the metadata of the role
     * @param _wearers // the addresses of the wearers
     * @param _imageURL // the image URL for hats that represent the role
     */
    function createRole(
        uint256 _poolId,
        string memory _metadata,
        address[] memory _wearers,
        string memory _imageURL
    )
        external
    {
        EvaluationPool memory evaluationPool = evaluations[_poolId];
        // check the caller is the owner of the evaluation contract
        require(Evaluation(evaluationPool.evaluation).owner() == msg.sender, INVALID());
        // check the wearers array is not empty
        require(_wearers.length > 0, INVALID());
        // check the metadata is not empty
        require(bytes(_metadata).length > 0, INVALID());

        // create a new hat for the role
        uint256 roleHatId = hats.createHat(
            evaluationPool.projectHatId,
            _metadata,
            uint32(_wearers.length),
            0x0000000000000000000000000000000000004A75,
            0x0000000000000000000000000000000000004A75,
            true,
            _imageURL
        );
        for (uint256 i = 0; i < _wearers.length; i++) {
            hats.mintHat(roleHatId, _wearers[i]);
        }

        emit RoleCreated(evaluationPool.projectHatId, roleHatId, _wearers, _metadata, _imageURL);
    }

    function attest(
        bytes32 profileId,
        address[] memory contributors,
        string memory proposal,
        string memory metadataUID
    )
        external
        returns (bytes32 attestationUID)
    {
        attestationUID = _attest(profileId, contributors, proposal, metadataUID, msg.sender);
    }

    /////////////////////////////////// INTERNAL FUNCTIONS //////////////////////////////////////

    /**
     * @dev deploy a new evaluation contract with create2 and initialize it
     * @dev create a new evaluation pool struct and store it in the evaluations mapping
     * @param _profileId the profileId of the project
     * @param _hatId the hatId of the project
     * @param _amount the amount of token to be deposited
     * @param _metadata the metadata
     * @param _owner the owner of the evaluation contract
     * @param _contributors the addresses of the contributors
     * @return poolId the poolId of the evaluation
     * @return evaluation the evaluation contract address
     */
    function _createEvaluationWithPool(
        bytes32 _profileId,
        uint256 _hatId,
        uint256 _amount,
        Metadata memory _metadata,
        address _owner,
        address[] memory _contributors
    )
        internal
        returns (uint256 poolId, Evaluation evaluation)
    {
        poolId = ++evaluationCount;
        bytes32 POOL_MANAGER_ROLE = bytes32(poolId);
        bytes32 POOL_CONTRIBUTOR_ROLE = keccak256(abi.encodePacked(poolId, "contributor"));

        _grantRole(POOL_MANAGER_ROLE, msg.sender);

        evaluation = _createEvaluation(_profileId, _owner, _contributors);

        require(address(evaluation) != address(0), ZERO_ADDRESS());

        EvaluationPool memory pool = EvaluationPool({
            profileId: _profileId,
            projectHatId: _hatId,
            evaluation: address(evaluation),
            token: address(voteToken),
            amount: _amount,
            metadata: _metadata,
            contributors: _contributors
        });

        evaluations[poolId] = pool;

        _setRoleAdmin(POOL_CONTRIBUTOR_ROLE, POOL_MANAGER_ROLE);

        require(evaluation.getPoolId() == 0, ALREADY_INITIALIZED());

        evaluation.initialize(poolId);

        require(evaluation.getPoolId() == poolId, MISMATCH());
        require(address(evaluation.getIES()) == address(this), MISMATCH());

        for (uint256 i = 0; i < _contributors.length; i++) {
            address contributor = _contributors[i];

            require(contributor != address(0), ZERO_ADDRESS());

            _grantRole(POOL_CONTRIBUTOR_ROLE, contributor);
        }

        return (poolId, evaluation);
    }

    function _createEvaluation(
        bytes32 _profileId,
        address _owner,
        address[] memory _contributors
    )
        internal
        returns (Evaluation evaluationAddress)
    {
        evaluationCount++;
        bytes memory bytecode = type(Evaluation).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(address(this), _owner, _contributors));

        bytes32 salt = keccak256(abi.encodePacked(_profileId, _owner, _contributors, evaluationCount));
        assembly {
            evaluationAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        return evaluationAddress;
    }

    function _createHypercerts(
        address account,
        uint256 units,
        string memory _uri,
        IHypercertToken.TransferRestrictions _restrictions
    )
        internal
    {
        hypercerts.mintClaim(account, units, _uri, _restrictions);
    }

    /// @dev create a new attestation
    /// @param profileId The unique identifier of the profile
    /// @param contributors The addresses of the contributors
    /// @param proposal The proposal of the attestation
    /// @param metadataUID The unique identifier of the metadata
    /// @return attestationUID The unique identifier of the attestation
    function _attest(
        bytes32 profileId,
        address[] memory contributors,
        string memory proposal,
        string memory metadataUID,
        address proposer
    )
        internal
        returns (bytes32 attestationUID)
    {
        // "bytes32 profileId, address[] contributors, string proposal, string metadataUID, address proposer"
        bytes memory data = abi.encode(profileId, contributors, proposal, metadataUID, proposer);
        AttestationRequestData memory requestData = AttestationRequestData({
            recipient: proposer,
            expirationTime: 0,
            revocable: true,
            refUID: 0x0,
            data: data,
            value: 0
        });
        AttestationRequest memory request = AttestationRequest({ schema: schemaUID, data: requestData });
        attestationUID = eas.attest(request);
    }

    function updateTreasury(address payable _treasury) external onlyAdmin {
        _updateTreasury(_treasury);
    }

    function _checkAdmin() internal view {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "IES: caller is not an admin");
    }

    function _generateProfileId(uint256 _hatsId, address _owner, string memory _name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_hatsId, _owner, _name));
    }

    function _updateTreasury(address payable _treasury) internal {
        if (_treasury == address(0)) revert ZERO_ADDRESS();

        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    // below functions are required by IERC1155Receiver
    ///@inheritdoc IERC1155Receiver
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        external
        pure
        override
        returns (bytes4)
    {
        console.logAddress(operator);
        console.logAddress(from);
        console.logBytes(data);
        console.logUint(id);
        console.logUint(value);
        return this.onERC1155Received.selector;
    }

    ///@inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        external
        pure
        override
        returns (bytes4)
    {
        console.logAddress(operator);
        console.logAddress(from);
        console.logBytes(data);
        for (uint256 i = 0; i < ids.length; i++) {
            console.logUint(ids[i]);
            console.logUint(values[i]);
        }
        return this.onERC1155BatchReceived.selector;
    }
}