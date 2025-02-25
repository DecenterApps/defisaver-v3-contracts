// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVault } from "../../../interfaces/fluid/vaults/IFluidVault.sol";
import { FluidHelper } from "../helpers/FluidHelper.sol";
import { FluidDexModel } from "../helpers/FluidDexModel.sol";
import { FluidLiquidityModel } from "../helpers/FluidLiquidityModel.sol";
import { FluidSupplyLiquidityLogic } from "../logic/liquidity/FluidSupplyLiquidityLogic.sol";
import { FluidSupplyDexLogic } from "../logic/dex/FluidSupplyDexLogic.sol";
import { FluidBorrowLiquidityLogic } from "../logic/liquidity/FluidBorrowLiquidityLogic.sol";
import { FluidBorrowDexLogic } from "../logic/dex/FluidBorrowDexLogic.sol";
import { FluidVaultTypes } from "../helpers/FluidVaultTypes.sol";
import { ActionBase } from "../../ActionBase.sol";
import { TokenUtils } from "../../../utils/TokenUtils.sol";

/// @title Open position on Fluid DEX vault (T2, T3, T4)
contract FluidDexOpen is ActionBase, FluidHelper {
    using TokenUtils for address;
    using FluidVaultTypes for uint256;

    /// @param vault The address of the Fluid DEX vault.
    /// @param from Address to pull the collateral from.
    /// @param to Address to send the borrowed assets to.
    /// @param supplyAction Supply action type.
    /// @param supplyAmount Amount of collateral to deposit. Used if supply action is LIQUIDITY.
    /// @param supplyVariableData Variable data for supply action. Used if supply action is VARIABLE_DEX.
    /// @param supplyExactData Exact data for supply action. Used if supply action is EXACT_DEX.
    /// @param borrowAction Borrow action type.
    /// @param borrowAmount Amount of debt to borrow. Used if borrow action is LIQUIDITY.
    /// @param borrowVariableData Variable data for borrow action. Used if borrow action is VARIABLE_DEX.
    /// @param borrowExactData Exact data for borrow action. Used if borrow action is EXACT_DEX.
    /// @param wrapBorrowedEth Whether to wrap the borrowed ETH into WETH if one of the borrowed assets is ETH.
    struct Params {
        address vault;
        address from;
        address to;
        FluidDexModel.ActionType supplyAction;
        uint256 supplyAmount;
        FluidDexModel.SupplyVariableData supplyVariableData;
        FluidDexModel.SupplyExactData supplyExactData;
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
        params.from = _parseParamAddr(params.from, _paramMapping[1], _subData, _returnValues);
        params.to = _parseParamAddr(params.to, _paramMapping[2], _subData, _returnValues);

        params.supplyAction = FluidDexModel.ActionType(_parseParamUint(uint8(params.supplyAction), _paramMapping[3], _subData, _returnValues));
        params.supplyAmount = _parseParamUint(params.supplyAmount, _paramMapping[4], _subData, _returnValues);
        params.supplyVariableData.collAmount0 = _parseParamUint(params.supplyVariableData.collAmount0, _paramMapping[5], _subData, _returnValues);
        params.supplyVariableData.collAmount1 = _parseParamUint(params.supplyVariableData.collAmount1, _paramMapping[6], _subData, _returnValues);
        params.supplyVariableData.minCollShares = _parseParamUint(params.supplyVariableData.minCollShares, _paramMapping[7], _subData, _returnValues);
        params.supplyExactData.perfectCollShares = _parseParamUint(params.supplyExactData.perfectCollShares, _paramMapping[8], _subData, _returnValues);
        params.supplyExactData.maxCollAmount0 = _parseParamUint(params.supplyExactData.maxCollAmount0, _paramMapping[9], _subData, _returnValues);
        params.supplyExactData.maxCollAmount1 = _parseParamUint(params.supplyExactData.maxCollAmount1, _paramMapping[10], _subData, _returnValues);

        params.borrowAction = FluidDexModel.ActionType(_parseParamUint(uint8(params.borrowAction), _paramMapping[11], _subData, _returnValues));
        params.borrowAmount = _parseParamUint(params.borrowAmount, _paramMapping[12], _subData, _returnValues);
        params.borrowVariableData.debtAmount0 = _parseParamUint(params.borrowVariableData.debtAmount0, _paramMapping[13], _subData, _returnValues);
        params.borrowVariableData.debtAmount1 = _parseParamUint(params.borrowVariableData.debtAmount1, _paramMapping[14], _subData, _returnValues);
        params.borrowVariableData.minDebtShares = _parseParamUint(params.borrowVariableData.minDebtShares, _paramMapping[15], _subData, _returnValues);
        params.borrowExactData.perfectDebtShares = _parseParamUint(params.borrowExactData.perfectDebtShares, _paramMapping[16], _subData, _returnValues);
        params.borrowExactData.minDebtAmount0 = _parseParamUint(params.borrowExactData.minDebtAmount0, _paramMapping[17], _subData, _returnValues);
        params.borrowExactData.minDebtAmount1 = _parseParamUint(params.borrowExactData.minDebtAmount1, _paramMapping[18], _subData, _returnValues);
        params.wrapBorrowedEth = _parseParamUint(params.wrapBorrowedEth ? 1 : 0, _paramMapping[19], _subData, _returnValues) == 1;

        (uint256 nftId, bytes memory logData) = _open(params);
        emit ActionEvent("FluidDexOpen", logData);
        return bytes32(nftId);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _open(params);
        logger.logActionDirectEvent("FluidDexOpen", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _open(Params memory _params) internal returns (uint256, bytes memory) {
        IFluidVault.ConstantViews memory constants = IFluidVault(_params.vault).constantsView();
        constants.vaultType.requireDexVault();

        // We are deliberately performing open in two separate calls to the vault.  
        // This will incur more gas, but it will significantly simplify logic
        // and reduce the complexity of passing borrow data to the supply logic.  
        // This also gives us the ability to combine different DEX action types,
        // like supply variable and borrow exact, which would not be possible in a single call.  
        uint256 nftId = _supply(_params, constants);

        _borrow(_params, constants, nftId);

        return (nftId, abi.encode(_params));
    }

    function _supply(
        Params memory _params,
        IFluidVault.ConstantViews memory _constants
    ) internal returns (uint256 nftId) {
        if (_params.supplyAction == FluidDexModel.ActionType.LIQUIDITY) {
            (nftId, ) = FluidSupplyLiquidityLogic.supply(
                FluidLiquidityModel.SupplyData({
                    vault: _params.vault,
                    vaultType: _constants.vaultType,
                    nftId: 0,
                    supplyToken: _constants.supplyToken.token0,
                    amount: _params.supplyAmount,
                    from: _params.from,
                    debtAmount: 0,
                    debtTo: address(0)
                })
            );
            return nftId;
        }

        FluidDexModel.SupplyDexData memory dexData = FluidDexModel.SupplyDexData({
            vault: _params.vault,
            vaultType: _constants.vaultType,
            nftId: 0,
            from: _params.from,
            variableData: _params.supplyVariableData,
            exactData: _params.supplyExactData
        });

        (nftId, ) = _params.supplyAction == FluidDexModel.ActionType.VARIABLE_DEX
            ? FluidSupplyDexLogic.supplyVariable(dexData, _constants.supplyToken)
            : FluidSupplyDexLogic.supplyExact(dexData, _constants.supplyToken);
    }

    function _borrow(
        Params memory _params,
        IFluidVault.ConstantViews memory _constants,
        uint256 _nftId
    ) internal {
        if (_params.borrowAction == FluidDexModel.ActionType.LIQUIDITY) {
            FluidBorrowLiquidityLogic.borrow(
                FluidLiquidityModel.BorrowData({
                    vault: _params.vault,
                    vaultType: _constants.vaultType,
                    nftId: _nftId,
                    borrowToken: _constants.borrowToken.token0,
                    amount: _params.borrowAmount,
                    to: _params.to,
                    wrapBorrowedEth: _params.wrapBorrowedEth
                })
            );
            return;
        }

        FluidDexModel.BorrowDexData memory dexData = FluidDexModel.BorrowDexData({
            vault: _params.vault,
            vaultType: _constants.vaultType,
            nftId: _nftId,
            to: _params.to,
            variableData: _params.borrowVariableData,
            exactData: _params.borrowExactData,
            wrapBorrowedEth: _params.wrapBorrowedEth
        });

        _params.borrowAction == FluidDexModel.ActionType.VARIABLE_DEX
            ? FluidBorrowDexLogic.borrowVariable(dexData, _constants.borrowToken)
            : FluidBorrowDexLogic.borrowExact(dexData, _constants.borrowToken);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}