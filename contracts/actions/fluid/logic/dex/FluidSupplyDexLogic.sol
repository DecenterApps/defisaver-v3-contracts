// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVault } from "../../../../interfaces/fluid/vaults/IFluidVault.sol";
import { IFluidVaultT2 } from "../../../../interfaces/fluid/vaults/IFluidVaultT2.sol";
import { IFluidVaultT4 } from "../../../../interfaces/fluid/vaults/IFluidVaultT4.sol";
import { FluidDexModel } from "../../helpers/FluidDexModel.sol";
import { FluidVaultTypes } from "../../helpers/FluidVaultTypes.sol";
import { FluidDexTokensUtils } from "../../helpers/FluidDexTokensUtils.sol";
import { TokenUtils } from "../../../../utils/TokenUtils.sol";
import { DFSMath } from "../../../../utils/math/DFSMath.sol";

/// @title FluidSupplyDexLogic - Implements the supplying of tokens to Fluid DEX
/// @dev Used only for vaults with smart collateral (T2 and T4)
library FluidSupplyDexLogic  {
    using TokenUtils for address;
    using DFSMath for uint256;
    using FluidVaultTypes for uint256;

    /// @notice Supplies tokens to a Fluid DEX using variable amount of shares.
    /// @param _data Supply data
    /// @param _tokens Tokens data
    /// @return nftId NFT ID of the position
    /// @return collShares Amount of collateral shares minted.
    function supplyVariable(
        FluidDexModel.SupplyDexData memory _data,
        IFluidVault.Tokens memory _tokens
    ) internal returns (uint256 nftId, uint256 collShares) {
        _data.vaultType.requireSmartCollateral();

        FluidDexTokensUtils.PulledTokensData memory vars = FluidDexTokensUtils.pullTokensIfNeededWithApproval(
            _tokens,
            _data.from,
            _data.vault,
            _data.variableData.collAmount0,
            _data.variableData.collAmount1
        );

        uint256 msgValue = vars.isToken0Native
            ? vars.amount0
            : (vars.isToken1Native ? vars.amount1 : 0);

        int256 exactCollSharesMinted;

        (nftId, exactCollSharesMinted, ) = _data.vaultType.isT2Vault()
            ? IFluidVaultT2(_data.vault).operate{ value: msgValue }(
                _data.nftId,
                vars.amount0.signed256(),
                vars.amount1.signed256(),
                _data.variableData.minCollShares.signed256(),
                0, /* debtAmount */
                address(0) /* to */
            )
            : IFluidVaultT4(_data.vault).operate{ value: msgValue}(
                _data.nftId,
                vars.amount0.signed256(),
                vars.amount1.signed256(),
                _data.variableData.minCollShares.signed256(),
                0, /* debtAmount0 */
                0, /* debtAmount1 */
                0, /* minDebtShares */
                address(0) /* to */
            );

        collShares = uint256(exactCollSharesMinted);
    }

    /// @notice Supplies tokens to a Fluid DEX using exact amount of shares.
    /// @param _data Supply data
    /// @param _tokens Tokens data
    /// @return nftId NFT ID of the position
    /// @return collShares Amount of collateral shares minted.
    function supplyExact(
        FluidDexModel.SupplyDexData memory _data,
        IFluidVault.Tokens memory _tokens
    ) internal returns (uint256 nftId, uint256 collShares) {
        _data.vaultType.requireSmartCollateral();

        // We always pull the max amount of collateral0/1 and refund the difference later
        FluidDexTokensUtils.PulledTokensData memory vars = FluidDexTokensUtils.pullTokensIfNeededWithApproval(
            _tokens,
            _data.from,
            _data.vault,
            _data.exactData.maxCollAmount0,
            _data.exactData.maxCollAmount1
        );

        uint256 msgValue = vars.isToken0Native
            ? vars.amount0
            : (vars.isToken1Native ? vars.amount1 : 0);

        int256[] memory operatePerfectData;

        (nftId, operatePerfectData) = _data.vaultType.isT2Vault()
            ? IFluidVaultT2(_data.vault).operatePerfect{ value: msgValue }(
                _data.nftId,
                _data.exactData.perfectCollShares.signed256(),
                vars.amount0.signed256(),
                vars.amount1.signed256(),
                0, /* debtAmount */
                address(0) /* to */
            )
            : IFluidVaultT4(_data.vault).operatePerfect{ value: msgValue}(
                _data.nftId,
                _data.exactData.perfectCollShares.signed256(),
                vars.amount0.signed256(),
                vars.amount1.signed256(),
                0, /* perfectDebtShares */
                0, /* minDebtAmount0 */ 
                0, /* minDebtAmount1 */
                address(0) /* to */
            );

        // Indexing of collateral data is same for T2 and T4 vaults.
        collShares = uint256(operatePerfectData[0]);

        {   // Refund any excess collateral0
            uint256 pulledCollAmount0 = uint256(operatePerfectData[1]);
            if (pulledCollAmount0 < vars.amount0) {
                uint256 refund = vars.amount0 - pulledCollAmount0;
                // Refund ETH as WETH
                if (vars.isToken0Native) {
                    TokenUtils.depositWeth(refund);
                    TokenUtils.WETH_ADDR.withdrawTokens(_data.from, refund);
                } else {
                    _tokens.token0.withdrawTokens(_data.from, refund);
                    _tokens.token0.approveToken(_data.vault, 0);
                }
            }
        }
        {   // Refund any excess collateral1
            uint256 pulledCollAmount1 = uint256(operatePerfectData[2]);
            if (pulledCollAmount1 < vars.amount1) {
                uint256 refund = vars.amount1 - pulledCollAmount1;
                // Refund ETH as WETH
                if (vars.isToken1Native) {
                    TokenUtils.depositWeth(refund);
                    TokenUtils.WETH_ADDR.withdrawTokens(_data.from, refund);
                } else {
                    _tokens.token1.withdrawTokens(_data.from, refund);
                    _tokens.token1.approveToken(_data.vault, 0);
                }
            }
        }
    }
}