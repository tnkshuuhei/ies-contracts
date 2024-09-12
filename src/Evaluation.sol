// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "./libraries/Errors.sol";
import { CEP } from "./CEP.sol";

contract Evaluation is Errors {
    CEP public cep;

    constructor(address cepAddress) {
        cep = CEP(cepAddress);
    }

    modifier onlyCep() {
        _checkCep();
        _;
    }

    function _checkCep() internal view {
        if (msg.sender != address(cep)) {
            revert UNAUTHORIZED();
        }
    }
}
