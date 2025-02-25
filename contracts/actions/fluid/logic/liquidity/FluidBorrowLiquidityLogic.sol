// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../../interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultT2 } from "../../../../interfaces/fluid/vaults/IFluidVaultT2.sol";
import { FluidLiquidityModel } from "../../helpers/FluidLiquidityModel.sol";
import { FluidVaultTypes } from "../../helpers/FluidVaultTypes.sol";
import { TokenUtils } from "../../../../utils/TokenUtils.sol";
import { DFSMath } from "../../../../utils/math/DFSMath.sol";

/// @title FluidBorrowLiquidityLogic - Implements the borrowing of tokens from Fluid liquidity layer
/// @dev Used only for vaults with liquidity debt (T1 and T2)
library FluidBorrowLiquidityLogic {
    using TokenUtils for address;
    using DFSMath for uint256;
    using FluidVaultTypes for uint256;

    /// @notice Borrows tokens from a Fluid liquidity layer
    /// @param _data Borrow data
    /// @return Amount of tokens borrowed. Will be the same as the input amount
    function borrow(
        FluidLiquidityModel.BorrowData memory _data
    ) internal returns (uint256) {
        _data.vaultType.requireLiquidityDebt();

        bool shouldWrapBorrowedEth = _data.wrapBorrowedEth && _data.borrowToken == TokenUtils.ETH_ADDR;

        address sendTokensTo = shouldWrapBorrowedEth ? address(this) : _data.to;

        if (_data.vaultType.isT1Vault()) {
            IFluidVaultT1(_data.vault).operate(
                _data.nftId,
                0, /* newColl_ */
                _data.amount.signed256(),
                sendTokensTo
            );
        } else {
            IFluidVaultT2(_data.vault).operate(
                _data.nftId,
                0, /* newColToken0_ */
                0, /* newColToken1_ */
                0, /* colSharesMinMax_ */
                _data.amount.signed256(),
                sendTokensTo
            );
        }

        if (shouldWrapBorrowedEth) {
            TokenUtils.depositWeth(_data.amount);
            TokenUtils.WETH_ADDR.withdrawTokens(_data.to, _data.amount);
        }

        return _data.amount;
    }
}