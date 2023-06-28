// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import "../../utils/TokenUtils.sol";
import "../ActionBase.sol";
import "./helpers/CurveUsdHelper.sol";

/// @title CurveUsdSelfLiquidate Closes the users position while he's in soft liquidation
contract CurveUsdSelfLiquidate is ActionBase, CurveUsdHelper {
    using TokenUtils for address;

    /// @param controllerAddress Address of the curveusd market controller
    /// @param minCrvUsdExpected Minimum amount of crvUsd as collateral for the user to have
    /// @param from Address from which to pull crvUSD if needed
    /// @param to Address that will receive the crvUSD and collateral asset
    struct Params {
        address controllerAddress;
        uint256 minCrvUsdExpected;
        address from;
        address to;
    }

    /// @inheritdoc ActionBase
    function executeAction(
        bytes memory _callData,
        bytes32[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        params.controllerAddress = _parseParamAddr(params.controllerAddress, _paramMapping[0], _subData, _returnValues);
        params.minCrvUsdExpected = _parseParamUint(params.minCrvUsdExpected, _paramMapping[1], _subData, _returnValues);
        params.from = _parseParamAddr(params.from, _paramMapping[2], _subData, _returnValues);
        params.to = _parseParamAddr(params.to, _paramMapping[3], _subData, _returnValues);

        ///@dev returning amount of crvUSD pulled because it's not known precisely before the execution and can be used with Sub/Sum Inputs Actions later
        (uint256 amountPulled, bytes memory logData) = _curveUsdSelfLiquidate(params);
        emit ActionEvent("CurveUsdSelfLiquidate", logData);
        return bytes32(amountPulled);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable virtual override {
        Params memory params = parseInputs(_callData);

        (, bytes memory logData) = _curveUsdSelfLiquidate(params);
        logger.logActionDirectEvent("CurveUsdSelfLiquidate", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    //////////////////////////// ACTION LOGIC ////////////////////////////

    function _curveUsdSelfLiquidate(Params memory _params) internal returns (uint256, bytes memory) {      
        if (!isControllerValid(_params.controllerAddress)) revert CurveUsdInvalidController();

        uint256 userWholeDebt = ICrvUsdController(_params.controllerAddress).debt(address(this));
        (uint256 collInCrvUsd, uint256 collInDepositAsset) = getCollAmountsFromAMM(_params.controllerAddress, address(this));

        uint256 amountToPull;

        
        if (collInCrvUsd < userWholeDebt) {
            // if we don't have enough crvUsd in coll, pull the rest from the user
            amountToPull = userWholeDebt - collInCrvUsd;
            amountToPull = CRVUSD_TOKEN_ADDR.pullTokensIfNeeded(_params.from, amountToPull);
            CRVUSD_TOKEN_ADDR.approveToken(_params.controllerAddress, amountToPull);
        }

        address collateralAsset = ICrvUsdController(_params.controllerAddress).collateral_token();

        if (collateralAsset != TokenUtils.WETH_ADDR){
            ICrvUsdController(_params.controllerAddress).liquidate(address(this), _params.minCrvUsdExpected);
        } else {
            ICrvUsdController(_params.controllerAddress).liquidate(address(this), _params.minCrvUsdExpected, false);
        }

        collateralAsset.withdrawTokens(_params.to, collInDepositAsset);

        // send leftover crvUsd to user
        if (collInCrvUsd > userWholeDebt) {
            CRVUSD_TOKEN_ADDR.withdrawTokens(_params.to, (collInCrvUsd - userWholeDebt));
        }

        return (
            amountToPull,
            abi.encode(_params, collInCrvUsd, collInDepositAsset, userWholeDebt)
        );
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}