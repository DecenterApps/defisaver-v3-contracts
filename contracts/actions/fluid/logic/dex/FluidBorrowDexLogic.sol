// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVault } from "../../../../interfaces/fluid/vaults/IFluidVault.sol";
import { IFluidVaultT3 } from "../../../../interfaces/fluid/vaults/IFluidVaultT3.sol";
import { IFluidVaultT4 } from "../../../../interfaces/fluid/vaults/IFluidVaultT4.sol";
import { FluidDexModel } from "../../helpers/FluidDexModel.sol";
import { FluidVaultTypes } from "../../helpers/FluidVaultTypes.sol";
import { FluidDexTokensUtils } from "../../helpers/FluidDexTokensUtils.sol";
import { TokenUtils } from "../../../../utils/TokenUtils.sol";
import { DFSMath } from "../../../../utils/math/DFSMath.sol";

/// @title FluidBorrowDexLogic - Implements the borrowing of tokens from Fluid DEX
/// @dev Used only for vaults with smart debt (T3 and T4)
library FluidBorrowDexLogic {
    using TokenUtils for address;
    using DFSMath for uint256;
    using FluidVaultTypes for uint256;

    /// @notice Borrows exact tokens from a Fluid DEX using variable amount of shares.
    /// @param _data Borrow data
    /// @param _tokens Tokens data
    /// @return borrowShares Amount of debt shares minted.
    function borrowVariable(
        FluidDexModel.BorrowDexData memory _data,
        IFluidVault.Tokens memory _tokens
    ) internal returns (uint256 borrowShares) {
        _data.vaultType.requireSmartDebt();

        (bool sendDebt0AsWrapped, bool sendDebt1AsWrapped) = FluidDexTokensUtils.shouldSendTokensAsWrapped(
            _tokens,
            _data.wrapBorrowedEth,
            _data.variableData.debtAmount0,
            _data.variableData.debtAmount1
        );

        address sendTokensTo = (sendDebt0AsWrapped || sendDebt1AsWrapped) ? address(this) : _data.to;

        ( , , int256 exactDebtShares) = _data.vaultType.isT3Vault()
            ? IFluidVaultT3(_data.vault).operate(
                _data.nftId,
                0, /* newCol_ */
                _data.variableData.debtAmount0.signed256(),
                _data.variableData.debtAmount1.signed256(),
                _data.variableData.minDebtShares.signed256(),
                sendTokensTo
            )
            : IFluidVaultT4(_data.vault).operate(
                _data.nftId,
                0, /* newColToken0_ */
                0, /* newColToken1_ */
                0, /* colSharesMinMax_ */
                _data.variableData.debtAmount0.signed256(),
                _data.variableData.debtAmount1.signed256(),
                _data.variableData.minDebtShares.signed256(),
                sendTokensTo
            );

        // If one of tokens should be wrapped, re-send them to the recipient
        FluidDexTokensUtils.sendTokens(
            _tokens,
            _data.to,
            _data.variableData.debtAmount0,
            _data.variableData.debtAmount1,
            sendDebt0AsWrapped,
            sendDebt1AsWrapped
        );

        borrowShares = uint256(exactDebtShares);
    }

    /// @notice Borrows tokens from a Fluid DEX using exact amount of shares.
    /// @param _data Borrow data
    /// @param _tokens Tokens data
    /// @return borrowShares Amount of borrow shares minted.
    function borrowExact(
        FluidDexModel.BorrowDexData memory _data,
        IFluidVault.Tokens memory _tokens
    ) internal returns (uint256 borrowShares) {
        _data.vaultType.requireSmartDebt();

        (bool sendDebt0AsWrapped, bool sendDebt1AsWrapped) = FluidDexTokensUtils.shouldSendTokensAsWrapped(
            _tokens,
            _data.wrapBorrowedEth,
            _data.exactData.minDebtAmount0,
            _data.exactData.minDebtAmount1
        );

        address sendTokensTo = (sendDebt0AsWrapped || sendDebt1AsWrapped) ? address(this) : _data.to;

        ( , int256[] memory operatePerfectData) = _data.vaultType.isT3Vault()
            ? IFluidVaultT3(_data.vault).operatePerfect(
                _data.nftId,
                0, /* newCol_ */
                _data.exactData.perfectDebtShares.signed256(),
                _data.exactData.minDebtAmount0.signed256(),
                _data.exactData.minDebtAmount1.signed256(),
                sendTokensTo

            )
            : IFluidVaultT4(_data.vault).operatePerfect(
                _data.nftId,
                0, /* perfectColShares_ */
                0, /* colToken0MinMax_ */
                0, /* colToken1MinMax_ */
                _data.exactData.perfectDebtShares.signed256(),
                _data.exactData.minDebtAmount0.signed256(),
                _data.exactData.minDebtAmount1.signed256(),
                sendTokensTo
            );

        {   
            bool isT3Vault = _data.vaultType.isT3Vault();

            // See IFluidVaultT3 and IFluidVaultT4 for the return values indexing
            borrowShares = uint256(operatePerfectData[isT3Vault ? 1 : 3]);
            uint256 exactBorrowedAmount0 = uint256(operatePerfectData[isT3Vault ? 2 : 4]);
            uint256 exactBorrowedAmount1 = uint256(operatePerfectData[isT3Vault ? 3 : 5]);

            // If one of tokens should be wrapped, re-send them to the recipient
            FluidDexTokensUtils.sendTokens(
                _tokens,
                _data.to,
                exactBorrowedAmount0,
                exactBorrowedAmount1,
                sendDebt0AsWrapped,
                sendDebt1AsWrapped
            );
        }
    }
}