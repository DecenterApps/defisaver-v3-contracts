// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultT1 } from "../../../../contracts/interfaces/fluid/vaults/IFluidVaultT1.sol";
import { IFluidVaultResolver } from "../../../../contracts/interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { IFluidVaultFactory } from "../../../../contracts/interfaces/fluid/IFluidVaultFactory.sol";
import { FluidVaultT1Open } from "../../../../contracts/actions/fluid/vaultT1/FluidVaultT1Open.sol";
import { FluidVaultT1Adjust } from "../../../../contracts/actions/fluid/vaultT1/FluidVaultT1Adjust.sol";
import { TokenUtils } from "../../../../contracts/utils/TokenUtils.sol";
import { FluidExecuteActions } from "../../../utils/executeActions/FluidExecuteActions.sol";
import { SmartWallet } from "../../../utils/SmartWallet.sol";
import { Vm } from "forge-std/Vm.sol";

contract TestFluidVaultT1Adjust is FluidExecuteActions {

    /*//////////////////////////////////////////////////////////////////////////
                                CONTRACT UNDER TEST
    //////////////////////////////////////////////////////////////////////////*/
    FluidVaultT1Adjust cut;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    SmartWallet wallet;
    address sender;
    address walletAddr;
    IFluidVaultT1[] vaults;

    FluidVaultT1Open openContract;

    struct TestConfig {
        bool isDirect;
        FluidVaultT1Adjust.CollActionType supplyActionType;
        FluidVaultT1Adjust.DebtActionType borrowActionType;
        uint256 openSupplyAmountUsd;
        uint256 openBorrowAmountUsd;
        uint256 supplyAmountUsd;
        uint256 borrowAmountUsd;
        bool isMaxSupplyAmount;
        bool isMaxBorrowAmount;
        bool sendWrappedEth;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   SETUP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        forkMainnetLatest();

        wallet = new SmartWallet(bob);
        sender = wallet.owner();
        walletAddr = wallet.walletAddr();

        cut = new FluidVaultT1Adjust();
        openContract = new FluidVaultT1Open();

        vaults = getT1Vaults();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    ////////////////////////////////////////////////////////////////////////*/
    function test_should_just_supply() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 0,
                supplyAmountUsd: 20000,
                borrowAmountUsd: 0,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_max_supply() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 0,
                supplyAmountUsd: 20000,
                borrowAmountUsd: 0,
                isMaxSupplyAmount: true,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_just_borrow() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 10000,
                supplyAmountUsd: 0,
                borrowAmountUsd: 10000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_just_borrow_while_send_wrapped_eth() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 10000,
                supplyAmountUsd: 0,
                borrowAmountUsd: 10000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: true
            })
        );
    }
    function test_should_just_withdraw() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 0,
                supplyAmountUsd: 20000,
                borrowAmountUsd: 0,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_just_withdraw_while_send_wrapped_eth() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 0,
                supplyAmountUsd: 20000,
                borrowAmountUsd: 0,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: true
            })
        );
    }
    function test_should_max_withdraw() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 0,
                supplyAmountUsd: 50000,
                borrowAmountUsd: 0,
                isMaxSupplyAmount: true,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_max_withdraw_while_send_wrapped_eth() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 0,
                supplyAmountUsd: 50000,
                borrowAmountUsd: 0,
                isMaxSupplyAmount: true,
                isMaxBorrowAmount: false,
                sendWrappedEth: true
            })
        );
    }
    function test_should_just_payback() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 0,
                borrowAmountUsd: 10000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_max_payback() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 0,
                borrowAmountUsd: 30000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: true,
                sendWrappedEth: false
            })
        );
    }
    function test_should_supply_borrow() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 20000,
                borrowAmountUsd: 10000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_supply_borrow_while_send_wrapped_eth() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 20000,
                borrowAmountUsd: 10000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: true
            })
        );
    }
    function test_should_supply_payback() public {
        _baseTest(
            TestConfig({
                isDirect: true,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 5000,
                borrowAmountUsd: 20000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_withdraw_borrow() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 2000,
                borrowAmountUsd: 5000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_withdraw_payback() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 10000,
                borrowAmountUsd: 9000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: false
            })
        );
    }
    function test_should_withdraw_payback_while_send_wrapped_eth() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 10000,
                borrowAmountUsd: 9000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: true
            })
        );
    }
    function test_should_max_supply_max_payback() public {
        _baseTest(
            TestConfig({
                isDirect: true,
                supplyActionType: FluidVaultT1Adjust.CollActionType.SUPPLY,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 20000,
                borrowAmountUsd: 30000,
                isMaxSupplyAmount: true,
                isMaxBorrowAmount: true,
                sendWrappedEth: false
            })
        );
    }
    function test_should_max_withdraw_max_payback() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 50000,
                borrowAmountUsd: 30000,
                isMaxSupplyAmount: true,
                isMaxBorrowAmount: true,
                sendWrappedEth: false
            })
        );
    }
    function test_should_max_withdraw_max_payback_while_send_wrapped_eth() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.PAYBACK,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 50000,
                borrowAmountUsd: 30000,
                isMaxSupplyAmount: true,
                isMaxBorrowAmount: true,
                sendWrappedEth: true
            })
        );
    }

    function test_should_withdraw_borrow_while_send_wrapped_eth() public {
        _baseTest(
            TestConfig({
                isDirect: false,
                supplyActionType: FluidVaultT1Adjust.CollActionType.WITHDRAW,
                borrowActionType: FluidVaultT1Adjust.DebtActionType.BORROW,
                openSupplyAmountUsd: 50000,
                openBorrowAmountUsd: 30000,
                supplyAmountUsd: 2000,
                borrowAmountUsd: 5000,
                isMaxSupplyAmount: false,
                isMaxBorrowAmount: false,
                sendWrappedEth: true
            })
        );
    }

    struct TempLocalVars {
        uint256 nftId;
        bool isNativeSupply;
        bool isNativeBorrow;
        uint256 supplyTokenAmount;
        uint256 borrowTokenAmount;

        IFluidVaultResolver.UserPosition userPositionBefore;
        IFluidVaultResolver.UserPosition userPositionAfter;

        // SNAPSHOTS
        uint256 senderBorrowTokenBalanceBefore;
        uint256 senderSupplyTokenBalanceBefore;
        uint256 senderEthTokenBalanceBefore;
        // --
        uint256 senderBorrowTokenBalanceAfter;
        uint256 senderSupplyTokenBalanceAfter;
        uint256 senderEthTokenBalanceAfter;
        // =================
        uint256 walletBorrowTokenBalanceBefore;
        uint256 walletSupplyTokenBalanceBefore;
        uint256 walletEthTokenBalanceBefore;
        uint256 walletWethTokenBalanceBefore;
        // --
        uint256 walletBorrowTokenBalanceAfter;
        uint256 walletSupplyTokenBalanceAfter;
        uint256 walletEthTokenBalanceAfter;
        uint256 walletWethTokenBalanceAfter;
    }

    function _baseTest(
        TestConfig memory _config
    ) internal {
        for (uint256 i = 0; i < vaults.length; ++i) {
            IFluidVaultT1.ConstantViews memory constants = vaults[i].constantsView();
            TempLocalVars memory vars;

            vars.nftId = executeFluidVaultT1Open(
                address(vaults[i]),
                _config.openSupplyAmountUsd,
                _config.openBorrowAmountUsd,
                wallet,
                address(openContract)
            );

            vars.isNativeSupply = constants.supplyToken == TokenUtils.ETH_ADDR;
            vars.isNativeBorrow = constants.borrowToken == TokenUtils.ETH_ADDR;

            (vars.userPositionBefore, ) = IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(vars.nftId);
            
            // .--------- SUPPLY ----------.
            if (_config.supplyActionType == FluidVaultT1Adjust.CollActionType.SUPPLY && _config.supplyAmountUsd > 0) {
                address supplyToken = vars.isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken;
                vars.supplyTokenAmount = amountInUSDPrice(supplyToken, _config.supplyAmountUsd);
                give(supplyToken, sender, vars.supplyTokenAmount);
                approveAsSender(sender, supplyToken, walletAddr, 0); // To handle Tether
                approveAsSender(sender, supplyToken, walletAddr, vars.supplyTokenAmount);
            }

            // .--------- WITHDRAW ----------.
            if (_config.supplyActionType == FluidVaultT1Adjust.CollActionType.WITHDRAW && _config.supplyAmountUsd > 0) {
                address supplyToken = vars.isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken;
                vars.supplyTokenAmount = amountInUSDPrice(supplyToken, _config.supplyAmountUsd);
            }

            // .--------- PAYBACK ----------.
            if (_config.borrowActionType == FluidVaultT1Adjust.DebtActionType.PAYBACK && _config.borrowAmountUsd > 0) {
                address borrowToken = vars.isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken;

                vars.borrowTokenAmount = _config.isMaxBorrowAmount
                    ? vars.userPositionBefore.borrow * 1001 / 1000 // add 0.1% buffer
                    : amountInUSDPrice(borrowToken, _config.borrowAmountUsd);

                give(borrowToken, sender, vars.borrowTokenAmount);
                approveAsSender(sender, borrowToken, walletAddr, 0); // To handle Tether
                approveAsSender(sender, borrowToken, walletAddr, vars.borrowTokenAmount);
            }

            // .--------- BORROW ----------.
            if (_config.borrowActionType == FluidVaultT1Adjust.DebtActionType.BORROW && _config.borrowAmountUsd > 0) {
                address borrowToken = vars.isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken;
                vars.borrowTokenAmount = amountInUSDPrice(borrowToken, _config.borrowAmountUsd);
            }

            // .--------- TAKE SNAPSHOTS ----------.
            vars.senderSupplyTokenBalanceBefore = balanceOf(vars.isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken, sender);
            vars.senderBorrowTokenBalanceBefore = balanceOf(vars.isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken, sender);
            vars.senderEthTokenBalanceBefore = address(sender).balance;
            vars.walletSupplyTokenBalanceBefore = balanceOf(vars.isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken, walletAddr);
            vars.walletBorrowTokenBalanceBefore = balanceOf(vars.isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken, walletAddr);
            vars.walletWethTokenBalanceBefore = balanceOf(TokenUtils.WETH_ADDR, walletAddr);
            vars.walletEthTokenBalanceBefore = address(walletAddr).balance;

            // .--------- EXECUTE ACTION ----------.
            bytes memory executeActionCallData = executeActionCalldata(
                fluidVaultT1AdjustEncode(
                    address(vaults[i]),
                    vars.nftId,
                    _config.isMaxSupplyAmount ? type(uint256).max : vars.supplyTokenAmount,
                    _config.isMaxBorrowAmount ? type(uint256).max : vars.borrowTokenAmount,
                    sender,
                    sender,
                    _config.sendWrappedEth,
                    _config.supplyActionType,
                    _config.borrowActionType
                ),
                _config.isDirect
            );

            wallet.execute(address(cut), executeActionCallData, 0);

            // .--------- TAKE SNAPSHOTS ----------.
            vars.senderSupplyTokenBalanceAfter = balanceOf(vars.isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken, sender);
            vars.senderBorrowTokenBalanceAfter = balanceOf(vars.isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken, sender);
            vars.senderEthTokenBalanceAfter = address(sender).balance;
            vars.walletSupplyTokenBalanceAfter = balanceOf(vars.isNativeSupply ? TokenUtils.WETH_ADDR : constants.supplyToken, walletAddr);
            vars.walletBorrowTokenBalanceAfter = balanceOf(vars.isNativeBorrow ? TokenUtils.WETH_ADDR : constants.borrowToken, walletAddr);
            vars.walletWethTokenBalanceAfter = balanceOf(TokenUtils.WETH_ADDR, walletAddr);
            vars.walletEthTokenBalanceAfter = address(walletAddr).balance;

            (vars.userPositionAfter, ) = IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(vars.nftId);

            // .--------- ASSERTIONS ----------.
            // make sure no dust is left on wallet
            assertEq(vars.walletSupplyTokenBalanceAfter, vars.walletSupplyTokenBalanceBefore);
            assertEq(vars.walletBorrowTokenBalanceAfter, vars.walletBorrowTokenBalanceBefore);
            assertEq(vars.walletEthTokenBalanceAfter, vars.walletEthTokenBalanceBefore);
            assertEq(vars.walletWethTokenBalanceAfter, vars.walletWethTokenBalanceBefore);

            // .--------- SUPPLY ----------.
            if (_config.supplyActionType == FluidVaultT1Adjust.CollActionType.SUPPLY && _config.supplyAmountUsd > 0) {
                if (_config.isMaxSupplyAmount) {
                    assertEq(vars.senderSupplyTokenBalanceAfter, 0);
                } else {
                    assertEq(vars.senderSupplyTokenBalanceAfter, vars.senderSupplyTokenBalanceBefore - vars.supplyTokenAmount);
                }
            }

            // .--------- WITHDRAW ----------.
            if (_config.supplyActionType == FluidVaultT1Adjust.CollActionType.WITHDRAW && _config.supplyAmountUsd > 0) {
                if (_config.isMaxSupplyAmount) {
                    assertEq(vars.userPositionAfter.supply, 0);
                    if (vars.isNativeSupply && !_config.sendWrappedEth) {
                        assertApproxEqRel(
                            vars.senderEthTokenBalanceAfter,
                            vars.senderEthTokenBalanceBefore + vars.userPositionBefore.supply,
                            1e15 // 0.1% tolerance
                        );
                    } else {
                        assertApproxEqRel(
                            vars.senderSupplyTokenBalanceAfter,
                            vars.senderSupplyTokenBalanceBefore + vars.userPositionBefore.supply,
                            1e15 // 0.1% tolerance
                        );
                    }
                } else {
                    if (vars.isNativeSupply && !_config.sendWrappedEth) {
                        assertEq(vars.senderEthTokenBalanceAfter, vars.senderEthTokenBalanceBefore + vars.supplyTokenAmount);
                    } else {
                        assertEq(vars.senderSupplyTokenBalanceAfter, vars.senderSupplyTokenBalanceBefore + vars.supplyTokenAmount);
                    }
                }
            }

            // .--------- PAYBACK ----------.
            if (_config.borrowActionType == FluidVaultT1Adjust.DebtActionType.PAYBACK && _config.borrowAmountUsd > 0) {
                if (_config.isMaxBorrowAmount) {
                    assertEq(vars.userPositionAfter.borrow, 0);
                    if (!vars.isNativeBorrow) {
                        assertApproxEqRel(
                            vars.senderBorrowTokenBalanceAfter,
                            vars.senderBorrowTokenBalanceBefore - vars.userPositionBefore.borrow,
                            1e15 // 0.1% tolerance
                        );
                    }
                } else {
                    assertEq(vars.senderBorrowTokenBalanceAfter, vars.senderBorrowTokenBalanceBefore - vars.borrowTokenAmount);
                }
            }

            // .--------- BORROW ----------.
            if (_config.borrowActionType == FluidVaultT1Adjust.DebtActionType.BORROW && _config.borrowAmountUsd > 0) {
                if (vars.isNativeBorrow && !_config.sendWrappedEth) {
                    assertEq(vars.senderEthTokenBalanceAfter, vars.senderEthTokenBalanceBefore + vars.borrowTokenAmount);
                } else {
                    assertEq(vars.senderBorrowTokenBalanceAfter, vars.senderBorrowTokenBalanceBefore + vars.borrowTokenAmount);
                }
            }
        }
    }
}