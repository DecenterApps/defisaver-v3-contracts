// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultResolver } from "../../../interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { FluidPaybackLiquidityLogic } from "../logic/liquidity/FluidPaybackLiquidityLogic.sol";
import { FluidLiquidityModel } from "../helpers/FluidLiquidityModel.sol";
import { FluidHelper } from "../helpers/FluidHelper.sol";
import { FluidVaultTypes } from "../helpers/FluidVaultTypes.sol";
import { ActionBase } from "../../ActionBase.sol";

/// @title Payback debt to Fluid Vault T1 (1_col:1_debt)
contract FluidVaultT1Payback is ActionBase, FluidHelper {

    /// @param vault The address of the Fluid Vault T1
    /// @param nftId ID of the NFT representing the position
    /// @param amount Amount to payback
    /// @param from Address to pull the tokens from
    struct Params {
        address vault;
        uint256 nftId;
        uint256 amount;
        address from;
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
        params.nftId = _parseParamUint(params.nftId, _paramMapping[1], _subData, _returnValues);
        params.amount = _parseParamUint(params.amount, _paramMapping[2], _subData, _returnValues);
        params.from = _parseParamAddr(params.from, _paramMapping[3], _subData, _returnValues);

        (uint256 amount, bytes memory logData) = _payback(params);
        emit ActionEvent("FluidVaultT1Payback", logData);
        return bytes32(amount);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _payback(params);
        logger.logActionDirectEvent("FluidVaultT1Payback", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _payback(Params memory _params) internal returns (uint256, bytes memory) {
        IFluidVaultT1.ConstantViews memory constants = IFluidVaultT1(_params.vault).constantsView();

        (IFluidVaultResolver.UserPosition memory userPosition, ) = 
            IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(_params.nftId);

        uint256 exactPaybackAmount = FluidPaybackLiquidityLogic.payback(
            FluidLiquidityModel.PaybackData({
                vault: _params.vault,
                vaultType: FluidVaultTypes.T1_VAULT_TYPE,
                nftId: _params.nftId,
                borrowToken: constants.borrowToken,
                amount: _params.amount,
                from: _params.from,
                position: userPosition
            })
        );

        return (exactPaybackAmount, abi.encode(_params));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
