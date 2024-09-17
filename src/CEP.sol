// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./CEPGovernor.sol";
import "./veCEP.sol";
import "./Evaluation.sol";
import "./libraries/Errors.sol";
import "./libraries/Metadata.sol";

// Comprehensive Evaluation Protocol
contract CEP is Initializable, OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, Errors {
    uint256 public evaluationCount;

    address payable public treasury;

    CEPGovernor public governor;
    VotingCEPToken public voteToken;

    struct EvaluationPool {
        bytes32 profileId;
        Evaluation evaluation;
        address token;
        uint256 amount;
        Metadata metadata;
        address[] contributors;
    }

    mapping(uint256 => EvaluationPool) public evaluations;

    event EvaluationCreated(uint256 indexed id, address indexed evaluation);

    event TreasuryUpdated(address treasury);

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _treasury,
        CEPGovernor _gonernor,
        VotingCEPToken _token
    )
        public
        initializer
    {
        __Ownable_init(_owner);
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        _updateTreasury(payable(_treasury));

        governor = _gonernor;
        voteToken = _token;
    }

    function _createEvaluationPool(
        bytes32 _profileId,
        address _token,
        uint256 _amount,
        Metadata memory _metadata,
        address[] memory _contributors
    )
        external
        returns (uint256 poolId, Evaluation evaluation)
    {
        poolId = ++evaluationCount;
        bytes32 POOL_MANAGER_ROLE = bytes32(poolId);
        bytes32 POOL_CONTRIBUTOR_ROLE = keccak256(abi.encodePacked(poolId, "contributor"));

        _grantRole(POOL_MANAGER_ROLE, msg.sender);

        evaluation = _createEvaluation(_profileId, _contributors);

        if (address(evaluation) == address(0)) revert ZERO_ADDRESS();

        EvaluationPool memory pool = EvaluationPool({
            profileId: _profileId,
            evaluation: evaluation,
            token: _token,
            amount: _amount,
            metadata: _metadata,
            contributors: _contributors
        });

        evaluations[poolId] = pool;

        _setRoleAdmin(POOL_CONTRIBUTOR_ROLE, POOL_MANAGER_ROLE);

        if (evaluation.getPoolId() != 0) revert ALREADY_INITIALIZED();

        evaluation.initialize(poolId);

        if (evaluation.getPoolId() != poolId || address(evaluation.getCep()) != address(this)) revert MISMATCH();

        for (uint256 i = 0; i < _contributors.length; i++) {
            address contributor = _contributors[i];

            if (contributor == address(0)) revert ZERO_ADDRESS();

            _grantRole(POOL_CONTRIBUTOR_ROLE, contributor);
        }

        emit EvaluationCreated(poolId, address(evaluation));

        return (poolId, evaluation);
    }

    function _createEvaluation(
        bytes32 _profileId,
        address[] memory _contributors
    )
        internal
        returns (Evaluation evaluationAddress)
    {
        evaluationCount++;
        bytes memory bytecode = type(Evaluation).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(address(this)));

        bytes32 salt = keccak256(abi.encodePacked(_profileId, _contributors, evaluationCount));
        assembly {
            evaluationAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        return evaluationAddress;
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
