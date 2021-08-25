// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "./helpers/CurveHelper.sol";
import "../../utils/TokenUtils.sol";
import "../../utils/SafeMath.sol";
import "../ActionBase.sol";

contract CurveWithdraw is ActionBase, CurveHelper {
    using TokenUtils for address;
    using SafeMath for uint256;

    function _sig(uint256 _nCoins, bool _useUnderlying) internal pure returns(bytes4) {
        if (!_useUnderlying) {
            if (_nCoins == 2) return bytes4(0x5b36389c);
            if (_nCoins == 3) return bytes4(0xecb586a5);
            if (_nCoins == 4) return bytes4(0x7d49d875);
            if (_nCoins == 5) return bytes4(0xe3bff5ce);
            if (_nCoins == 6) return bytes4(0x684916a5);
            if (_nCoins == 7) return bytes4(0x5c912d2b);
            if (_nCoins == 8) return bytes4(0x3fec6549);
            revert("Invalid number of coins in pool.");
        }
        if (_nCoins == 2) return bytes4(0x269b5581);
        if (_nCoins == 3) return bytes4(0xfce64736);
        if (_nCoins == 4) return bytes4(0xa6929895);
        if (_nCoins == 5) return bytes4(0xcbfe789f);
        if (_nCoins == 6) return bytes4(0xfe27e085);
        if (_nCoins == 7) return bytes4(0x78afd240);
        if (_nCoins == 8) return bytes4(0xef930778);
        revert("Invalid number of coins in pool.");
    }

    struct Params {
        address sender;
        address receiver;
        address pool;
        address lpToken;
        uint256 burnAmount;
        uint256[] minAmounts;
        address[] tokens;
        bool useUnderlying;
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
        params.lpToken = _parseParamAddr(params.lpToken, _paramMapping[3], _subData, _returnValues);
        params.burnAmount = _parseParamUint(params.burnAmount, _paramMapping[4], _subData, _returnValues);
        
        uint256 N_COINS = params.minAmounts.length;
        require(N_COINS == params.tokens.length);
        for (uint256 i = 0; i < params.tokens.length; i++) {
            params.minAmounts[i] = _parseParamUint(params.minAmounts[i], _paramMapping[5 + i], _subData, _returnValues);
            params.tokens[i] = _parseParamAddr(params.tokens[i], _paramMapping[5 + N_COINS + i], _subData, _returnValues);
        }

        _curveWithdraw(params);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes[] memory _callData) public payable virtual override {
        Params memory params = parseInputs(_callData);

        _curveWithdraw(params);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    //////////////////////////// ACTION LOGIC ////////////////////////////

    /// @notice Dont forget NatSpec
    function _curveWithdraw(Params memory _params) internal {
        _params.lpToken.pullTokensIfNeeded(_params.sender, _params.burnAmount);
        _params.lpToken.approveToken(_params.pool, _params.burnAmount);
        
        uint256[] memory balances = new uint256[](_params.tokens.length);
        for (uint256 i = 0; i < _params.tokens.length; i++) {
            balances[i] = _params.tokens[i].getBalance(address(this));
        }

        bytes memory payload = _constructPayload(_params.minAmounts, _params.burnAmount, _params.useUnderlying);
        (bool success, ) = _params.pool.call(payload);
        require(success);

        for (uint256 i = 0; i < _params.tokens.length; i++) {
            uint256 balanceDelta = _params.tokens[i].getBalance(address(this)).sub(balances[i]);
            address tokenAddr = _params.tokens[i];
            if (tokenAddr == TokenUtils.ETH_ADDR) {
                TokenUtils.depositWeth(balanceDelta);
                tokenAddr = TokenUtils.WETH_ADDR;
            }
            tokenAddr.withdrawTokens(_params.receiver, balanceDelta);
        }

        logger.Log(
            address(this),
            msg.sender,
            "CurveWithdraw",
            abi.encode(
                _params
            )
        );
    }

    function _constructPayload(uint256[] memory _minAmounts, uint256 _burnAmount, bool _useUnderlying) internal pure returns (bytes memory payload) {
        uint256 payloadSize = 4 + (_minAmounts.length + 1) * 32;
        if (_useUnderlying) payloadSize = payloadSize.add(32);
        payload = new bytes(payloadSize);
        
        bytes4 sig = _sig(_minAmounts.length, _useUnderlying);
        
        assembly {
            mstore(add(payload, 0x20), sig)    // store the signature after dynamic array length field (&callData + 0x20)
            mstore(add(payload, 0x24), _burnAmount)    // copy the first arg after the selector (0x20 + 0x4 bytes)

            let offset := 0x20  // offset of the first element in '_minAmounts'
            for { let i := 0 } lt(i, mload(_minAmounts)) { i := add(i, 1) } {
                mstore(add(payload, add(0x24, offset)), mload(add(_minAmounts, offset)))   // payload offset needs to account for 0x4 bytes of selector and 0x20 bytes for _burnAmount arg
                offset := add(offset, 0x20) // offset for next copy
            }

            if eq(_useUnderlying, true) { mstore(add(payload, add(0x24, offset)), true) }
        }
    }
    function parseInputs(bytes[] memory _callData) internal pure returns (Params memory params) {
        params = abi.decode(_callData[0], (Params));
    }
}