// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import { ActionBase } from "../../contracts/actions/ActionBase.sol";
import { CompV3Supply } from "../../contracts/actions/compoundV3/CompV3Supply.sol";
import { CompV3Withdraw } from "../../contracts/actions/compoundV3/CompV3Withdraw.sol";
import { CompV3Payback } from "../../contracts/actions/compoundV3/CompV3Payback.sol";
import { CompV3Borrow } from "../../contracts/actions/compoundV3/CompV3Borrow.sol";
import { DFSSell } from "../../contracts/actions/exchange/DFSSell.sol";
import { DFSExchangeData } from "../../contracts/exchangeV3/DFSExchangeData.sol";
import { GasFeeTaker } from "../../contracts/actions/fee/GasFeeTaker.sol";
import { CompV3RatioCheck } from "../../contracts/actions/checkers/CompV3RatioCheck.sol";
import { IFlashLoanBase } from "../../contracts/interfaces/flashloan/IFlashLoanBase.sol";
import { AaveV3Supply } from "../../contracts/actions/aaveV3/AaveV3Supply.sol";
import { AaveV3Borrow } from "../../contracts/actions/aaveV3/AaveV3Borrow.sol";
import { AaveV3Withdraw } from "../../contracts/actions/aaveV3/AaveV3Withdraw.sol";
import { AaveV3SetEMode } from "../../contracts/actions/aaveV3/AaveV3SetEMode.sol";
import { AaveV3DelegateCredit } from "../../contracts/actions/aaveV3/AaveV3DelegateCredit.sol";
import { AaveV3CollateralSwitch } from "../../contracts/actions/aaveV3/AaveV3CollateralSwitch.sol";
import { AaveV3ClaimRewards } from "../../contracts/actions/aaveV3/AaveV3ClaimRewards.sol";
import { AaveV3Payback } from "../../contracts/actions/aaveV3/AaveV3Payback.sol";
import { AaveV3ATokenPayback } from "../../contracts/actions/aaveV3/AaveV3ATokenPayback.sol";
import { SumInputs } from "../../contracts/actions/utils/SumInputs.sol";
import { PullToken } from "../../contracts/actions/utils/PullToken.sol";
import { SendToken } from "../../contracts/actions/utils/SendToken.sol";
import { LiquityV2Open } from "../../contracts/actions/liquityV2/trove/LiquityV2Open.sol";
import { LiquityV2Close } from "../../contracts/actions/liquityV2/trove/LiquityV2Close.sol";
import { LiquityV2Supply } from "../../contracts/actions/liquityV2/trove/LiquityV2Supply.sol";
import { LiquityV2Withdraw } from "../../contracts/actions/liquityV2/trove/LiquityV2Withdraw.sol";
import { LiquityV2Borrow } from "../../contracts/actions/liquityV2/trove/LiquityV2Borrow.sol";
import { LiquityV2Payback } from "../../contracts/actions/liquityV2/trove/LiquityV2Payback.sol";
import { LiquityV2Claim } from "../../contracts/actions/liquityV2/trove/LiquityV2Claim.sol";
import { LiquityV2Adjust } from "../../contracts/actions/liquityV2/trove/LiquityV2Adjust.sol";
import { LiquityV2AdjustZombieTrove } from "../../contracts/actions/liquityV2/trove/LiquityV2AdjustZombieTrove.sol";
import { LiquityV2AdjustInterestRate } from "../../contracts/actions/liquityV2/trove/LiquityV2AdjustInterestRate.sol";
import { LiquityV2SPDeposit } from "../../contracts/actions/liquityV2/stabilityPool/LiquityV2SPDeposit.sol";
import { LiquityV2SPWithdraw } from "../../contracts/actions/liquityV2/stabilityPool/LiquityV2SPWithdraw.sol";
import { LiquityV2SPClaimColl } from "../../contracts/actions/liquityV2/stabilityPool/LiquityV2SPClaimColl.sol";
import { EulerV2Supply } from "../../contracts/actions/eulerV2/EulerV2Supply.sol";
import { EulerV2Withdraw } from "../../contracts/actions/eulerV2/EulerV2Withdraw.sol";
import { EulerV2Borrow } from "../../contracts/actions/eulerV2/EulerV2Borrow.sol";
import { EulerV2Payback } from "../../contracts/actions/eulerV2/EulerV2Payback.sol";
import { EulerV2CollateralSwitch } from "../../contracts/actions/eulerV2/EulerV2CollateralSwitch.sol";
import { EulerV2ReorderCollaterals } from "../../contracts/actions/eulerV2/EulerV2ReorderCollaterals.sol";
import { EulerV2PaybackWithShares } from "../../contracts/actions/eulerV2/EulerV2PaybackWithShares.sol";
import { EulerV2PullDebt } from "../../contracts/actions/eulerV2/EulerV2PullDebt.sol";
import { AaveV3RatioCheck } from "../../contracts/actions/checkers/AaveV3RatioCheck.sol";
import { SendTokensAndUnwrap } from "../../contracts/actions/utils/SendTokensAndUnwrap.sol";
import { RenzoStake } from "../../contracts/actions/renzo/RenzoStake.sol";
import { EtherFiStake } from "../../contracts/actions/etherfi/EtherFiStake.sol";
import { EtherFiWrap } from "../../contracts/actions/etherfi/EtherFiWrap.sol";
import { EtherFiUnwrap } from "../../contracts/actions/etherfi/EtherFiUnwrap.sol";
import { MorphoTokenWrap } from "../../contracts/actions/morpho-blue/MorphoTokenWrap.sol";
import { FluidVaultT1Open } from "../../contracts/actions/fluid/vaultT1/FluidVaultT1Open.sol";
import { FluidVaultT1Supply } from "../../contracts/actions/fluid/vaultT1/FluidVaultT1Supply.sol";
import { FluidVaultT1Withdraw } from "../../contracts/actions/fluid/vaultT1/FluidVaultT1Withdraw.sol";
import { FluidVaultT1Borrow } from "../../contracts/actions/fluid/vaultT1/FluidVaultT1Borrow.sol";
import { FluidVaultT1Payback } from "../../contracts/actions/fluid/vaultT1/FluidVaultT1Payback.sol";
import { FluidVaultT1Adjust } from "../../contracts/actions/fluid/vaultT1/FluidVaultT1Adjust.sol";

contract ActionsUtils {

    bytes32[] internal subData = new bytes32[](0);
    uint8[]  internal paramMapping = new uint8[](15);
    bytes32[] internal returnValues = new bytes32[](0);

    enum FLSource {
        EMPTY,
        AAVEV2,
        BALANCER,
        GHO,
        MAKER,
        AAVEV3,
        UNIV3,
        SPARK,
        MORPHO_BLUE
    }

    function executeActionCalldata(bytes memory _paramsCalldata, bool _isDirect) public view returns (bytes memory callData) {
        if (_isDirect) {
            callData = abi.encodeWithSelector(
                ActionBase.executeActionDirect.selector,
                _paramsCalldata
            );
        } else {
            callData = abi.encodeWithSelector(
                ActionBase.executeAction.selector,
                _paramsCalldata,
                subData,
                paramMapping,
                returnValues
            );
        }
    }

    function compV3SupplyEncode(
        address _market,
        address _tokenAddr,
        uint256 _amount,
        address _from
    ) public pure returns (bytes memory) {
        CompV3Supply.Params memory params = CompV3Supply.Params({
            market: _market,
            tokenAddr: _tokenAddr,
            amount: _amount,
            from: _from,
            onBehalf: address(0)
        });

        return abi.encode(params);
    }

    function compV3WithdrawEncode(
        address _market,
        address _to,
        address _tokenAddr,
        uint256 _amount
    ) public pure returns (bytes memory) {
        CompV3Withdraw.Params memory params = CompV3Withdraw.Params({
            market: _market,
            to: _to,
            asset: _tokenAddr,
            amount: _amount,
            onBehalf: address(0)
        });

        return abi.encode(params);
    }

    function compV3BorrowEncode(
        address _market,
        uint _amount,
        address _to
    ) public pure returns (bytes memory) {
        CompV3Borrow.Params memory params = CompV3Borrow.Params({
            market: _market,
            amount: _amount,
            to: _to,
            onBehalf: address(0)
        });

        return abi.encode(params);
    }

    function compV3PaybackEncode(
        address _market,
        address _from,
        uint256 _amount
    ) public pure returns (bytes memory) {
        CompV3Payback.Params memory params = CompV3Payback.Params({
            market: _market,
            amount: _amount,
            from: _from,
            onBehalf: address(0)
        });

        return abi.encode(params);
    }

    function sellEncode(
        address _srcAddr,
        address _destAddr,
        uint256 _srcAmount,
        address _from,
        address _to,
        address _wrapper
    ) public view returns (bytes memory) {
        DFSExchangeData.OffchainData memory offchain;

        address[] memory path = new address[](2);
        path[0] = _srcAddr;
        path[1] = _destAddr;
        bytes memory wrapperData = abi.encode(path);

        DFSExchangeData.ExchangeData memory sellParams = DFSExchangeData.ExchangeData({
            srcAddr: _srcAddr,
            destAddr: _destAddr,
            srcAmount: _srcAmount,
            destAmount: 0,
            minPrice: 0,
            dfsFeeDivider: 0,
            user: msg.sender,
            wrapper: _wrapper,
            wrapperData: wrapperData,
            offchainData: offchain
        });

        DFSSell.Params memory params = DFSSell.Params({
            exchangeData: sellParams,
            from: _from,
            to: _to
        });

        return abi.encode(params);
    }

    function gasFeeEncode(uint256 _gasUsed, address _feeToken) public pure returns (bytes memory) {
        GasFeeTaker.GasFeeTakerParams memory params = GasFeeTaker.GasFeeTakerParams({
            gasUsed: _gasUsed,
            feeToken: _feeToken,
            availableAmount: 0,
            dfsFeeDivider: 0
        });

        return abi.encode(params);
    }

    function compV3RatioCheckEncode(uint8 _state, uint _targetRatio, address _market) public pure returns (bytes memory) {
        CompV3RatioCheck.Params memory params = CompV3RatioCheck.Params({
            ratioState: CompV3RatioCheck.RatioState(_state),
            targetRatio: _targetRatio,
            market: _market,
            user: address(0)
        });

        return abi.encode(params);
    }

    function flActionEncode(
        address _tokenAddr,
        uint256 _amount,
        FLSource _flSource
    ) public pure returns (bytes memory) {
        address[] memory tokens = new address[](1);
        tokens[0] = _tokenAddr;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        uint256[] memory modes = new uint256[](0);

        /// @dev modes are used for aave and spark
        if (_flSource == FLSource.AAVEV2 || _flSource == FLSource.AAVEV3 || _flSource == FLSource.SPARK) {
            modes = new uint256[](1);
            modes[0] = 0;
        }

        /// @dev gho uses hardcoded gho token and maker uses hardcoded dai so we don't need to pass tokens
        if (_flSource == FLSource.GHO || _flSource == FLSource.MAKER) {
            tokens = new address[](0);
        }

        IFlashLoanBase.FlashLoanParams memory params = IFlashLoanBase.FlashLoanParams({
            tokens: tokens,
            amounts: amounts,
            modes: modes,
            onBehalfOf: address(0),
            flParamGetterAddr: address(0),
            flParamGetterData: abi.encodePacked(uint8(_flSource)),
            recipeData: ""
        });

        return abi.encode(params);
    }

    function flUniswapEncode(
        address _token0,
        address _token1,
        address _pool,
        uint256 _amount0,
        uint256 _amount1
    ) public pure returns (bytes memory) {
        address[] memory tokens = new address[](3);
        tokens[0] = _token0;
        tokens[1] = _token1;
        tokens[2] = _pool;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _amount0;
        amounts[1] = _amount1;

        IFlashLoanBase.FlashLoanParams memory params = IFlashLoanBase.FlashLoanParams({
            tokens: tokens,
            amounts: amounts,
            modes: new uint256[](0),
            onBehalfOf: address(0),
            flParamGetterAddr: address(0),
            flParamGetterData: abi.encodePacked(uint8(FLSource.UNIV3)),
            recipeData: ""
        });

        return abi.encode(params);
    }

    function aaveV3SupplyEncode(
        uint256 _amount,
        address _from,
        uint16 _assetId,
        bool _useDefaultMarket,
        bool _useOnBehalfOf,
        address _market,
        address _onBehalf
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3Supply.Params({
                amount: _amount,
                from: _from,
                assetId: _assetId,
                enableAsColl: true,
                useDefaultMarket: _useDefaultMarket,
                useOnBehalf: _useOnBehalfOf,
                market: _market,
                onBehalf: _onBehalf
            })
        );
    }

    function aaveV3BorrowEncode(
        uint256 _amount,
        address _to,
        uint8 _rateMode,
        uint16 _assetId,
        bool _useDefaultMarket,
        bool _useOnBehalf,
        address _market,
        address _onBehalf
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3Borrow.Params({
                amount: _amount,
                to: _to,
                rateMode: _rateMode,
                assetId: _assetId,
                useDefaultMarket: _useDefaultMarket,
                useOnBehalf: _useOnBehalf,
                market: _market,
                onBehalf: _onBehalf
            })
        );
    }

    function aaveV3WithdrawEncode(
        uint16 _assetId,
        bool _useDefaultMarket,
        uint256 _amount,
        address _to,
        address _market
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3Withdraw.Params({
                assetId: _assetId,
                useDefaultMarket: _useDefaultMarket,
                amount: _amount,
                to: _to,
                market: _market
            })
        );
    }

    function aaveV3SetEModeEncode(
        uint8 _categoryId,
        bool _useDefaultMarket,
        address _market
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3SetEMode.Params({
                categoryId: _categoryId,
                useDefaultMarket: _useDefaultMarket,
                market: _market
            })
        );
    }

    function aaveV3DelegateCreditEncode(
        uint256 _amount,
        address _delegatee,
        uint16 _assetId,
        uint8 _rateMode,
        bool _useDefaultMarket,
        address _market
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3DelegateCredit.Params({
                amount: _amount,
                delegatee: _delegatee,
                assetId: _assetId,
                rateMode: _rateMode,
                useDefaultMarket: _useDefaultMarket,
                market: _market
            })
        );
    }

    function aaveV3CollateralSwitchEncode(
        uint8 _arrayLength,
        uint16[] memory _assetIds,
        bool[] memory _useAsCollateral,
        bool _useDefaultMarket,
        address _market
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3CollateralSwitch.Params({
                arrayLength: _arrayLength,
                assetIds: _assetIds,
                useAsCollateral: _useAsCollateral,
                useDefaultMarket: _useDefaultMarket,
                market: _market
            })
        );
    }

    function aaveV3ClaimRewardsEncode(
        uint256 _amount,
        address _to,
        address _reward,
        address[] memory _assets
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3ClaimRewards.Params({
                amount: _amount,
                to: _to,
                reward: _reward,
                assetsLength: uint8(_assets.length),
                assets: _assets
            })
        );
    }

    function aaveV3PaybackEncode(
        uint256 _amount,
        address _from,
        uint8 _rateMode,
        uint16 _assetId,
        bool _useDefaultMarket,
        bool _useOnBehalf,
        address _market,
        address _onBehalf
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3Payback.Params({
                amount: _amount,
                from: _from,
                rateMode: _rateMode,
                assetId: _assetId,
                useDefaultMarket: _useDefaultMarket,
                useOnBehalf: _useOnBehalf,
                market: _market,
                onBehalf: _onBehalf
            })
        );
    }

    function aaveV3ATokenPaybackEncode(
        uint256 _amount,
        address _from,
        uint8 _rateMode,
        uint16 _assetId,
        bool _useDefaultMarket,
        address _market
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            AaveV3ATokenPayback.Params({
                amount: _amount,
                from: _from,
                rateMode: _rateMode,
                assetId: _assetId,
                useDefaultMarket: _useDefaultMarket,
                market: _market
            })
        );
    }

    function aaveV3RatioCheckEncode(uint8 _state, uint _targetRatio) public pure returns (bytes memory) {
        AaveV3RatioCheck.Params memory params = AaveV3RatioCheck.Params({
            ratioState: AaveV3RatioCheck.RatioState(_state),
            targetRatio: _targetRatio
        });

        return abi.encode(params);
    }

    function sumInputsEncode(
        uint256 _a,
        uint256 _b
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            SumInputs.Params({
                a: _a,
                b: _b
            })
        );
    }

    function pullTokenEncode(
        address _tokenAddr,
        address _from,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            PullToken.Params({
                tokenAddr: _tokenAddr,
                from: _from,
                amount: _amount
            })
        );
    }

    function sendTokenEncode(
        address _tokeAddr,
        address _to,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            SendToken.Params({
                tokenAddr: _tokeAddr,
                to: _to,
                amount: _amount
            })
        );
    }

    function eulerV2SupplyEncode(
        address _vault,
        address _account,
        address _from,
        uint256 _amount,
        bool _enableAsColl
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2Supply.Params({
                vault: _vault,
                account: _account,
                from: _from,
                amount: _amount,
                enableAsColl: _enableAsColl
            })
        );
    }

    function eulerV2WithdrawEncode(
        address _vault,
        address _account,
        address _receiver,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2Withdraw.Params({
                vault: _vault,
                account: _account,
                receiver: _receiver,
                amount: _amount
            })
        );
    }

    function eulerV2PaybackEncode(
        address _vault,
        address _account,
        address _from,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2Payback.Params({
                vault: _vault,
                account: _account,
                from: _from,
                amount: _amount
            })
        );
    }

    function eulerV2BorrowEncode(
        address _vault,
        address _account,
        address _receiver,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2Borrow.Params({
                vault: _vault,
                account: _account,
                receiver: _receiver,
                amount: _amount
            })
        );
    }

    function eulerV2CollateralSwitchEncode(
        address _vault,
        address _account,
        bool _enableAsColl
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2CollateralSwitch.Params({
                vault: _vault,
                account: _account,
                enableAsColl: _enableAsColl
            })
        );
    }

    function eulerV2ReorderCollaterals(
        address _account,
        uint8[][] memory _indexes
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2ReorderCollaterals.Params({
                account: _account,
                indexes: _indexes
            })
        );
    }

    function eulerV2PaybackWithSharesEncode(
        address _vault,
        address _from,
        address _account,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2PaybackWithShares.Params({
                vault: _vault,
                from: _from,
                account: _account,
                amount: _amount
            })
        );
    }

    function eulerV2PullDebtEncode(
        address _vault,
        address _account,
        address _from,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EulerV2PullDebt.Params({
                vault: _vault,
                account: _account,
                from: _from,
                amount: _amount
            })
        );
    }

    function renzoStakeEncode(
        uint256 _amount,
        address _from,
        address _to
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            RenzoStake.Params({
                amount: _amount,
                from: _from,
                to: _to
            })
        );
    }

    function etherFiStakeEncode(
        uint256 _amount,
        address _from,
        address _to,
        bool _shouldWrap
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EtherFiStake.Params({
                amount: _amount,
                from: _from,
                to: _to,
                shouldWrap: _shouldWrap
            })
        );
    }

    function etherFiWrapEncode(
        uint256 _amount,
        address _from,
        address _to
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EtherFiWrap.Params({
                amount: _amount,
                from: _from,
                to: _to
            })
        );
    }

    function etherFiUnwrapEncode(
        uint256 _amount,
        address _from,
        address _to
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            EtherFiUnwrap.Params({
                amount: _amount,
                from: _from,
                to: _to
            })
        );
    }

    function liquityV2PaybackEncode(
        address _market,
        address _from,
        uint256 _troveId,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Payback.Params({
                market: _market,
                from: _from,
                troveId: _troveId,
                amount: _amount
            })
        );
    }
    
    function liquityV2SupplyEncode(
        address _market,
        address _from,
        uint256 _troveId,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Supply.Params({
                market: _market,
                from: _from,
                troveId: _troveId,
                amount: _amount
            })
        );
    }

    function liquityV2WithdrawEncode(
        address _market,
        address _to,
        uint256 _troveId,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Withdraw.Params({
                market: _market,
                to: _to,
                troveId: _troveId,
                amount: _amount
            })
        );
    }

    function liquityV2SPClaimCollEncode(
        address _market,
        address _to
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2SPClaimColl.Params({
                market: _market,
                to: _to
            })
        );
    }

    function liquityV2SPDepositEncode(
        address _market,
        address _from,
        address _boldGainTo,
        address _collGainTo,
        uint256 _amount,
        bool _doClaim
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2SPDeposit.Params({
                market: _market,
                from: _from,
                boldGainTo: _boldGainTo,
                collGainTo: _collGainTo,
                amount: _amount,
                doClaim: _doClaim
                })
        );
    }

    function liquityV2SPWithdrawEncode(
        address _market,
        address _boldTo,
        address _collGainTo,
        uint256 _amount,
        bool _doClaim
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2SPWithdraw.Params({
                market: _market,
                boldTo: _boldTo,
                collGainTo: _collGainTo,
                amount: _amount,
                doClaim: _doClaim
            })
        );
    }

    function liquityV2CloseEncode(
        address _market,
        address _from,
        address _to,
        uint256 _troveId
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Close.Params({
                market: _market,
                from: _from,
                to: _to,
                troveId: _troveId
                })
        );
    }

    function liquityV2OpenEncode(
        address _market,
        address _from,
        address _to,
        address _interestBatchManager,
        uint256 _ownerIndex,
        uint256 _collAmount,
        uint256 _boldAmount,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _annualInterestRate,
        uint256 _maxUpfrontFee
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Open.Params({
                market: _market,
                from: _from,
                to: _to,
                interestBatchManager: _interestBatchManager,
                ownerIndex: _ownerIndex,
                collAmount: _collAmount,
                boldAmount: _boldAmount,
                upperHint: _upperHint,
                lowerHint: _lowerHint,
                annualInterestRate: _annualInterestRate,
                maxUpfrontFee: _maxUpfrontFee
            })
        );
    }

    function liquityV2AdjustEncode(
        address _market,
        address _from,
        address _to,
        uint256 _troveId,
        uint256 _collAmount,
        uint256 _debtAmount,
        uint256 _maxUpfrontFee,
        LiquityV2Adjust.CollActionType _collAction,
        LiquityV2Adjust.DebtActionType _debtAction
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Adjust.Params({
                market: _market,
                from: _from,
                to: _to,
                troveId: _troveId,
                collAmount: _collAmount,
                debtAmount: _debtAmount,
                maxUpfrontFee: _maxUpfrontFee,
                collAction: _collAction,
                debtAction: _debtAction
            })
        );
    }

    function liquityV2AdjustZombieTroveEncode(
        address _market,
        address _from,
        address _to,
        uint256 _troveId,
        uint256 _collAmount,
        uint256 _debtAmount,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee,
        LiquityV2AdjustZombieTrove.CollActionType _collAction,
        LiquityV2AdjustZombieTrove.DebtActionType _debtAction
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2AdjustZombieTrove.Params({
                market: _market,
                from: _from,
                to: _to,
                troveId: _troveId,
                collAmount: _collAmount,
                debtAmount: _debtAmount,
                maxUpfrontFee: _maxUpfrontFee,
                upperHint: _upperHint,
                lowerHint: _lowerHint,
                collAction: _collAction,
                debtAction: _debtAction
            })
        );
    }

    function liquityV2AdjustInterestRateEncode(
        address _market,
        uint256 _troveId,
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2AdjustInterestRate.Params({
                market: _market,
                troveId: _troveId,
                newAnnualInterestRate: _newAnnualInterestRate,
                upperHint: _upperHint,
                lowerHint: _lowerHint,
                maxUpfrontFee: _maxUpfrontFee
            })
        );
    }

    function liquityV2BorrowEncode(
        address _market,
        address _to,
        uint256 _troveId,
        uint256 _amount,
        uint256 _maxUpfrontFee
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Borrow.Params({
                market: _market,
                to: _to,
                troveId: _troveId,
                amount: _amount,
                maxUpfrontFee: _maxUpfrontFee
            })
        );
    }

    function liquityV2ClaimEncode(
        address _market,
        address _to
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            LiquityV2Claim.Params({
                market: _market,
                to: _to
            })
        );
    }

    function sendTokensAndUnwrapEncode(
        address[] memory _tokens,
        address[] memory _receivers,
        uint256[] memory _amounts
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            SendTokensAndUnwrap.Params({
                tokens: _tokens,
                receivers: _receivers,
                amounts: _amounts
                })
        );
    }
    
    function morphoTokenWrapEncode(
        address _to,
        uint256 _amount
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            MorphoTokenWrap.Params({
                to: _to,
                amount: _amount
            })
        );
    }

    function fluidVaultT1OpenEncode(
        address _vault,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _from,
        address _to,
        bool _wrapBorrowedEth
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            FluidVaultT1Open.Params({
                vault: _vault,
                collAmount: _collAmount,
                debtAmount: _debtAmount,
                from: _from,
                to: _to,
                wrapBorrowedEth: _wrapBorrowedEth
            })
        );
    }

    function fluidVaultT1SupplyEncode(
        address _vault,
        uint256 _nftId,
        uint256 _amount,
        address _from
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            FluidVaultT1Supply.Params({
                vault: _vault,
                nftId: _nftId,
                amount: _amount,
                from: _from
            })
        );
    }

    function fluidVaultT1WithdrawEncode(
        address _vault,
        uint256 _nftId,
        uint256 _amount,
        address _to,
        bool _wrapWithdrawnEth
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            FluidVaultT1Withdraw.Params({
                vault: _vault,
                nftId: _nftId,
                amount: _amount,
                to: _to,
                wrapWithdrawnEth: _wrapWithdrawnEth
            })
        );
    }

    function fluidVaultT1BorrowEncode(
        address _vault,
        uint256 _nftId,
        uint256 _amount,
        address _to,
        bool _wrapBorrowedEth
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            FluidVaultT1Borrow.Params({
                vault: _vault,
                nftId: _nftId,
                amount: _amount,
                to: _to,
                wrapBorrowedEth: _wrapBorrowedEth
            })
        );
    }

    function fluidVaultT1PaybackEncode(
        address _vault,
        uint256 _nftId,
        uint256 _amount,
        address _from
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            FluidVaultT1Payback.Params({
                vault: _vault,
                nftId: _nftId,
                amount: _amount,
                from: _from
            })
        );
    }

    function fluidVaultT1AdjustEncode(
        address _vault,
        uint256 _nftId,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _from,
        address _to,
        bool _sendWrappedEth,
        FluidVaultT1Adjust.CollActionType _collAction,
        FluidVaultT1Adjust.DebtActionType _debtAction
    ) public pure returns (bytes memory params) {
        params = abi.encode(
            FluidVaultT1Adjust.Params({
                vault: _vault,
                nftId: _nftId,
                collAmount: _collAmount,
                debtAmount: _debtAmount,
                from: _from,
                to: _to,
                sendWrappedEth: _sendWrappedEth,
                collAction: _collAction,
                debtAction: _debtAction
            })
        );
    }
}
