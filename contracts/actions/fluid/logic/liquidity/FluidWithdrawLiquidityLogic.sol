// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../../interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultT3 } from "../../../../interfaces/fluid/vaults/IFluidVaultT3.sol";
import { FluidLiquidityModel } from "../../helpers/FluidLiquidityModel.sol";
import { FluidVaultTypes } from "../../helpers/FluidVaultTypes.sol";
import { TokenUtils } from "../../../../utils/TokenUtils.sol";
import { DFSMath } from "../../../../utils/math/DFSMath.sol";

/// @title FluidSupplyLiquidityLogic - Implements the supply of tokens to Fluid liquidity layer
/// @dev Used only for vaults with liquidity collateral (T1 and T3)
library FluidWithdrawLiquidityLogic {
    using TokenUtils for address;
    using DFSMath for uint256;
    using FluidVaultTypes for uint256;

    /// @notice Withdraws tokens from a Fluid liquidity layer
    /// @param _data Withdraw data
    /// @return Amount of tokens withdrawn. In case of max withdrawal, it will be the exact total amount withdrawn.
    function withdraw(
        FluidLiquidityModel.WithdrawData memory _data
    ) internal returns (uint256) {
        _data.vaultType.requireLiquidityCollateral();

        bool shouldWrapWithdrawnEth = _data.wrapWithdrawnEth && _data.supplyToken == TokenUtils.ETH_ADDR;

        address sendTokensTo = shouldWrapWithdrawnEth ? address(this) : _data.to;

        // type(int256).min will trigger max withdrawal inside the vault
        int256 withdrawAmount = _data.amount == type(uint256).max
            ? type(int256).min
            : -_data.amount.signed256();

        ( , withdrawAmount , ) = _data.vaultType.isT1Vault()
            ? IFluidVaultT1(_data.vault).operate(
                _data.nftId,
                withdrawAmount,
                0, /* newDebt_ */
                sendTokensTo
            )
            : IFluidVaultT3(_data.vault).operate(
                _data.nftId,
                withdrawAmount,
                0, /* newDebtToken0_ */
                0, /* newDebtToken1_ */
                0, /* debtSharesMinMax_ */
                sendTokensTo
            );

        uint256 exactAmount = uint256(-withdrawAmount);

        if (shouldWrapWithdrawnEth) {
            TokenUtils.depositWeth(exactAmount);
            TokenUtils.WETH_ADDR.withdrawTokens(_data.to, exactAmount);
        }

        return exactAmount;
    }
}