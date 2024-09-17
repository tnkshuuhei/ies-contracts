// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "./libraries/Errors.sol";
import { CEP } from "./CEP.sol";

contract Evaluation is Errors {
    CEP public cep;

    uint256 public poolId;

    constructor(address cepAddress) {
        cep = CEP(cepAddress);
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
}
