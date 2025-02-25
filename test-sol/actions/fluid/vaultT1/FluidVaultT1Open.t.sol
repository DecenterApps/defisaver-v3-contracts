// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../../contracts/interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultResolver } from "../../../../contracts/interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { IFluidVaultFactory } from "../../../../contracts/interfaces/fluid/IFluidVaultFactory.sol";
import { FluidVaultT1Open } from "../../../../contracts/actions/fluid/vaultT1/FluidVaultT1Open.sol";
import { FluidTestHelper } from "../FluidTestHelper.t.sol";

import { SmartWallet } from "../../../utils/SmartWallet.sol";
import { TokenUtils } from "../../../../contracts/utils/TokenUtils.sol";
import { BaseTest } from "../../../utils/BaseTest.sol";
import { ActionsUtils } from "../../../utils/ActionsUtils.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

contract TestFluidVaultT1Open is BaseTest, FluidTestHelper, ActionsUtils {

    /*//////////////////////////////////////////////////////////////////////////
                                CONTRACT UNDER TEST
    //////////////////////////////////////////////////////////////////////////*/
    FluidVaultT1Open cut;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    SmartWallet wallet;
    address sender;
    address walletAddr;
    IFluidVaultT1[] vaults;

    /*//////////////////////////////////////////////////////////////////////////
                                   SETUP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        forkMainnetLatest();

        wallet = new SmartWallet(bob);
        sender = wallet.owner();
        walletAddr = wallet.walletAddr();

        cut = new FluidVaultT1Open();

        vaults = getT1Vaults();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    ////////////////////////////////////////////////////////////////////////*/
    function test_should_open_position() public {
        bool isDirect = false;
        bool takeMaxUint256 = false;
        uint256 collateralAmountInUSD = 30000;
        uint256 borrowAmountInUSD = 10000;
        bool wrapBorrowedEth = false;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD, borrowAmountInUSD, wrapBorrowedEth);
    }
    function test_should_open_position_direct_action() public {
        bool isDirect = true;
        bool takeMaxUint256 = false;
        uint256 collateralAmountInUSD = 30000;
        uint256 borrowAmountInUSD = 10000;
        bool wrapBorrowedEth = false;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD, borrowAmountInUSD, wrapBorrowedEth);
    }
    function test_should_open_position_with_maxUint256() public {
        bool isDirect = false;
        bool takeMaxUint256 = true;
        uint256 collateralAmountInUSD = 30000;
        uint256 borrowAmountInUSD = 10000;
        bool wrapBorrowedEth = false;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD, borrowAmountInUSD, wrapBorrowedEth);
    }
    function test_should_open_only_supply_position() public {
        bool isDirect = false;
        bool takeMaxUint256 = false;
        uint256 collateralAmountInUSD = 30000;
        uint256 borrowAmountInUSD = 0;
        bool wrapBorrowedEth = false;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD, borrowAmountInUSD, wrapBorrowedEth);
    }
    function test_should_open_position_with_borrow_eth_wrap() public {
        bool isDirect = false;
        bool takeMaxUint256 = false;
        uint256 collateralAmountInUSD = 30000;
        uint256 borrowAmountInUSD = 10000;
        bool wrapBorrowedEth = true;
        _baseTest(isDirect, takeMaxUint256, collateralAmountInUSD, borrowAmountInUSD, wrapBorrowedEth);
    }
    function _baseTest(
        bool isDirect,
        bool takeMaxUint256,
        uint256 collateralAmountInUSD,
        uint256 borrowAmountInUSD,
        bool wrapBorrowedEth
    ) internal {
        for (uint256 i = 0; i < vaults.length; ++i) {
            IFluidVaultT1.ConstantViews memory constants = vaults[i].constantsView();
            bool isNativeSupply = constants.supplyToken == TokenUtils.ETH_ADDR;
            bool isNativeBorrow = constants.borrowToken == TokenUtils.ETH_ADDR;

            constants.supplyToken = isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken;
            uint256 supplyAmount = amountInUSDPrice(constants.supplyToken, collateralAmountInUSD);
            give(constants.supplyToken, sender, supplyAmount);
            approveAsSender(sender, constants.supplyToken, walletAddr, supplyAmount);    

            uint256 borrowAmount = borrowAmountInUSD != 0
                ? amountInUSDPrice(isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken, borrowAmountInUSD)
                : 0;

            bytes memory executeActionCallData = executeActionCalldata(
                fluidVaultT1OpenEncode(
                    address(vaults[i]),
                    takeMaxUint256 ? type(uint256).max : supplyAmount,
                    borrowAmount,
                    sender,
                    sender,
                    wrapBorrowedEth
                ),
                isDirect
            );

            uint256 senderSupplyTokenBalanceBefore = balanceOf(constants.supplyToken, sender);
            uint256 senderBorrowTokenBalanceBefore = isNativeBorrow 
                ? (
                    wrapBorrowedEth? balanceOf(TokenUtils.WETH_ADDR, sender) : address(sender).balance
                )
                : balanceOf(constants.borrowToken, sender);

            vm.recordLogs();

            wallet.execute(address(cut), executeActionCallData, 0);

            Vm.Log[] memory logs = vm.getRecordedLogs();

            uint256 createdNft;
            for (uint256 j = 0; j < logs.length; ++j) {
                if (logs[j].topics[0] == IFluidVaultFactory.NewPositionMinted.selector) {
                    createdNft = uint256(logs[j].topics[3]);
                    break;
                }
            }
            assertNotEq(createdNft, 0);

            uint256 senderSupplyTokenBalanceAfter = balanceOf(constants.supplyToken, sender);
            uint256 senderBorrowTokenBalanceAfter = isNativeBorrow 
                ? (
                    wrapBorrowedEth ? balanceOf(TokenUtils.WETH_ADDR, sender) : address(sender).balance 
                ) 
                : balanceOf(constants.borrowToken, sender);

            assertEq(senderSupplyTokenBalanceAfter, senderSupplyTokenBalanceBefore - supplyAmount);
            assertEq(senderBorrowTokenBalanceAfter, senderBorrowTokenBalanceBefore + borrowAmount);

            (IFluidVaultResolver.UserPosition memory userPosition, ) = 
                IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(createdNft);

            assertEq(userPosition.owner, walletAddr);
            assertEq(userPosition.isLiquidated, false);
            assertEq(userPosition.isSupplyPosition, borrowAmount == 0);

            _logData(supplyAmount, borrowAmount, userPosition);
        }
    }

    function _logData(
        uint256 supplyAmount,
        uint256 borrowAmount,
        IFluidVaultResolver.UserPosition memory userPosition
    ) internal view {
        console.log("supplyAmount", supplyAmount);
        console.log("borrowAmount", borrowAmount);
        console.log("owner", userPosition.owner);
        console.log("isLiquidated", userPosition.isLiquidated);
        console.log("isSupplyPosition", userPosition.isSupplyPosition);
        console.log("tick", uint256(userPosition.tick));
        console.log("tickId", userPosition.tickId);
        console.log("beforeSupply", userPosition.beforeSupply);
        console.log("beforeBorrow", userPosition.beforeBorrow);
        console.log("beforeDustBorrow", userPosition.beforeDustBorrow);
        console.log("supply", userPosition.supply);
        console.log("borrow", userPosition.borrow);
        console.log("dustBorrow", userPosition.dustBorrow);
    }
}