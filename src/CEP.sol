// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";
import { SchemaResolver } from "eas-contracts/resolver/SchemaResolver.sol";
import { ISchemaResolver } from "eas-contracts/resolver/ISchemaResolver.sol";
import { IHats } from "hats-contracts/interfaces/IHats.sol";

import "./gov/CEPGovernor.sol";
import "./gov/veCEP.sol";
import "./Evaluation.sol";
import "./libraries/Errors.sol";
import "./libraries/Metadata.sol";
import "./eas/AttesterResolver.sol";

// Comprehensive Evaluation Protocol
contract CEP is AccessControl, Errors {
    address payable public treasury;
    uint256 public topHatId;
    uint256 public evaluationCount;
    bytes32 public schemaUID;

    CEPGovernor public governor;
    VotingCEPToken public voteToken;
    IEAS public eas;
    AttesterResolver public resolver;
    IHats public hats;

    struct EvaluationPool {
        bytes32 profileId;
        address evaluation;
        address token;
        uint256 amount;
        Metadata metadata;
        address[] contributors;
    }

    // poolId => EvaluationPool
    mapping(uint256 => EvaluationPool) public evaluations;

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

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    constructor(
        address _owner,
        address _treasury,
        CEPGovernor _gonernor,
        VotingCEPToken _token,
        IEAS _eas,
        ISchemaRegistry _schemaRegistry,
        IHats _hats
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        _updateTreasury(payable(_treasury));

        governor = _gonernor;
        voteToken = _token;

        resolver = new AttesterResolver(_eas, address(this));

        // TODO: define proper schema
        bytes32 _schemaUID = _schemaRegistry.register(
            "bytes32 profileId, address[] contributors, string proposal, string metadataUID, address proposer",
            ISchemaResolver(address(resolver)),
            true
        );

        schemaUID = _schemaUID;
        hats = _hats;

        // mint topHat
        uint256 hatId = _hats.mintTopHat(
            address(this), // target: Tophat's wearer address. The address that will be granted the hat.
            "Impact Evaluation DAO", // name
            "imageURL" // TODO: add the default image URL
        );
        topHatId = hatId;

        emit Initialized(_owner, _treasury, address(_gonernor), address(_token), _schemaUID, hatId);
    }

    // TODO: implement the function to create Impact report
    function createReport(
        address _evaluation,
        address[] calldata _contributors,
        string memory _description,
        uint256 _amount,
        address _proposor
    )
        external
    {
        require(_proposor == msg.sender, UNAUTHORIZED());
        require(_proposor != address(0), ZERO_ADDRESS());
        require(_contributors.length > 0, INVALID());
        require(_amount > 0, INVALID());

        Evaluation evaluation = Evaluation(_evaluation);
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

        // target1: token address
        targets[0] = address(token);
        // target2: address(this)
        targets[1] = address(this);

        values[0] = 0;
        values[1] = 0;

        // call the proposeImpactReport() on Evaluation
        evaluation.proposeImpactReport(_contributors, targets, values, calldatas, _description);
    }

    function createEvaluationWithPool(
        bytes32 _profileId,
        address _token,
        uint256 _amount,
        Metadata memory _metadata,
        address _owner,
        address[] memory _contributors
    )
        external
    {
        (uint256 poolId, Evaluation evaluation) =
            _createEvaluationWithPool(_profileId, _token, _amount, _metadata, _owner, _contributors);
        emit EvaluationCreated(poolId, address(evaluation));
    }

    /// @dev deploy a new evaluation contract with create2 and initialize it
    /// @dev create a new evaluation pool struct and store it in the evaluations mapping
    function _createEvaluationWithPool(
        bytes32 _profileId,
        address _token,
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
            evaluation: address(evaluation),
            token: _token,
            amount: _amount,
            metadata: _metadata,
            contributors: _contributors
        });

        evaluations[poolId] = pool;

        _setRoleAdmin(POOL_CONTRIBUTOR_ROLE, POOL_MANAGER_ROLE);

        require(evaluation.getPoolId() == 0, ALREADY_INITIALIZED());

        evaluation.initialize(poolId);

        require(evaluation.getPoolId() == poolId, MISMATCH());
        require(address(evaluation.getCep()) == address(this), MISMATCH());

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
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "CEP: caller is not an admin");
    }

    function _updateTreasury(address payable _treasury) internal {
        if (_treasury == address(0)) revert ZERO_ADDRESS();

        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
}
