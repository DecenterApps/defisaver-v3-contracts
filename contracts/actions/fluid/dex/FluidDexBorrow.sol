// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVault } from "../../../interfaces/fluid/vaults/IFluidVault.sol";
import { FluidHelper } from "../helpers/FluidHelper.sol";
import { FluidDexModel } from "../helpers/FluidDexModel.sol";
import { FluidLiquidityModel } from "../helpers/FluidLiquidityModel.sol";
import { FluidBorrowLiquidityLogic } from "../logic/liquidity/FluidBorrowLiquidityLogic.sol";
import { FluidBorrowDexLogic } from "../logic/dex/FluidBorrowDexLogic.sol";
import { FluidVaultTypes } from "../helpers/FluidVaultTypes.sol";
import { ActionBase } from "../../ActionBase.sol";
import { TokenUtils } from "../../../utils/TokenUtils.sol";

/// @title Borrow tokens from Fluid DEX vault (T2, T3, T4)
contract FluidDexBorrow is ActionBase, FluidHelper {
    using TokenUtils for address;
    using FluidVaultTypes for uint256;

    /// @param vault The address of the Fluid DEX vault.
    /// @param to Address to send the borrowed assets to.
    /// @param nftId The NFT ID of the position.
    /// @param borrowAction Borrow action type.
    /// @param borrowAmount Amount of debt to borrow. Used if borrow action is LIQUIDITY.
    /// @param borrowVariableData Variable data for borrow action. Used if borrow action is VARIABLE_DEX.
    /// @param borrowExactData Exact data for borrow action. Used if borrow action is EXACT_DEX.
    /// @param wrapBorrowedEth Whether to wrap the borrowed ETH into WETH if one of the borrowed assets is ETH.
    struct Params {
        address vault;
        address to;
        uint256 nftId;
        FluidDexModel.ActionType borrowAction;
        uint256 borrowAmount;
        FluidDexModel.BorrowVariableData borrowVariableData;
        FluidDexModel.BorrowExactData borrowExactData;
        bool wrapBorrowedEth;
    }

    /// @inheritdoc ActionBase
    function executeAction(
        bytes memory _callData,
        bytes32[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        params.vault = _parseParamAddr(params.vault, _paramMapping[0], _subData, _returnValues);
        params.to = _parseParamAddr(params.to, _paramMapping[1], _subData, _returnValues);
        params.nftId = _parseParamUint(params.nftId, _paramMapping[2], _subData, _returnValues);

        params.borrowAction = FluidDexModel.ActionType(_parseParamUint(uint8(params.borrowAction), _paramMapping[3], _subData, _returnValues));
        params.borrowAmount = _parseParamUint(params.borrowAmount, _paramMapping[4], _subData, _returnValues);
        params.borrowVariableData.debtAmount0 = _parseParamUint(params.borrowVariableData.debtAmount0, _paramMapping[5], _subData, _returnValues);
        params.borrowVariableData.debtAmount1 = _parseParamUint(params.borrowVariableData.debtAmount1, _paramMapping[6], _subData, _returnValues);
        params.borrowVariableData.minDebtShares = _parseParamUint(params.borrowVariableData.minDebtShares, _paramMapping[7], _subData, _returnValues);
        params.borrowExactData.perfectDebtShares = _parseParamUint(params.borrowExactData.perfectDebtShares, _paramMapping[8], _subData, _returnValues);
        params.borrowExactData.minDebtAmount0 = _parseParamUint(params.borrowExactData.minDebtAmount0, _paramMapping[9], _subData, _returnValues);
        params.borrowExactData.minDebtAmount1 = _parseParamUint(params.borrowExactData.minDebtAmount1, _paramMapping[10], _subData, _returnValues);
        params.wrapBorrowedEth = _parseParamUint(params.wrapBorrowedEth ? 1 : 0, _paramMapping[11], _subData, _returnValues) == 1;

        (uint256 borrowAmountOrShares, bytes memory logData) = _borrow(params);
        emit ActionEvent("FluidDexBorrow", logData);
        return bytes32(borrowAmountOrShares);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _borrow(params);
        logger.logActionDirectEvent("FluidDexBorrow", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _borrow(Params memory _params) internal returns (uint256, bytes memory) {
        IFluidVault.ConstantViews memory constants = IFluidVault(_params.vault).constantsView();
        constants.vaultType.requireDexVault();

        if (_params.borrowAction == FluidDexModel.ActionType.LIQUIDITY) {
            uint256 borrowAmount = FluidBorrowLiquidityLogic.borrow(
                FluidLiquidityModel.BorrowData({
                    vault: _params.vault,
                    vaultType: constants.vaultType,
                    nftId: _params.nftId,
                    borrowToken: constants.borrowToken.token0,
                    amount: _params.borrowAmount,
                    to: _params.to,
                    wrapBorrowedEth: _params.wrapBorrowedEth
                })
            );
            return (borrowAmount, abi.encode(_params));
        }

        FluidDexModel.BorrowDexData memory dexData = FluidDexModel.BorrowDexData({
            vault: _params.vault,
            vaultType: constants.vaultType,
            nftId: _params.nftId,
            to: _params.to,
            variableData: _params.borrowVariableData,
            exactData: _params.borrowExactData,
            wrapBorrowedEth: _params.wrapBorrowedEth
        });

        uint256 borrowShares = _params.borrowAction == FluidDexModel.ActionType.VARIABLE_DEX
            ? FluidBorrowDexLogic.borrowVariable(dexData, constants.borrowToken)
            : FluidBorrowDexLogic.borrowExact(dexData, constants.borrowToken);

        return (borrowShares, abi.encode(_params));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}