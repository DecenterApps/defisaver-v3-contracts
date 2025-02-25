// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultResolver } from "../../../interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { FluidHelper } from "../helpers/FluidHelper.sol";
import { DFSMath } from "../../../utils/math/DFSMath.sol";
import { ActionBase } from "../../ActionBase.sol";
import { TokenUtils } from "../../../utils/TokenUtils.sol";

/// @title Adjust position on Fluid Vault T1 (1_col:1_debt)
contract FluidVaultT1Adjust is ActionBase, FluidHelper {
    using TokenUtils for address;
    using DFSMath for uint256;

    enum CollActionType { SUPPLY, WITHDRAW }
    enum DebtActionType { PAYBACK, BORROW }

    /// @param vault Address of the Fluid Vault T1
    /// @param nftId ID of the NFT representing the position
    /// @param collAmount Amount of collateral to supply/withdraw. In case of max withdraw, use type(uint256).max
    /// @param debtAmount Amount of debt to payback/borrow. In case of max payback, use type(uint256).max
    /// @param from Address to pull tokens from
    /// @param to Address to send tokens to
    /// @param sendWrappedEth Whether to wrap the ETH into WETH before sending to 'to' address
    ///                       Applicable if one of the following conditions is met:
    ///                       - Supply token is ETH and collActionType is WITHDRAW
    ///                       - Borrow token is ETH and debtActionType is BORROW
    ///                       Note: One flag is enough, because there won't be ETH on both sides.
    /// @param collAction Type of collateral action to perform. 0 for supply, 1 for withdraw
    /// @param debtAction Type of debt action to perform. 0 for payback, 1 for borrow
    struct Params {
        address vault;
        uint256 nftId;
        uint256 collAmount;
        uint256 debtAmount;
        address from;
        address to;
        bool sendWrappedEth;
        CollActionType collAction;
        DebtActionType debtAction;
    }

    /// @dev Helper struct to group local variables for max payback calculation
    /// @param maxPayback Flag to indicate if max payback is needed
    /// @param borrowTokenBalanceBefore Snapshot of borrow token balance before payback
    /// @param borrowTokenBalanceAfter Snapshot of borrow token balance after payback
    struct MaxPaybackSnapshot {
        bool maxPayback;
        uint256 borrowTokenBalanceBefore;
        uint256 borrowTokenBalanceAfter;
    }

    /// @dev Helper struct to group local variables for adjust action. Avoids stack too deep errors.
    struct AdjustLocalVars {
        uint256 msgValue;
        int256 supplyTokenAmount;
        int256 borrowTokenAmount;
        bool sendWithdrawnEthAsWrapped;
        bool sendBorrowedEthAsWrapped;
        address sendTokensTo;
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
        params.collAmount = _parseParamUint(params.collAmount, _paramMapping[2], _subData, _returnValues);
        params.debtAmount = _parseParamUint(params.debtAmount, _paramMapping[3], _subData, _returnValues);
        params.from = _parseParamAddr(params.from, _paramMapping[4], _subData, _returnValues);
        params.to = _parseParamAddr(params.to, _paramMapping[5], _subData, _returnValues);
        params.sendWrappedEth = _parseParamUint(
            params.sendWrappedEth ? 1 : 0,
            _paramMapping[6],
            _subData,
            _returnValues
        ) == 1;
        params.collAction = CollActionType(
            _parseParamUint(uint8(params.collAction), _paramMapping[7], _subData, _returnValues)
        );
        params.debtAction = DebtActionType(
            _parseParamUint(uint8(params.debtAction), _paramMapping[8], _subData, _returnValues)
        );

        (uint256 debtAmount, bytes memory logData) = _adjust(params);
        emit ActionEvent("FluidVaultT1Adjust", logData);
        return bytes32(debtAmount);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _adjust(params);
        logger.logActionDirectEvent("FluidVaultT1Adjust", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _adjust(Params memory _params) internal returns (uint256, bytes memory) {
        IFluidVaultT1.ConstantViews memory constants = IFluidVaultT1(_params.vault).constantsView();

        AdjustLocalVars memory vars;

        vars.sendWithdrawnEthAsWrapped =
            _params.sendWrappedEth && 
            _params.collAction == CollActionType.WITHDRAW &&
            constants.supplyToken == TokenUtils.ETH_ADDR &&
            _params.collAmount > 0;

        vars.sendBorrowedEthAsWrapped =
            _params.sendWrappedEth && 
            _params.debtAction == DebtActionType.BORROW &&
            constants.borrowToken == TokenUtils.ETH_ADDR &&
            _params.debtAmount > 0;

        if (_params.collAction == CollActionType.SUPPLY) {
            (vars.supplyTokenAmount, vars.msgValue) = _handleSupply(_params, constants.supplyToken);
        }

        if (_params.collAction == CollActionType.WITHDRAW) {
            vars.supplyTokenAmount = _handleWithdraw(_params);
        }

        MaxPaybackSnapshot memory paybackSnapshot;
        if (_params.debtAction == DebtActionType.PAYBACK) {
            (paybackSnapshot, vars.msgValue, vars.borrowTokenAmount) = _handlePayback(
                _params,
                constants.borrowToken,
                vars.msgValue
            );
        }

        if (_params.debtAction == DebtActionType.BORROW) {
            vars.borrowTokenAmount = _handleBorrow(_params);
        }

        vars.sendTokensTo = (vars.sendWithdrawnEthAsWrapped || vars.sendBorrowedEthAsWrapped) 
            ? address(this)
            : _params.to;

        ( , int256 exactCollAmt, int256 exactDebtAmt) = IFluidVaultT1(_params.vault).operate{ value: vars.msgValue }(
            _params.nftId,
            vars.supplyTokenAmount,
            vars.borrowTokenAmount,
            vars.sendTokensTo
        );

        if (vars.sendWithdrawnEthAsWrapped) {
            TokenUtils.depositWeth(uint256(-exactCollAmt));
            TokenUtils.WETH_ADDR.withdrawTokens(_params.to, uint256(-exactCollAmt));

            if (_params.debtAction == DebtActionType.BORROW) {
                constants.borrowToken.withdrawTokens(_params.to, uint256(exactDebtAmt));
            }
        }

        if (vars.sendBorrowedEthAsWrapped) {
            TokenUtils.depositWeth(uint256(exactDebtAmt));
            TokenUtils.WETH_ADDR.withdrawTokens(_params.to, uint256(exactDebtAmt));

            if (_params.collAction == CollActionType.WITHDRAW) {
                constants.supplyToken.withdrawTokens(_params.to, uint256(-exactCollAmt));
            }
        }

        if (paybackSnapshot.maxPayback) {
            _handleMaxPaybackRefund(_params, constants.borrowToken, paybackSnapshot);
        }

        uint256 retVal = _params.debtAction == DebtActionType.BORROW
            ? uint256(exactDebtAmt)
            : uint256(-exactDebtAmt);

        return (retVal, abi.encode(_params));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }

    /// @dev Helper function to handle supply action
    /// @param _params Params struct passed to the action
    /// @param _supplyToken Address of the supply token
    /// @return supplyTokenAmount Amount of supply token to be supplied to Fluid T1 Vault
    /// @return msgValue Amount of ETH to be sent to the vault (if supply token is ETH)
    function _handleSupply(
        Params memory _params,
        address _supplyToken
    ) internal returns (int256 supplyTokenAmount, uint256 msgValue) {
        if (_params.collAmount == 0) return (0, 0);

        if (_supplyToken == TokenUtils.ETH_ADDR) {
            _params.collAmount = TokenUtils.WETH_ADDR.pullTokensIfNeeded(_params.from, _params.collAmount);
            TokenUtils.withdrawWeth(_params.collAmount);
            msgValue = _params.collAmount;
        } else {
            _params.collAmount = _supplyToken.pullTokensIfNeeded(_params.from, _params.collAmount);
            _supplyToken.approveToken(_params.vault, _params.collAmount);
        }
        
        supplyTokenAmount = _params.collAmount.signed256();
    }

    /// @dev Helper function to handle withdraw action
    /// @param _params Params struct passed to the action
    /// @return supplyTokenAmount Amount of supply token to be withdrawn from Fluid T1 Vault. Supports max withdraw.
    function _handleWithdraw(Params memory _params) internal pure returns (int256 supplyTokenAmount) {
        if (_params.collAmount == 0) return 0;

        supplyTokenAmount = _params.collAmount == type(uint256).max
            ? type(int256).min
            : -_params.collAmount.signed256();
    }

    /// @dev Helper function to handle borrow action
    /// @param _params Params struct passed to the action
    /// @return borrowTokenAmount Amount of borrow token to be borrowed from Fluid T1 Vault
    function _handleBorrow(Params memory _params) internal pure returns (int256 borrowTokenAmount) {
        if (_params.debtAmount == 0) return 0;

        borrowTokenAmount = _params.debtAmount.signed256();
    }

    /// @dev Helper function to handle payback action
    /// @param _params Params struct passed to the action
    /// @param _borrowToken Address of the borrow token
    /// @param _currentMsgValue Calculated msg value from previous actions. Updated only if payback is in ETH
    /// @return snapshot MaxPaybackSnapshot - helper struct that holds information about max payback so we can later refund any remainder
    /// @return msgValue Amount of ETH to be sent to the vault, if payback token is ETH, otherwise it will return _currentMsgValue 
    /// @return borrowTokenAmount Amount of borrow token to be paid back to Fluid T1 Vault
    function _handlePayback(
        Params memory _params,
        address _borrowToken,
        uint256 _currentMsgValue
    ) 
        internal
        returns (
            MaxPaybackSnapshot memory snapshot,
            uint256 msgValue,
            int256 borrowTokenAmount
        )
    {
        // By default, return the current msg value. This will only be changed if payback is in ETH.
        msgValue = _currentMsgValue;

        if (_params.debtAmount == 0) return (snapshot, msgValue, 0);

        (IFluidVaultResolver.UserPosition memory userPosition, ) = 
            IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(_params.nftId);

        if (_params.debtAmount > userPosition.borrow) {
            snapshot.maxPayback = true;
            // See comments in FluidPaybackLiquidityLogic.sol
            _params.debtAmount = userPosition.borrow * 100001 / 100000 + 5;
            snapshot.borrowTokenBalanceBefore = _borrowToken == TokenUtils.ETH_ADDR
                ? address(this).balance
                : _borrowToken.getBalance(address(this));
        }

        if (_borrowToken == TokenUtils.ETH_ADDR) {
            _params.debtAmount = TokenUtils.WETH_ADDR.pullTokensIfNeeded(_params.from, _params.debtAmount);
            TokenUtils.withdrawWeth(_params.debtAmount);
            msgValue = _params.debtAmount;
        } else {
            _params.debtAmount = _borrowToken.pullTokensIfNeeded(_params.from, _params.debtAmount);
            _borrowToken.approveToken(_params.vault, _params.debtAmount);
        }

        borrowTokenAmount = snapshot.maxPayback ? type(int256).min : -_params.debtAmount.signed256();
    }

    /// @dev Helper function to handle max payback refund
    /// @param _params Params struct passed to the action
    /// @param _borrowToken Address of the borrow token
    /// @param _snapshot MaxPaybackSnapshot - helper struct that holds information about max payback
    function _handleMaxPaybackRefund(
        Params memory _params,
        address _borrowToken,
        MaxPaybackSnapshot memory _snapshot
    ) internal {
        uint256 borrowTokenBalanceAfter = _borrowToken == TokenUtils.ETH_ADDR
            ? address(this).balance
            : _borrowToken.getBalance(address(this));

        // Sanity check: if we didn't perform a max payback directly from the wallet,
        // the number of borrowed tokens should not decrease.
        if (_params.from != address(this)) {
            require(borrowTokenBalanceAfter >= _snapshot.borrowTokenBalanceBefore);
        }

        // We pulled slightly more than needed, so refund dust amount to 'from' address.
        if (borrowTokenBalanceAfter > _snapshot.borrowTokenBalanceBefore) {
            uint256 dustAmount = borrowTokenBalanceAfter - _snapshot.borrowTokenBalanceBefore;
            // This also supports plain ETH.
            _borrowToken.withdrawTokens(_params.from, dustAmount);
            // Remove any dust approval left.
            if (_borrowToken != TokenUtils.ETH_ADDR) {
                _borrowToken.approveToken(_params.vault, 0);
            }
        }
    }
}
