// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVault } from "../../../interfaces/fluid/vaults/IFluidVault.sol";
import { IFluidVaultResolver } from "../../../interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { FluidHelper } from "../helpers/FluidHelper.sol";
import { FluidDexModel } from "../helpers/FluidDexModel.sol";
import { FluidLiquidityModel } from "../helpers/FluidLiquidityModel.sol";
import { FluidPaybackLiquidityLogic } from "../logic/liquidity/FluidPaybackLiquidityLogic.sol";
import { FluidPaybackDexLogic } from "../logic/dex/FluidPaybackDexLogic.sol";
import { FluidVaultTypes } from "../helpers/FluidVaultTypes.sol";
import { ActionBase } from "../../ActionBase.sol";
import { TokenUtils } from "../../../utils/TokenUtils.sol";

contract FluidDexPayback is ActionBase, FluidHelper {
    using TokenUtils for address;
    using FluidVaultTypes for uint256;

    struct Params {
        address vault;
        address from;
        uint256 nftId;
        FluidDexModel.ActionType paybackAction;
        uint256 paybackAmount;
        FluidDexModel.PaybackVariableData paybackVariableData;
        FluidDexModel.PaybackExactData paybackExactData;
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
        params.nftId = _parseParamUint(params.nftId, _paramMapping[2], _subData, _returnValues);

        params.paybackAction = FluidDexModel.ActionType(_parseParamUint(uint8(params.paybackAction), _paramMapping[3], _subData, _returnValues));
        params.paybackAmount = _parseParamUint(params.paybackAmount, _paramMapping[4], _subData, _returnValues);
        params.paybackVariableData.debtAmount0 = _parseParamUint(params.paybackVariableData.debtAmount0, _paramMapping[5], _subData, _returnValues);
        params.paybackVariableData.debtAmount1 = _parseParamUint(params.paybackVariableData.debtAmount1, _paramMapping[6], _subData, _returnValues);
        params.paybackVariableData.maxDebtShares = _parseParamUint(params.paybackVariableData.maxDebtShares, _paramMapping[7], _subData, _returnValues);
        params.paybackExactData.perfectDebtShares = _parseParamUint(params.paybackExactData.perfectDebtShares, _paramMapping[8], _subData, _returnValues);
        params.paybackExactData.maxDebtAmount0 = _parseParamUint(params.paybackExactData.maxDebtAmount0, _paramMapping[9], _subData, _returnValues);
        params.paybackExactData.maxDebtAmount1 = _parseParamUint(params.paybackExactData.maxDebtAmount1, _paramMapping[10], _subData, _returnValues);

        (uint256 paybackAmountOrBurnedShares, bytes memory logData) = _payback(params);
        emit ActionEvent("FluidDexPayback", logData);
        return bytes32(paybackAmountOrBurnedShares);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _payback(params);
        logger.logActionDirectEvent("FluidDexPayback", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _payback(Params memory _params) internal returns (uint256, bytes memory) {
        IFluidVault.ConstantViews memory constants = IFluidVault(_params.vault).constantsView();
        constants.vaultType.requireDexVault();

        (IFluidVaultResolver.UserPosition memory userPosition, ) = 
                IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(_params.nftId);

        if (_params.paybackAction == FluidDexModel.ActionType.LIQUIDITY) {
            uint256 paybackAmount = FluidPaybackLiquidityLogic.payback(
                FluidLiquidityModel.PaybackData({
                    vault: _params.vault,
                    vaultType: constants.vaultType,
                    nftId: _params.nftId,
                    borrowToken: constants.borrowToken.token0,
                    amount: _params.paybackAmount,
                    from: _params.from,
                    position: userPosition
                })
            );
            return (paybackAmount, abi.encode(_params));
        }

        FluidDexModel.PaybackDexData memory dexData = FluidDexModel.PaybackDexData({
            vault: _params.vault,
            vaultType: constants.vaultType,
            nftId: _params.nftId,
            from: _params.from,
            variableData: _params.paybackVariableData,
            exactData: _params.paybackExactData,
            position: userPosition
        });

        uint256 burnedShares = _params.paybackAction == FluidDexModel.ActionType.VARIABLE_DEX
            ? FluidPaybackDexLogic.paybackVariable(dexData, constants.borrowToken)
            : FluidPaybackDexLogic.paybackExact(dexData, constants.borrowToken);

        return (burnedShares, abi.encode(_params));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}