// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../contracts/interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultResolver } from "../../../contracts/interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { IFluidVaultFactory } from "../../../contracts/interfaces/fluid/IFluidVaultFactory.sol";
import { FluidTestHelper } from "../../actions/fluid/FluidTestHelper.t.sol";
import { TokenUtils } from "../../../contracts/utils/TokenUtils.sol";
import { ExecuteActionsBase } from "./ExecuteActionsBase.sol";
import { SmartWallet } from "../SmartWallet.sol";
import { Vm } from "forge-std/Vm.sol";

contract FluidExecuteActions is ExecuteActionsBase, FluidTestHelper {

    error NftNotFound();

    function executeFluidVaultT1Open(
        address _vault,
        uint256 _collAmountInUSD,
        uint256 _borrowAmountInUSD,
        SmartWallet _wallet,
        address _openContract
    ) internal returns (uint256 nftId) {
        IFluidVaultT1.ConstantViews memory constants = IFluidVaultT1(_vault).constantsView();
        bool isNativeSupply = constants.supplyToken == TokenUtils.ETH_ADDR;
        bool isNativeBorrow = constants.borrowToken == TokenUtils.ETH_ADDR;
    
        constants.supplyToken = isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken;
        uint256 collAmount = amountInUSDPrice(constants.supplyToken, _collAmountInUSD);
        give(constants.supplyToken, _wallet.owner(), collAmount);
        _wallet.ownerApprove(constants.supplyToken, collAmount);

        uint256 borrowAmount = _borrowAmountInUSD != 0
                ? amountInUSDPrice(isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken, _borrowAmountInUSD)
                : 0;

        bytes memory executeActionCallData = executeActionCalldata(
            fluidVaultT1OpenEncode(
                _vault,
                collAmount,
                borrowAmount,
                _wallet.owner(),
                _wallet.owner(),
                false
            ),
            true
        );

        vm.recordLogs();
        _wallet.execute(_openContract, executeActionCallData, 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics[0] == IFluidVaultFactory.NewPositionMinted.selector) {
                nftId = uint256(logs[i].topics[3]);
                return nftId;
            }
        }

        revert NftNotFound();
    }
}