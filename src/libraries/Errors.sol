// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with.
contract Errors {
    /// ======================
    /// ====== Generic =======
    /// ======================

    /// @notice Thrown when input validation fails
    error INVALID_INPUT();

    /// @notice Thrown when mismatch in decoding data
    error DATA_MISMATCH();

    /// @notice Thrown when not enough funds are available
    error INSUFFICIENT_FUNDS();

    /// @notice Thrown when user is not authorized
    error UNAUTHORIZED();

    /// @notice Thrown when address is the zero address
    error ZERO_ADDRESS();

    /// @notice Thrown when the function is not implemented
    error NOT_IMPLEMENTED();

    /// @notice Thrown when the value is non-zero
    error NON_ZERO_VALUE();

    /// @notice Thrown when the contract is already initialized
    error ALREADY_INITIALIZED();

    /// ======================
    /// ===== Project =======
    /// ======================

    /// @notice Thrown when project registration fails
    error INVALID_PROJECT_REGISTRATION();

    /// @notice Thrown when project owner mismatch
    error INVALID_PROJECT_OWNER();

    /// ======================
    /// ====== Report =======
    /// ======================

    /// @notice Thrown when report creation fails
    error INVALID_REPORT_CREATION();

    /// @notice Thrown when contributors list is empty
    error NO_CONTRIBUTORS();

    /// @notice Thrown when role data is invalid
    error INVALID_ROLE_DATA();

    error EMPTY_ROLE_WEARERS();

    error EMPTY_ROLE_METADATA();

    error EMPTY_ROLE_IMAGE_URL();

    /// ======================
    /// === Evaluation ======
    /// ======================

    /// @notice Thrown when evaluation contract initialization fails due to invalid parameters or state
    error EVALUATION_INIT_FAILED();

    /// @notice Thrown when the provided pool ID doesn't match the expected value
    error POOL_ID_MISMATCH();

    /// @notice Thrown when the evaluation contract address doesn't match the expected value
    error EVALUATION_CONTRACT_MISMATCH();

    /// @notice Thrown when attempting to interact with an uninitialized pool
    error POOL_NOT_INITIALIZED(uint256 poolId);
}
