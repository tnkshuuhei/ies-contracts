// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";

import "./libraries/Errors.sol";
import { CEP } from "./CEP.sol";

contract Evaluation is AccessControl, Errors {
    CEP public cep;

    uint256 public poolId;
    address public governor;
    address public owner;

    address[] public contributors;

    bytes32 public CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR_ROLE");

    event ImpactReportCreated(address[] contributors, uint256 proposalId);

    constructor(address _cepAddress, address _owner, address[] memory _contributors) {
        cep = CEP(_cepAddress);
        contributors = _contributors;

        for (uint256 i = 0; i < _contributors.length; i++) {
            _grantRole(CONTRIBUTOR_ROLE, _contributors[i]);
        }
        governor = address(cep.governor());
        owner = _owner;
    }

    modifier onlyCep() {
        _checkCep();
        _;
    }

    ///@param _contributors array of contributor addresses
    ///@param targets array of the target contract addresses
    ///@param values array of values to be handled by the proposal
    ///@param calldatas array of calldatas to be handled by the proposal
    ///@param description string description of the proposal
    function proposeImpactReport(
        address[] calldata _contributors,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        external
        onlyCep
        returns (uint256)
    {
        // create proposal on Governor contract
        uint256 proposalId = IGovernor(governor).propose(targets, values, calldatas, description);

        // TODO: emit event
        emit ImpactReportCreated(_contributors, proposalId);
        return proposalId;
    }

    // TODO: implement the initialize function
    function initialize(uint256 _poolId) external {
        poolId = _poolId;
    }

    function getCep() external view returns (address) {
        return address(cep);
    }

    function getPoolId() external view returns (uint256) {
        return poolId;
    }

    function _checkCep() internal view {
        if (msg.sender != address(cep)) {
            revert UNAUTHORIZED();
        }
    }

    function checkContributor(address _contributor) external view returns (bool isContributor) {
        isContributor = _checkContributor(_contributor);
        return isContributor;
    }

    function _checkContributor(address _contributor) internal view returns (bool) {
        if (!hasRole(CONTRIBUTOR_ROLE, _contributor)) {
            revert UNAUTHORIZED();
        } else {
            return true;
        }
    }

    function checkOwner(address caller) external view returns (bool) {
        return _checkOwner(caller);
    }

    function _checkOwner(address caller) internal view returns (bool) {
        if (caller != owner) {
            revert UNAUTHORIZED();
        } else {
            return true;
        }
    }
}
