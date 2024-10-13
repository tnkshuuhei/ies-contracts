// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";
import { console } from "forge-std/console.sol";

import "./libraries/Errors.sol";
import { CEP } from "./CEP.sol";

contract Evaluation is AccessControl, Errors, IERC1155Receiver {
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
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    modifier onlyCep() {
        require(_checkCep() == true, UNAUTHORIZED());
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
        returns (uint256 proposalId)
    {
        // create proposal on Governor contract
        proposalId = IGovernor(governor).propose(
            targets, values, calldatas, string(abi.encodePacked("[Impact Report]", description))
        );

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

    function _checkCep() internal view returns (bool) {
        require(msg.sender == address(cep), UNAUTHORIZED());
        return true;
    }

    function checkContributor(address _contributor) external view returns (bool isContributor) {
        isContributor = _checkContributor(_contributor);
        return isContributor;
    }

    function _checkContributor(address _contributor) internal view returns (bool) {
        require(hasRole(CONTRIBUTOR_ROLE, _contributor), UNAUTHORIZED());
        return true;
    }

    function checkOwner(address caller) external view returns (bool) {
        return _checkOwner(caller);
    }

    function _checkOwner(address caller) internal view returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, caller), UNAUTHORIZED());
        return true;
    }

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
