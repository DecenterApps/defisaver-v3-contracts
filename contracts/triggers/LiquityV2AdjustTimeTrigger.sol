// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import {AdminAuth} from "../auth/AdminAuth.sol";
import {ITrigger} from "../interfaces/ITrigger.sol";
import {TriggerHelper} from "./helpers/TriggerHelper.sol";
import {IAddressesRegistry} from "../interfaces/liquityV2/IAddressesRegistry.sol";
import {ITroveManager} from "../interfaces/liquityV2/ITroveManager.sol";
import {IBorrowerOperations} from "../interfaces/liquityV2/IBorrowerOperations.sol";

/// @title Trigger contract that verifies if current LiquityV2 position adjust time has passed.
/// @dev If the trove has an interest batch manager, the trigger will not be triggered.
/// @dev If the trove is not active, the trigger will not be triggered.
/// @dev Adjust time is 7 days.
contract LiquityV2AdjustTimeTrigger is ITrigger, AdminAuth, TriggerHelper {
    uint256  constant INTEREST_RATE_ADJ_COOLDOWN = 7 days;

    /// @param market address of the market where the trove is
    /// @param troveId id of the trove
    struct SubParams {
        address market;
        uint256 troveId;
    }

    /// @dev checks if the adjust time has passed
    function isTriggered(bytes memory, bytes memory _subData) public override returns (bool) {
        SubParams memory triggerSubData = parseSubInputs(_subData);

        return isAdjustmentFeeZero(triggerSubData.market, triggerSubData.troveId);
    }

    function isAdjustmentFeeZero(address _market, uint256 _troveId) public view returns (bool) {
        IAddressesRegistry market = IAddressesRegistry(_market);
        ITroveManager troveManager = ITroveManager(market.troveManager());
        IBorrowerOperations borrowerOperations = IBorrowerOperations(market.borrowerOperations());
        ITroveManager.LatestTroveData memory troveData = troveManager.getLatestTroveData(_troveId);

        // return false if trove has an interest batch manager
        if (borrowerOperations.interestBatchManagerOf(_troveId) != address(0)) {
            return false;
        }

        if (troveManager.getTroveStatus(_troveId) != ITroveManager.Status.active) {
            return false;
        }

        uint256 currentTime = block.timestamp;
        return currentTime >= troveData.lastInterestRateAdjTime + INTEREST_RATE_ADJ_COOLDOWN;
    }

    function parseSubInputs(bytes memory _subData) public pure returns (SubParams memory params) {
        params = abi.decode(_subData, (SubParams));
    }

    function changedSubData(bytes memory _subData) public pure override returns (bytes memory) {}

    function isChangeable() public pure override returns (bool) {
        return false;
    }
}
