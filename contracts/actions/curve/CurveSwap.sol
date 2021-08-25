// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "./helpers/CurveHelper.sol";
import "../../utils/TokenUtils.sol";
import "../ActionBase.sol";

contract CurveSwap is ActionBase, CurveHelper {
    using TokenUtils for address;

    struct Params {
        address sender;
        address receiver;
        address pool;
        address from;
        address to;
        uint256 amount;
        uint256 expected;
    }

    function executeAction(
        bytes[] memory _callData,
        bytes[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);
        params.sender = _parseParamAddr(params.sender, _paramMapping[0], _subData, _returnValues);
        params.receiver = _parseParamAddr(params.receiver, _paramMapping[1], _subData, _returnValues);
        params.pool = _parseParamAddr(params.pool, _paramMapping[2], _subData, _returnValues);
        params.from = _parseParamAddr(params.from, _paramMapping[3], _subData, _returnValues);
        params.to = _parseParamAddr(params.to, _paramMapping[4], _subData, _returnValues);
        params.amount = _parseParamUint(params.amount, _paramMapping[5], _subData, _returnValues);
        params.expected = _parseParamUint(params.expected, _paramMapping[6], _subData, _returnValues);
        

        uint256 received = _curveSwap(params);
        return bytes32(received);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes[] memory _callData) public payable virtual override {
        Params memory params = parseInputs(_callData);

        _curveSwap(params);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    //////////////////////////// ACTION LOGIC ////////////////////////////

    /// @notice Dont forget NatSpec
    function _curveSwap(Params memory _params) internal returns (uint256) {
        if (_params.amount == type(uint256).max) {
            _params.amount = _params.from.getBalance(_params.sender);
        }
        uint256 msgValue;
        if (_params.from == TokenUtils.ETH_ADDR) {
            TokenUtils.WETH_ADDR.pullTokensIfNeeded(_params.sender, _params.amount);
            TokenUtils.withdrawWeth(_params.amount);
            msgValue = _params.amount;
        }
        else {
            _params.from.pullTokensIfNeeded(_params.sender, _params.amount);
            _params.from.approveToken(address(getSwaps()), _params.amount);
        }
        
        uint256 received = getSwaps().exchange{ value: msgValue }(
            _params.pool,
            _params.from,
            _params.to,
            _params.amount,
            _params.expected,
            _params.receiver
        );

        logger.Log(
            address(this),
            msg.sender,
            "CurveSwap",
            abi.encode(
                _params,
                received
            )
        );

        return received;
    }

    function parseInputs(bytes[] memory _callData) internal pure returns (Params memory params) {
        params = abi.decode(_callData[0], (Params));
    }
}