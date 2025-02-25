// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

/// @title DFSMath
/// @notice Provides math utility functions.
library DFSMath {

    /// @notice Converts an unsigned 256-bit integer to a signed 256-bit integer.
    /// @dev Reverts if the input value exceeds the maximum value of int256.
    /// @param x The unsigned integer to convert.
    /// @return The signed integer representation of `x`.
    function signed256(uint256 x) internal pure returns (int256) {
        require(x <= uint256(type(int256).max));
        return int256(x);
    }
}