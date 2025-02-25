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
library FluidSupplyLiquidityLogic {
    using TokenUtils for address;
    using DFSMath for uint256;
    using FluidVaultTypes for uint256;

    /// @notice Supplies tokens to a Fluid liquidity layer
    /// @param _data Supply data
    /// @return nftId NFT id of the position. Used when opening a new position
    /// @return supplyAmount Amount of tokens supplied. Will be the same as the input amount
    function supply(
        FluidLiquidityModel.SupplyData memory _data
    ) internal returns (uint256 nftId, uint256 supplyAmount) {
        _data.vaultType.requireLiquidityCollateral();

        uint256 msgValue;

        if (_data.supplyToken == TokenUtils.ETH_ADDR) {
            _data.amount = TokenUtils.WETH_ADDR.pullTokensIfNeeded(_data.from, _data.amount);
            TokenUtils.withdrawWeth(_data.amount);
            msgValue = _data.amount;
        } else {
            _data.amount = _data.supplyToken.pullTokensIfNeeded(_data.from, _data.amount);
            _data.supplyToken.approveToken(_data.vault, _data.amount);
        }

        (nftId , , ) = _data.vaultType.isT1Vault()
            ? IFluidVaultT1(_data.vault).operate{ value: msgValue }(
                _data.nftId,
                _data.amount.signed256(),
                _data.debtAmount.signed256(), // used during opening of new position
                _data.debtTo // used during opening of new position
            )
            : IFluidVaultT3(_data.vault).operate{ value: msgValue }(
                _data.nftId,
                _data.amount.signed256(),
                0, /* newDebtToken0_ */
                0, /* newDebtToken1_ */
                0, /* debtSharesMinMax_ */
                address(0) /* to */
            );

        return (nftId, _data.amount);
    }
}