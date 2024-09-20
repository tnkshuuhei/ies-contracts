// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./libraries/Errors.sol";
import { CEP } from "./CEP.sol";

contract Evaluation is AccessControl, Errors {
    CEP public cep;

    uint256 public poolId;

    address[] public contributors;

    bytes32 public CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR_ROLE");

    constructor(address _cepAddress, address[] memory _contributors) {
        cep = CEP(_cepAddress);
        contributors = _contributors;

        for (uint256 i = 0; i < _contributors.length; i++) {
            _grantRole(CONTRIBUTOR_ROLE, _contributors[i]);
        }
    }

    modifier onlyCep() {
        _checkCep();
        _;
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
}
