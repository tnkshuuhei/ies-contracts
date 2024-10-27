// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

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
import { LibString } from "solady/utils/LibString.sol";
import { console } from "forge-std/console.sol";

import { VotingIESToken } from "./gov/VotingIESToken.sol";
import { Evaluation } from "./Evaluation.sol";
import { Errors } from "./libraries/Errors.sol";
import { AttesterResolver } from "./eas/AttesterResolver.sol";

contract IES is AccessControl, Errors, IERC1155Receiver {
    // Constants
    string private constant DEFAULT_TOP_HAT_NAME = "IES";
    string private constant REPORT_HAT_PREFIX = "[Impact Report] #";

    // State variables
    address payable public treasury;
    bytes32 public schemaUID;
    uint256 public topHatId;
    uint256 public evaluationCount;
    uint256 public MIN_DEPOSIT;

    IGovernor public governor;
    VotingIESToken public voteToken;
    IEAS public eas;
    AttesterResolver public resolver;
    IHats public hats;
    IERC1155 public splitsToken;

    // Structs
    struct EvaluationPool {
        bytes32 profileId;
        uint256 projectHatId;
        address evaluation;
        address token;
        uint256 amount;
        string metadata;
        address[] contributors;
    }

    struct Profile {
        bytes32 id;
        uint256 hatId;
        string name;
        string metadata;
        address owner;
        string imageURL;
    }

    struct HatsRole {
        uint256 parentHatId;
        string metadata;
        string name;
        string description;
        address[] wearers;
        string imageURL;
    }

    // Mappings
    // poolId => EvaluationPool
    mapping(uint256 => EvaluationPool) public evaluations;

    // hatId => Evaluation address
    mapping(uint256 => address) public evaluationAddrByHatId;

    // hatId => Profile
    mapping(uint256 => Profile) public profilesById;

    // hatsid => count
    mapping(uint256 => uint256) public projectReportCount;

    // Events
    event ImpactReportCreated(
        uint256 indexed projectHatId,
        uint256 indexed reportHatId,
        uint256 indexed proposalId,
        address proposer,
        string reportMetadata
    );
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
    event ProfileCreated(
        bytes32 indexed id, uint256 hatId, string name, string metadata, address owner, string imageURL
    );
    event RoleCreated(
        uint256 indexed projectHatid,
        uint256 reportHatId,
        uint256 roleHatId,
        address[] wearers,
        string metadata,
        string imageURL
    );
    event MinimumDepositChanged(uint256 indexed minDeposit);

    // Modifiers
    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    modifier onlyGovernor() {
        _checkGovernor();
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
     * @param _imageURL the image URL of the top hat
     * @param _splitsToken the splits token address
     */
    constructor(
        address _owner,
        address _treasury,
        address _gonernor,
        address _token,
        address _eas,
        address _schemaRegistry,
        address _hats,
        string memory _imageURL,
        address _splitsToken
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _updateTreasury(payable(_treasury));

        governor = IGovernor(_gonernor);
        voteToken = VotingIESToken(_token);
        splitsToken = IERC1155(_splitsToken);
        eas = IEAS(_eas);
        hats = IHats(_hats);

        MIN_DEPOSIT = 1000 * 10 ** 18;

        resolver = new AttesterResolver(IEAS(_eas), address(this));

        bytes32 _schemaUID = ISchemaRegistry(_schemaRegistry).register(
            "bytes32 profileId, address[] contributors, string description, string metadataUID, address proposer, string[] links",
            ISchemaResolver(address(resolver)),
            true
        );
        schemaUID = _schemaUID;

        // mint topHat
        uint256 hatId = IHats(_hats).mintTopHat(
            address(this), // target: Tophat's wearer address. The address that will be granted the hat.
            DEFAULT_TOP_HAT_NAME, // name: The name of the hat.
            _imageURL
        );
        topHatId = hatId;

        emit Initialized(_owner, _treasury, address(_gonernor), address(_token), _schemaUID, hatId);
    }

    /////////////////////////////////// EXTERNAL FUNCTIONS //////////////////////////////////////

    /**
     * @dev Register a new project
     * @param _name The name of the project
     * @param _imageURL The image URL for the hats that represent the project
     * @param _metadata The metadata of the project
     * @param _owner The owner of the project
     * @return profileId The unique identifier of the project
     */
    function registerProject(
        string memory _name,
        string memory _imageURL,
        string memory _metadata, //cid for data : { name: "Project Name", description: "Project description" }
        address _owner
    )
        external
        returns (bytes32 profileId, uint256 hatId)
    {
        // check
        require(_owner != address(0), ZERO_ADDRESS());
        require(_owner == msg.sender, UNAUTHORIZED());
        require((bytes(_name).length != 0 || bytes(_metadata).length != 0), INVALID_INPUT());

        // create a new hat for the project, that represents the project itself
        hatId = hats.createHat(
            topHatId, // parent hatId
            _metadata, // should be the project name
            1, // Max supply is 1 for the project
            0x0000000000000000000000000000000000004A75, // eligibility module address on sepolia
            0x0000000000000000000000000000000000004A75, // toggle module address on sepolia
            true,
            _imageURL
        );

        // mint the hat to the owner
        hats.mintHat(hatId, _owner);

        // Generate a profile ID using a nonce and the msg.sender
        profileId = _generateProfileId(hatId, _owner, _metadata);

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
        emit ProfileCreated(profileId, hatId, _name, _metadata, _owner, _imageURL);

        // Return the profile ID
        return (profileId, hatId);
    }

    /**
     * @dev Create a new Impact Report
     * @param _hatId // the hatId of the project that the report is created for
     * @param _contributors // the addresses of the contributors
     * @param _title // the title of the report
     * @param _description // the description of the report
     * @param _reportMetadata // the metadata of the report
     * @param _links // the links of evidence for the report
     * @param _imageURL // the image URL for hats that represent the report
     * @param _proposer // the address of the proposor
     */
    function createReport(
        uint256 _hatId,
        address[] calldata _contributors,
        string memory _title,
        string memory _description,
        string memory _imageURL,
        string memory _reportMetadata,
        string[] memory _links,
        address _proposer, // the address of the proposor
        bytes[] memory _roleData
    )
        external
        returns (uint256 reportHatsId, uint256 poolId, uint256 proposalId)
    {
        require(_proposer != address(0), ZERO_ADDRESS());
        require((_proposer == msg.sender), UNAUTHORIZED());
        require((_contributors.length > 0), NO_CONTRIBUTORS());
        require((_roleData.length > 0), INVALID_ROLE_DATA());

        Profile memory profile = profilesById[_hatId];

        projectReportCount[_hatId]++;

        // create a new hat for the report
        reportHatsId = hats.createHat(
            _hatId,
            string(abi.encodePacked(REPORT_HAT_PREFIX, LibString.toString(projectReportCount[_hatId]))),
            1,
            0x0000000000000000000000000000000000004A75,
            0x0000000000000000000000000000000000004A75,
            true,
            _imageURL
        );

        // create new pool for the report
        (, Evaluation evaluation) =
            _createEvaluationWithPool(profile.id, reportHatsId, MIN_DEPOSIT, profile.metadata, _proposer, _contributors);

        // Check If the evaluation contract is already initialized
        require(evaluation.initialized() == true, POOL_NOT_INITIALIZED(evaluation.getPoolId()));

        evaluationAddrByHatId[reportHatsId] = address(evaluation);

        // mint the hat to the evaluation contract
        hats.mintHat(reportHatsId, address(evaluation));

        EvaluationPool memory pool = evaluations[evaluation.getPoolId()];

        // check if the msg.sender is the owner of the evaluation contract
        evaluation.checkOwner(msg.sender);

        // transfer the amount to the evaluation contract
        ERC20 token = ERC20(pool.token);

        // need approval from the msg.sender to this contract
        require(token.transferFrom(msg.sender, address(governor), MIN_DEPOSIT), INSUFFICIENT_FUNDS());

        // create array of calldatas, targets, and values
        bytes[] memory _data = new bytes[](2 + _contributors.length);
        address[] memory _target = new address[](2 + _contributors.length);
        uint256[] memory _values = new uint256[](2 + _contributors.length);

        // calldata1: send back the token from governor contract to the owner address
        _data[0] = abi.encodeWithSignature("transfer(address,uint256)", msg.sender, MIN_DEPOSIT);
        // target1: token address
        _target[0] = address(token);
        _values[0] = 0;

        // calldata2: attest the proposal with the contributors
        _data[1] = abi.encodeWithSelector(
            IES.attest.selector, pool.profileId, _contributors, _description, _reportMetadata, _proposer, _links
        );

        // target2: address(this)
        _target[1] = address(this);
        _values[1] = 0;

        // mint 1 split token to each contributor
        for (uint256 i = 0; i < _contributors.length; i++) {
            _data[2 + i] = abi.encodeWithSignature("mint(address,uint256,bytes)", _contributors[i], 1, new bytes(0));
            _target[2 + i] = address(splitsToken);
            _values[2 + i] = 0;
        }

        // call the proposeImpactReport() on Evaluation
        proposalId = evaluation.proposeImpactReport(_contributors, _target, _values, _data, _title, _description);

        require(_roleData.length > 0, INVALID_ROLE_DATA());

        // create roles for the report
        for (uint256 i = 0; i < _roleData.length; i++) {
            HatsRole memory role = abi.decode(_roleData[i], (HatsRole));
            require(role.wearers.length > 0, EMPTY_ROLE_WEARERS());
            require(bytes(role.metadata).length > 0, EMPTY_ROLE_METADATA());
            require(bytes(role.imageURL).length > 0, EMPTY_ROLE_IMAGE_URL());

            uint256 roleHatId = hats.createHat(
                reportHatsId,
                role.metadata,
                uint32(role.wearers.length),
                0x0000000000000000000000000000000000004A75,
                0x0000000000000000000000000000000000004A75,
                true,
                role.imageURL
            );
            for (uint256 j = 0; j < role.wearers.length; j++) {
                require(role.wearers[j] != address(0), ZERO_ADDRESS());
                hats.mintHat(roleHatId, role.wearers[j]);
            }

            emit RoleCreated(_hatId, reportHatsId, roleHatId, role.wearers, role.metadata, role.imageURL);
        }

        emit ImpactReportCreated(_hatId, reportHatsId, proposalId, _proposer, _reportMetadata);
        return (reportHatsId, evaluation.getPoolId(), proposalId);
    }

    function attest(
        bytes32 profileId,
        address[] memory contributors,
        string memory description,
        string memory metadataUID,
        address proposer,
        string[] memory links
    )
        external
        onlyGovernor
        returns (bytes32)
    {
        return _attest(profileId, contributors, description, metadataUID, proposer, links);
    }

    function changeMinDeposit(uint256 _minDeposit) external onlyAdmin {
        MIN_DEPOSIT = _minDeposit;
        emit MinimumDepositChanged(_minDeposit);
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
        string memory _metadata,
        address _owner,
        address[] memory _contributors
    )
        internal
        returns (uint256 poolId, Evaluation evaluation)
    {
        poolId = evaluationCount;
        bytes32 POOL_MANAGER_ROLE = bytes32(poolId);
        bytes32 POOL_CONTRIBUTOR_ROLE = keccak256(abi.encodePacked(poolId, "contributor"));

        _grantRole(POOL_MANAGER_ROLE, msg.sender);

        evaluation = _createEvaluation(_profileId, _owner, _contributors);

        evaluationCount++;

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

        require(evaluation.getPoolId() == poolId, POOL_ID_MISMATCH());
        require(address(evaluation.getIES()) == address(this), EVALUATION_CONTRACT_MISMATCH());

        for (uint256 i = 0; i < _contributors.length; i++) {
            address contributor = _contributors[i];

            require(contributor != address(0), ZERO_ADDRESS());

            _grantRole(POOL_CONTRIBUTOR_ROLE, contributor);
        }
        emit EvaluationCreated(poolId, address(evaluation));
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

    /// @dev create a new attestation
    /// @param profileId The unique identifier of the profile
    /// @param contributors The addresses of the contributors
    /// @param description The proposal of the attestation
    /// @param metadataUID The unique identifier of the metadata
    /// @return attestationUID The unique identifier of the attestation
    function _attest(
        bytes32 profileId,
        address[] memory contributors,
        string memory description,
        string memory metadataUID,
        address proposer,
        string[] memory links
    )
        internal
        returns (bytes32 attestationUID)
    {
        // "bytes32 profileId, address[] contributors, string proposal, string metadataUID, address proposer"
        bytes memory data = abi.encode(profileId, contributors, description, metadataUID, proposer, links);
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

    function _checkGovernor() internal view {
        require(msg.sender == address(governor), "IES: caller is not the governor");
    }

    function _generateProfileId(
        uint256 _hatsId,
        address _owner,
        string memory _metadata
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_hatsId, _owner, _metadata));
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
