// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import "../../../utils/TokenUtils.sol";
import "../../ActionBase.sol";
import "../helpers/LlamaLendHelper.sol";
import "./LlamaLendSwapper.sol";
import "../../../interfaces/IBytesTransientStorage.sol";
import "../../../exchangeV3/DFSExchangeData.sol";

/// @title LlamaLendLevCreate 
contract LlamaLendLevCreate is ActionBase, LlamaLendHelper {
    using TokenUtils for address;

    /// @param controllerAddress Address of the llamalend market controller
    /// @param from address from which collAmount of collToken will be pulled
    /// @param collAmount amount of collateral that the user is providing at first
    /// @param nBands number of bands the created position will have
    /// @param exData exchange data for swapping (srcAmount will be amount of debt token generated and sold)
    /// @param gasUsed info for automated strategy gas reimbursement
    struct Params {
        address controllerAddress;
        address from;
        uint256 collAmount;
        uint256 nBands;
        DFSExchangeData.ExchangeData exData;
        uint32 gasUsed;
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
        params.from = _parseParamAddr(params.from, _paramMapping[1], _subData, _returnValues);
        params.collAmount = _parseParamUint(params.collAmount, _paramMapping[2], _subData, _returnValues);
        params.nBands = _parseParamUint(params.nBands, _paramMapping[3], _subData, _returnValues);

        (uint256 debtGeneratedAndSold, bytes memory logData) = _create(params);
        emit ActionEvent("LlamaLendLevCreate", logData);
        return bytes32(debtGeneratedAndSold);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable virtual override {
        Params memory params = parseInputs(_callData);

        (, bytes memory logData) = _create(params);
        logger.logActionDirectEvent("LlamaLendLevCreate", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    //////////////////////////// ACTION LOGIC ////////////////////////////

    function _create(Params memory _params) internal returns (uint256, bytes memory) {
        /// @dev see ICrvUsdController natspec
        if (_params.collAmount == 0 || _params.exData.srcAmount == 0) revert();

        address collAddr = ILlamaLendController(_params.controllerAddress).collateral_token();
        _params.collAmount = collAddr.pullTokensIfNeeded(_params.from, _params.collAmount);

        address llamalendSwapper = registry.getAddr(LLAMALEND_SWAPPER_ID);
        uint256[] memory info = new uint256[](5);
        info[0] = _params.gasUsed;

        transientStorage.setBytesTransiently(abi.encode(_params.exData));


        collAddr.approveToken(_params.controllerAddress, _params.collAmount);
        // create loan
        ILlamaLendController(_params.controllerAddress).create_loan_extended(
            _params.collAmount,
            _params.exData.srcAmount,
            _params.nBands,
            llamalendSwapper,
            info
        );

        return (
            _params.exData.srcAmount,
            abi.encode(_params)
        );
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}