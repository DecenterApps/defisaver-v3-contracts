// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import {AdminAuth} from "../auth/AdminAuth.sol";
import {ITrigger} from "../interfaces/ITrigger.sol";
import {TriggerHelper} from "./helpers/TriggerHelper.sol";
import {IAddressesRegistry} from "../interfaces/liquityV2/IAddressesRegistry.sol";
import {ITroveManager} from "../interfaces/liquityV2/ITroveManager.sol";
import {IBorrowerOperations} from "../interfaces/liquityV2/IBorrowerOperations.sol";
import {ISortedTroves} from "../interfaces/liquityV2/ISortedTroves.sol";
import {IStabilityPool} from "../interfaces/liquityV2/IStabilityPool.sol";

// TODO update comment
/// @title Trigger contract that calculates the debt in front of a trove taking all the branches into account
contract LiquityV2DebtInFrontTrigger is ITrigger, AdminAuth, TriggerHelper {
    address internal constant ETH_MARKET = 0x38e1F07b954cFaB7239D7acab49997FBaAD96476;
    address internal constant WST_ETH_MARKET = 0x2D4ef56cb626E9a4C90c156018BA9CE269573c61;
    address internal constant RETH_MARKET = 0x3b48169809DD827F22C9e0F2d71ff12Ea7A94a2F;

    /// @param market address of the market where the trove is
    /// @param troveId id of the trove
    struct SubParams {
        address market;
        uint256 troveId;
        uint256 debtInFrontMin;
    }

    /// @dev checks if the adjust time has passed
    function isTriggered(bytes memory, bytes memory _subData) public override returns (bool) {
        SubParams memory triggerSubData = parseSubInputs(_subData);

        uint256 debtInFront = getDebtInFront(triggerSubData.market, triggerSubData.troveId);

        return debtInFront >= triggerSubData.debtInFrontMin;
    }

    function getDebtInFront(address _market, uint256 _trove) public view returns (uint256) {
        (uint256 ethTotalDebt, uint256 ethUnbackedBold) = getUnbackedDebt(ETH_MARKET);
        (uint256 wstEthTotalDebt, uint256 wstEthUnbackedBold) = getUnbackedDebt(WST_ETH_MARKET);
        (uint256 rEthTotalDebt, uint256 rEthUnbackedBold) = getUnbackedDebt(RETH_MARKET);

        uint256 totalUnbackedDebt = ethUnbackedBold + wstEthUnbackedBold + rEthUnbackedBold;

        uint256 branchDebtInFront = getDebtInFrontOnTrovesBranch(_market, _trove, 0, 1000);

        uint256 totalDebtInFront = branchDebtInFront;
        if (_market == ETH_MARKET) {
            totalDebtInFront += getRedeemAmount(
                wstEthTotalDebt,
                branchDebtInFront,
                wstEthUnbackedBold,
                ethUnbackedBold
            );
            totalDebtInFront += getRedeemAmount(
                rEthTotalDebt,
                branchDebtInFront,
                rEthUnbackedBold,
                ethUnbackedBold
            );
        } else if (_market == WST_ETH_MARKET) {
            totalDebtInFront += getRedeemAmount(
                ethTotalDebt,
                branchDebtInFront,
                ethUnbackedBold,
                wstEthUnbackedBold
            );
            totalDebtInFront += getRedeemAmount(
                rEthTotalDebt,
                branchDebtInFront,
                rEthUnbackedBold,
                wstEthUnbackedBold
            );
        } else if (_market == RETH_MARKET) {
            totalDebtInFront += getRedeemAmount(
                ethTotalDebt,
                branchDebtInFront,
                ethUnbackedBold,
                rEthUnbackedBold
            );
            totalDebtInFront += getRedeemAmount(
                wstEthTotalDebt,
                branchDebtInFront,
                wstEthUnbackedBold,
                rEthUnbackedBold
            );
        } else {
            // TODO return 0 or revert?
            return 0;
        }

        return totalDebtInFront;
    }

    function getDebtInFrontOnTrovesBranch(
        address _market,
        uint256 _troveId,
        uint256 _acc,
        uint256 _iterations
    ) public view returns (uint256 debt) {
        ITroveManager troveManager = ITroveManager(IAddressesRegistry(_market).troveManager());
        ISortedTroves sortedTroves = ISortedTroves(IAddressesRegistry(_market).sortedTroves());

        uint256 next = _troveId;
        debt = _acc;
        for (uint256 i = 0; i < _iterations; ++i) {
            next = sortedTroves.getNext(next);
            if (next == 0) return debt;
            debt += _getDebtInFrontOnTrovesBranch(troveManager, next);
        }
    }

    function getRedeemAmount(
        uint256 totalBorrowOnBranch,
        uint256 debtInFrontOnBranch,
        uint256 unbackedBoldOnBranch,
        uint256 selectedMarketUnbackedData
    ) public pure returns (uint256) {
        uint256 totalDebtInFront = (debtInFrontOnBranch * unbackedBoldOnBranch) /
            selectedMarketUnbackedData;
        if (totalBorrowOnBranch < totalDebtInFront) {
            return totalBorrowOnBranch;
        } else {
            return totalDebtInFront;
        }
    }

    function parseSubInputs(bytes memory _subData) public pure returns (SubParams memory params) {
        params = abi.decode(_subData, (SubParams));
    }

    function changedSubData(bytes memory _subData) public pure override returns (bytes memory) {}

    function isChangeable() public pure override returns (bool) {
        return false;
    }

    function getUnbackedDebt(
        address _market
    ) internal view returns (uint256 systemDebt, uint256 unbackedBold) {
        IAddressesRegistry registry = IAddressesRegistry(_market);
        systemDebt = IBorrowerOperations(registry.borrowerOperations()).getEntireSystemDebt();
        uint256 boldDeposits = IStabilityPool(registry.stabilityPool()).getTotalBoldDeposits();
        unbackedBold = systemDebt - boldDeposits;
    }

    function _getDebtInFrontOnTrovesBranch(
        ITroveManager _troveManager,
        uint256 _troveId
    ) internal view returns (uint256 debt) {
        ITroveManager.LatestTroveData memory latestTroveData = _troveManager.getLatestTroveData(
            _troveId
        );
        debt = latestTroveData.entireDebt;
    }
}
