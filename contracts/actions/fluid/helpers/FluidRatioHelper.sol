// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultResolver } from "../../../interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { IERC20 } from "../../../interfaces/IERC20.sol";

import { FluidVaultTypes } from "./FluidVaultTypes.sol";
import { FluidHelper } from "./FluidHelper.sol";

import { TokenUtils } from "../../../utils/TokenUtils.sol";

/// @title Helper methods for Fluid ratio calc.
contract FluidRatioHelper is FluidHelper {
    using FluidVaultTypes for uint256;

    uint256 internal constant ORACLE_PRICE_DECIMALS = 27;
    uint256 internal constant ETH_DECIMALS = 18;
    uint256 internal constant WAD = 1e18;

    /// @notice Gets ratio for a fluid position
    /// @param _nftId nft id of the fluid position
    function getRatio(uint256 _nftId) public view returns (uint256 ratio) {
        (
            IFluidVaultResolver.UserPosition memory userPosition,
            IFluidVaultResolver.VaultEntireData memory vaultData
        ) = IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(_nftId);

        // For now, only handle the case for T1 Vaults
        if (vaultData.constantVariables.vaultType.isT1Vault()) {
            uint256 collAmount = userPosition.supply;
            address collToken = vaultData.constantVariables.supplyToken.token0;

            uint256 debtAmount = userPosition.borrow;
            address debtToken = vaultData.constantVariables.borrowToken.token0;

            if (debtAmount == 0) return uint256(0);

            uint256 collDec = collToken != TokenUtils.ETH_ADDR ? IERC20(collToken).decimals() : ETH_DECIMALS;
            uint256 debtDec = debtToken != TokenUtils.ETH_ADDR ? IERC20(debtToken).decimals() : ETH_DECIMALS;

            /**
            * @dev Examples:
            *
            * 1. (2.5 WBTC / 50k USDC)
            *    price = 1028534478997854690000000000000
            *    priceScaler = 10 ** (27 - 8 + 6) = 1e25
            *    collAmount = 2.5 * 1e8
            *    debtAmount = 50000 * 1e6
            *    collAmountInDebtToken = ((2.5 * 1e8 * 1028534478997854690000000000000) / 1e25) * 1e6 / 1e8 = 257133619749
            *    ratio = 257133619749 * 1e18 / (50000 * 1e6) = 5.14267239498e18 = 514.267239498 %
            *
            * 2. (3.2 weETH / 1.5 wstETH)
            *    price = 888143936867381715436793889
            *    priceScaler = 10 ** (27 - 18 + 18) = 1e27
            *    collAmount = 3.2 * 1e18
            *    debtAmount = 1.5 * 1e18
            *    collAmountInDebtToken = ((3.2 * 1e18 * 888143936867381715436793889) / 1e27) * 1e18 / 1e18 = 2.8420605979756216e18
            *    ratio = 2.8420605979756216e18 * 1e18 / (1.5 * 1e18) = 1.894707065317081e+18 = 189.47070653170812 %
            *
            * 3. (2 WBTC / 30 ETH)
            *    price =  321857633689348920539866335783307690682 / 10 ** (27 - 8 + 18) = 32.18576336893489
            *    priceScaler = 10 ** (27 - 8 + 18) = 1e37
            *    collAmount = 2 * 1e8
            *    debtAmount = 30 * 1e18
            *    collAmountInDebtToken = ((2 * 1e8 * 321857633689348920539866335783307690682) / 1e37) * 1e18 / 1e8 = 6.437152673786979e19
            *    ratio = 6.437152673786979e19 * 1e18 / (30 * 1e18) = 2.145717557928993e18 = 214.5717557928993 %
            */
            uint256 price = vaultData.configs.oraclePriceOperate;
            uint256 priceScaler = 10 ** (ORACLE_PRICE_DECIMALS - collDec + debtDec);
            uint256 collAmountInDebtToken = ((collAmount * price) / priceScaler) * (10 ** debtDec) / (10 ** collDec);

            ratio = collAmountInDebtToken * WAD / debtAmount;
        }
    }
}