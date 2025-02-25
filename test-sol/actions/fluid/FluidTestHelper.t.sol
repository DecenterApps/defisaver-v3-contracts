// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { FluidHelper } from "../../../contracts/actions/fluid/helpers/FluidHelper.sol";
import { IFluidVaultT1 } from "../../../contracts/interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultT2 } from "../../../contracts/interfaces/fluid/vaults/IFluidVaultT2.sol";

contract FluidTestHelper is FluidHelper {

    address internal constant FLUID_DEX_RESOLVER = 0x7af0C11F5c787632e567e6418D74e5832d8FFd4c;

    function getT1Vaults() internal pure returns (IFluidVaultT1[] memory vaults) {
        vaults = new IFluidVaultT1[](8);
        vaults[0] = IFluidVaultT1(0x1982CC7b1570C2503282d0A0B41F69b3B28fdcc3); // id:14 - wstETH/USDC
        vaults[1] = IFluidVaultT1(0xb4F3bf2d96139563777C0231899cE06EE95Cc946); // id:15 - wstETH/USDT
        vaults[2] = IFluidVaultT1(0x6F72895Cf6904489Bcd862c941c3D02a3eE4f03e); // id:21 - WBTC/USDC
        vaults[3] = IFluidVaultT1(0x6F72895Cf6904489Bcd862c941c3D02a3eE4f03e); // id:25 - wstETH/WBTC
        vaults[4] = IFluidVaultT1(0x025C1494b7d15aa931E011f6740E0b46b2136cb9); // id:25 - rsETH/wstETH
        vaults[5] = IFluidVaultT1(0x01c7c1c41dea58b043e700eFb23Dc077F12a125e); // id:29 - cbBTC/USDC
        vaults[6] = IFluidVaultT1(0x0C8C77B7FF4c2aF7F6CEBbe67350A490E3DD6cB3); // id:11 - ETH/USDC
        vaults[7] = IFluidVaultT1(0x82B27fA821419F5689381b565a8B0786aA2548De); // id:13 - wstETH/ETH
    }

    function getT2Vaults() internal pure returns (IFluidVaultT2[] memory vaults) {
        vaults = new IFluidVaultT2[](3);
        vaults[0] = IFluidVaultT2(0xf7FA55D14C71241e3c970E30C509Ff58b5f5D557); // id:52 - WBTC-cbBTC/USDT
        vaults[1] = IFluidVaultT2(0xb4a15526d427f4d20b0dAdaF3baB4177C85A699A); // id:74 - weETH-ETH/wstETH
        vaults[2] = IFluidVaultT2(0x7503b58Bb29937e7E2980f70D3FD021B7ebeA6d0); // id:92 - sUSDe-USDT/USDT
    }
}