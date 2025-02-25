// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVault } from "../../../interfaces/fluid/vaults/IFluidVault.sol";
import { TokenUtils } from "../../../utils/TokenUtils.sol";

/// @title Helper library that simplifies token transfers for fluid dex actions
library FluidDexTokensUtils {
    using TokenUtils for address;

    /// @notice Helper struct to hold data about pulled tokens
    /// @param amount0 Amount of token0 pulled
    /// @param amount1 Amount of token1 pulled
    /// @param isToken0Native Whether token0 is native or not
    /// @param isToken1Native Whether token1 is native or not
    struct PulledTokensData {
        uint256 amount0;
        uint256 amount1;
        bool isToken0Native;
        bool isToken1Native;
    }

    /// @notice Sends tokens to the recipient and wraps them if needed
    /// @dev If no tokens should be wrapped, the function won't have any effect
    /// @param _tokens Fluid vault tokens
    /// @param _to Address to send the tokens to
    /// @param _amount0 Amount of token0 to send
    /// @param _amount1 Amount of token1 to send
    /// @param _sendToken0AsWrapped Whether to send token0 as wrapped
    /// @param _sendToken1AsWrapped Whether to send token1 as wrapped
    function sendTokens(
        IFluidVault.Tokens memory _tokens,
        address _to,
        uint256 _amount0,
        uint256 _amount1,
        bool _sendToken0AsWrapped,
        bool _sendToken1AsWrapped
    ) internal {
        if (_sendToken0AsWrapped) {
            TokenUtils.depositWeth(_amount0);
            TokenUtils.WETH_ADDR.withdrawTokens(_to, _amount0);
            _tokens.token1.withdrawTokens(_to, _amount1);
        }

        if (_sendToken1AsWrapped) {
            TokenUtils.depositWeth(_amount1);
            TokenUtils.WETH_ADDR.withdrawTokens(_to, _amount1);
            _tokens.token0.withdrawTokens(_to, _amount0);
        }
    }

    /// @notice Checks if tokens should be sent as wrapped. Used by withdraw and borrow actions
    /// @param _tokens Fluid vault tokens
    /// @param _shouldWrap Whether tokens should be wrapped
    /// @param _amount0 Amount of token0 to send
    /// @param _amount1 Amount of token1 to send
    /// @return sendToken0AsWrapped Whether token0 should be sent as wrapped
    /// @return sendToken1AsWrapped Whether token1 should be sent as wrapped
    function shouldSendTokensAsWrapped(
        IFluidVault.Tokens memory _tokens,
        bool _shouldWrap,
        uint256 _amount0,
        uint256 _amount1
    ) internal pure returns (bool sendToken0AsWrapped, bool sendToken1AsWrapped) {
        sendToken0AsWrapped = _shouldWrap && _tokens.token0 == TokenUtils.ETH_ADDR && _amount0 > 0;
        sendToken1AsWrapped = _shouldWrap && _tokens.token1 == TokenUtils.ETH_ADDR && _amount1 > 0;
    }

    /// @notice Pulls tokens from the sender if needed and approves them for the approval target
    /// @param _tokens Fluid vault tokens
    /// @param _from Address to pull the tokens from
    /// @param _approvalTarget Address to approve the tokens for
    /// @param _amount0 Amount of token0 to pull
    /// @param _amount1 Amount of token1 to pull
    /// @return vars Pulled tokens data
    function pullTokensIfNeededWithApproval(
        IFluidVault.Tokens memory _tokens,
        address _from,
        address _approvalTarget,
        uint256 _amount0,
        uint256 _amount1
    ) internal returns (PulledTokensData memory vars) {
        (vars.amount0, vars.isToken0Native) = _pullTokenIfNeededWithApproval(
            _amount0,
            _tokens.token0,
            _from,
            _approvalTarget
        );

        (vars.amount1, vars.isToken1Native) = _pullTokenIfNeededWithApproval(
            _amount1,
            _tokens.token1,
            _from,
            _approvalTarget
        );
    }

    function _pullTokenIfNeededWithApproval(
        uint256 _amount,
        address _token,
        address _from,
        address _approvalTarget
    ) internal returns (uint256 amount, bool isNative) {
        if (_amount == 0) return (0, false);

        if (_token == TokenUtils.ETH_ADDR) {
            _amount = TokenUtils.WETH_ADDR.pullTokensIfNeeded(_from, _amount);
            TokenUtils.withdrawWeth(_amount);
            return (_amount, true);
        }

        _amount = _token.pullTokensIfNeeded(_from, _amount);
        _token.approveToken(_approvalTarget, _amount);

        return (_amount, false);
    }
}