// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../../contracts/interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultResolver } from "../../../../contracts/interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { IFluidVaultFactory } from "../../../../contracts/interfaces/fluid/IFluidVaultFactory.sol";
import { FluidVaultT1Open } from "../../../../contracts/actions/fluid/vaultT1/FluidVaultT1Open.sol";
import { FluidVaultT1Supply } from "../../../../contracts/actions/fluid/vaultT1/FluidVaultT1Supply.sol";
import { TokenUtils } from "../../../../contracts/utils/TokenUtils.sol";

import { FluidExecuteActions } from "../../../utils/executeActions/FluidExecuteActions.sol";
import { SmartWallet } from "../../../utils/SmartWallet.sol";
import { console } from "forge-std/console.sol";

contract TestFluidVaultT1Supply is FluidExecuteActions {

    /*//////////////////////////////////////////////////////////////////////////
                                CONTRACT UNDER TEST
    //////////////////////////////////////////////////////////////////////////*/
    FluidVaultT1Supply cut;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    SmartWallet wallet;
    address sender;
    address walletAddr;
    IFluidVaultT1[] vaults;

    FluidVaultT1Open openContract;

    /*//////////////////////////////////////////////////////////////////////////
                                   SETUP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        forkMainnetLatest();

        wallet = new SmartWallet(bob);
        sender = wallet.owner();
        walletAddr = wallet.walletAddr();

        cut = new FluidVaultT1Supply();
        openContract = new FluidVaultT1Open();

        vaults = getT1Vaults();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    ////////////////////////////////////////////////////////////////////////*/
    function test_should_supply() public {
        bool isDirect = false;
        bool takeMaxUint256 = false;
        uint256 collateralAmountInUSD = 30000;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD);
    }
    function test_should_supply_direct_action() public {
        bool isDirect = true;
        bool takeMaxUint256 = false;
        uint256 collateralAmountInUSD = 30000;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD);
    }
    function test_should_supply_with_maxUint256() public {
        bool isDirect = false;
        bool takeMaxUint256 = true;
        uint256 collateralAmountInUSD = 30000;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD);
    }
    function _baseTest(
        bool _isDirect,
        bool _takeMaxUint256,
        uint256 _collateralAmountInUSD
    ) internal {
        uint256 initialSupplyOpenAmountUSD = 10000;

        for (uint256 i = 0; i < vaults.length; ++i) {

            uint256 nftId = executeFluidVaultT1Open(
                address(vaults[i]),
                initialSupplyOpenAmountUSD,
                0,
                wallet,
                address(openContract)
            );

            IFluidVaultT1.ConstantViews memory constants = vaults[i].constantsView();
            if (constants.supplyToken == TokenUtils.ETH_ADDR) {
                constants.supplyToken = TokenUtils.WETH_ADDR;
            }

            uint256 supplyAmount = amountInUSDPrice(constants.supplyToken, _collateralAmountInUSD);
            give(constants.supplyToken, sender, supplyAmount);
            approveAsSender(sender, constants.supplyToken, walletAddr, supplyAmount);

            bytes memory executeActionCallData = executeActionCalldata(
                fluidVaultT1SupplyEncode(
                    address(vaults[i]),
                    nftId,
                    _takeMaxUint256 ? type(uint256).max : supplyAmount,
                    sender
                ),
                _isDirect
            );

            (IFluidVaultResolver.UserPosition memory userPositionBefore, ) = 
                IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(nftId);

            uint256 senderSupplyTokenBalanceBefore = balanceOf(constants.supplyToken, sender);
            uint256 walletSupplyTokenBalanceBefore = balanceOf(constants.supplyToken, walletAddr);
            wallet.execute(address(cut), executeActionCallData, 0);
            uint256 senderSupplyTokenBalanceAfter = balanceOf(constants.supplyToken, sender);
            uint256 walletSupplyTokenBalanceAfter = balanceOf(constants.supplyToken, walletAddr);

            assertEq(walletSupplyTokenBalanceAfter, walletSupplyTokenBalanceBefore);
            assertEq(senderSupplyTokenBalanceAfter, senderSupplyTokenBalanceBefore - supplyAmount);

            (IFluidVaultResolver.UserPosition memory userPositionAfter, ) = 
                IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(nftId);

            console.log("supplyAmount: ", supplyAmount);
            console.log("diff1:", userPositionAfter.supply - userPositionBefore.supply);
            console.log("userPositionBefore.supply", userPositionBefore.supply);
            console.log("userPositionAfter.supply", userPositionAfter.supply);
        }
    }
}