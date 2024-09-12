// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "./Evaluation.sol";
import "./libraries/Errors.sol";

// Comprehensive Evaluation Protocol
contract CEP is Initializable, OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, Errors {
    uint256 public evaluationCount;

    address payable public treasury;

    mapping(uint256 => address) public evaluations;

    event EvaluationCreated(uint256 indexed id, address indexed evaluation);

    event TreasuryUpdated(address treasury);

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    function initialize(address _owner, address _treasury) public initializer {
        __Ownable_init(_owner);
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        treasury = payable(_treasury);
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
