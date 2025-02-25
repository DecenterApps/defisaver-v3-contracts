// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../../interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultT2 } from "../../../../interfaces/fluid/vaults/IFluidVaultT2.sol";
import { FluidLiquidityModel } from "../../helpers/FluidLiquidityModel.sol";
import { FluidVaultTypes } from "../../helpers/FluidVaultTypes.sol";
import { TokenUtils } from "../../../../utils/TokenUtils.sol";
import { DFSMath } from "../../../../utils/math/DFSMath.sol";

/// @title FluidPaybackLiquidityLogic - Implements the payback of tokens to Fluid liquidity layer
/// @dev Used only for vaults with liquidity debt (T1 and T2)
library FluidPaybackLiquidityLogic {
    using TokenUtils for address;
    using DFSMath for uint256;
    using FluidVaultTypes for uint256;

    /// @notice Paybacks tokens to a Fluid liquidity layer
    /// @param _data Payback data
    /// @return Amount of tokens paid back. In case of max payback, it will be the exact total amount paid back
    function payback(
        FluidLiquidityModel.PaybackData memory _data
    ) internal returns (uint256) {
        _data.vaultType.requireLiquidityDebt();

        bool isEthPayback = _data.borrowToken == TokenUtils.ETH_ADDR;

        uint256 borrowTokenBalanceBefore;
        bool maxPayback;
        if (_data.amount > _data.position.borrow) {
            maxPayback = true;
            // The exact full payback amount is dynamically calculated inside the vault and can surpass the recorded debt.
            // To account for this, we need to pull slightly more than the recorded debt.
            // We will increase the amount by 0.001% and add an extra fixed margin of 5 units.
            // Note that even though an amount higher than the recorded debt is categorized as max payback,
            // the user must still have sufficient tokens and allowance to cover this extra amount.
            _data.amount = _data.position.borrow * 100001 / 100000 + 5;
            // If we pull more than necessary, we will take a snapshot and refund any dust amount.
            borrowTokenBalanceBefore = isEthPayback
                ? address(this).balance
                : _data.borrowToken.getBalance(address(this));
        }

        if (isEthPayback) {
            _data.amount = TokenUtils.WETH_ADDR.pullTokensIfNeeded(_data.from, _data.amount);
            TokenUtils.withdrawWeth(_data.amount);
        } else {
            _data.amount = _data.borrowToken.pullTokensIfNeeded(_data.from, _data.amount);
            _data.borrowToken.approveToken(_data.vault, _data.amount);
        }

        // type(int256).min will trigger max payback inside the vault.
        int256 paybackAmount =  maxPayback ? type(int256).min : -_data.amount.signed256();

        // If we send more ETH than needed, the vault will refund the dust.
        uint256 msgValue = isEthPayback ? _data.amount : 0;

        // Execute payback operation.
        ( , , int256 exactPaybackAmount) = _data.vaultType.isT1Vault()
            ? IFluidVaultT1(_data.vault).operate{value: msgValue}(
                _data.nftId,
                0, /* newColl_ */
                paybackAmount,
                address(0) /* to_ */
            )
            : IFluidVaultT2(_data.vault).operate{value: msgValue}(
                _data.nftId,
                0, /* newColToken0_ */
                0, /* newColToken1_ */
                0, /* colSharesMinMax_ */
                paybackAmount,
                address(0) /* to_ */
            );

        if (maxPayback) {
            uint256 borrowTokenBalanceAfter = isEthPayback
                ? address(this).balance
                : _data.borrowToken.getBalance(address(this));

            // Sanity check: if we didn't perform a max payback directly from the wallet,
            // the number of borrowed tokens should not decrease.
            if (_data.from != address(this)) {
                require(borrowTokenBalanceAfter >= borrowTokenBalanceBefore);
            }

            // We pulled slightly more than needed, so refund dust amount to 'from' address.
            if (borrowTokenBalanceAfter > borrowTokenBalanceBefore) {
                uint256 dustAmount = borrowTokenBalanceAfter - borrowTokenBalanceBefore;
                // This also supports plain ETH.
                _data.borrowToken.withdrawTokens(_data.from, dustAmount);
                // Remove any dust approval left.
                if (!isEthPayback) {
                    _data.borrowToken.approveToken(_data.vault, 0);
                }
            }
        }

        return (uint256(-exactPaybackAmount));
    }
}