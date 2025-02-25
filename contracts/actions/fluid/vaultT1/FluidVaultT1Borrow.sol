// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../interfaces/fluid/vaults/IFluidVaultT1.sol";
import { FluidBorrowLiquidityLogic } from "../logic/liquidity/FluidBorrowLiquidityLogic.sol";
import { FluidLiquidityModel } from "../helpers/FluidLiquidityModel.sol";
import { FluidVaultTypes } from "../helpers/FluidVaultTypes.sol";
import { ActionBase } from "../../ActionBase.sol";

/// @title Borrow assets from Fluid Vault T1 (1_col:1_debt)
contract FluidVaultT1Borrow is ActionBase {

    /// @param vault The address of the Fluid Vault T1
    /// @param nftId ID of the NFT representing the position
    /// @param amount Amount to borrow
    /// @param to Address to send the borrowed assets to
    /// @param wrapBorrowedEth Whether to wrap the borrowed ETH into WETH if the borrowed asset is ETH.
    struct Params {
        address vault;
        uint256 nftId;
        uint256 amount;
        address to;
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
        params.nftId = _parseParamUint(params.nftId, _paramMapping[1], _subData, _returnValues);
        params.amount = _parseParamUint(params.amount, _paramMapping[2], _subData, _returnValues);
        params.to = _parseParamAddr(params.to, _paramMapping[3], _subData, _returnValues);
        params.wrapBorrowedEth = _parseParamUint(
            params.wrapBorrowedEth ? 1 : 0,
            _paramMapping[4],
            _subData,
            _returnValues
        ) == 1;

        (uint256 amount, bytes memory logData) = _borrow(params);
        emit ActionEvent("FluidVaultT1Borrow", logData);
        return bytes32(amount);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _borrow(params);
        logger.logActionDirectEvent("FluidVaultT1Borrow", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _borrow(Params memory _params) internal returns (uint256, bytes memory) {
        IFluidVaultT1.ConstantViews memory constants = IFluidVaultT1(_params.vault).constantsView();

        uint256 borrowAmount = FluidBorrowLiquidityLogic.borrow(
            FluidLiquidityModel.BorrowData({
                vault: _params.vault,
                vaultType: FluidVaultTypes.T1_VAULT_TYPE,
                nftId: _params.nftId,
                borrowToken: constants.borrowToken,
                amount: _params.amount,
                to: _params.to,
                wrapBorrowedEth: _params.wrapBorrowedEth
            })
        );

        return (borrowAmount, abi.encode(_params));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
