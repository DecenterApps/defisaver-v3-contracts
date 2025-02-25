// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../interfaces/fluid/vaults/IFluidVaultT1.sol";
import { FluidSupplyLiquidityLogic } from "../logic/liquidity/FluidSupplyLiquidityLogic.sol";
import { FluidLiquidityModel } from "../helpers/FluidLiquidityModel.sol";
import { FluidVaultTypes } from "../helpers/FluidVaultTypes.sol";
import { ActionBase } from "../../ActionBase.sol";
import { TokenUtils } from "../../../utils/TokenUtils.sol";

/// @title Open position on Fluid Vault T1 (1_col:1_debt)
contract FluidVaultT1Open is ActionBase {
    using TokenUtils for address;

    /// @param vault The address of the Fluid Vault T1
    /// @param collAmount Amount of collateral to deposit.
    /// @param debtAmount Amount of debt to borrow. Can be 0 if only depositing collateral.
    /// @param from Address to pull the collateral from.
    /// @param to Address to send the borrowed assets to.
    /// @param wrapBorrowedEth Whether to wrap the borrowed ETH into WETH if the borrowed asset is ETH.
    struct Params {
        address vault;
        uint256 collAmount;
        uint256 debtAmount;
        address from;
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
        params.collAmount = _parseParamUint(params.collAmount, _paramMapping[1], _subData, _returnValues);
        params.debtAmount = _parseParamUint(params.debtAmount, _paramMapping[2], _subData, _returnValues);
        params.from = _parseParamAddr(params.from, _paramMapping[3], _subData, _returnValues);
        params.to = _parseParamAddr(params.to, _paramMapping[4], _subData, _returnValues);
        params.wrapBorrowedEth = _parseParamUint(
            params.wrapBorrowedEth ? 1 : 0,
            _paramMapping[5],
            _subData,
            _returnValues
        ) == 1;

        (uint256 nftId, bytes memory logData) = _open(params);
        emit ActionEvent("FluidVaultT1Open", logData);
        return bytes32(nftId);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _open(params);
        logger.logActionDirectEvent("FluidVaultT1Open", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _open(Params memory _params) internal returns (uint256, bytes memory) {
        IFluidVaultT1.ConstantViews memory constants = IFluidVaultT1(_params.vault).constantsView();

        bool shouldWrapBorrowedEth = 
            _params.wrapBorrowedEth &&
            _params.debtAmount > 0 &&
            constants.borrowToken == TokenUtils.ETH_ADDR;

        address sendTokensTo = shouldWrapBorrowedEth ? address(this) : _params.to;

        (uint256 nftId, ) = FluidSupplyLiquidityLogic.supply(
            FluidLiquidityModel.SupplyData({
                vault: _params.vault,
                vaultType: FluidVaultTypes.T1_VAULT_TYPE,
                nftId: 0,
                supplyToken: constants.supplyToken,
                amount: _params.collAmount,
                from: _params.from,
                debtAmount: _params.debtAmount,
                debtTo: sendTokensTo
            })
        );

        if (shouldWrapBorrowedEth) {
            TokenUtils.depositWeth(_params.debtAmount);
            TokenUtils.WETH_ADDR.withdrawTokens(_params.to, _params.debtAmount);    
        }

        return (nftId, abi.encode(_params));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
