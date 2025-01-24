
import { IFluidVaultT1 } from "../../../../contracts/interfaces/fluid/IFluidVaultT1.sol";
import { IFluidVaultResolver } from "../../../../contracts/interfaces/fluid/IFluidVaultResolver.sol";
import { IFluidVaultFactory } from "../../../../contracts/interfaces/fluid/IFluidVaultFactory.sol";
import { FluidVaultT1Open } from "../../../../contracts/actions/fluid/vaultT1/FluidVaultT1Open.sol";
import { FluidVaultT1Borrow } from "../../../../contracts/actions/fluid/vaultT1/FluidVaultT1Borrow.sol";

import { FluidExecuteActions } from "../../../utils/executeActions/FluidExecuteActions.sol";
import { SmartWallet } from "../../../utils/SmartWallet.sol";
import { console } from "forge-std/console.sol";

contract TestFluidVaultT1Borrow is FluidExecuteActions {

    /*//////////////////////////////////////////////////////////////////////////
                                CONTRACT UNDER TEST
    //////////////////////////////////////////////////////////////////////////*/
    FluidVaultT1Borrow cut;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    SmartWallet wallet;
    address sender;
    address walletAddr;
    IFluidVaultT1[] vaults;

    FluidVaultT1Open openContract;

    /*//////////////////////////////////////////////////////////////////////////
                                   SETUP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        forkMainnetLatest();

        wallet = new SmartWallet(bob);
        sender = wallet.owner();
        walletAddr = wallet.walletAddr();

        cut = new FluidVaultT1Borrow();
        openContract = new FluidVaultT1Open();

        vaults = getT1Vaults();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    ////////////////////////////////////////////////////////////////////////*/
    function test_should_borrow() public {
        bool isDirect = false;
        uint256 initialSupplyAmountUSD = 50000;
        uint256 borrowAmountUSD = 30000;
        _baseTest(isDirect, initialSupplyAmountUSD, borrowAmountUSD);
    }
    function test_should_borrow_action_direct() public {
        bool isDirect = true;
        uint256 initialSupplyAmountUSD = 50000;
        uint256 borrowAmountUSD = 30000;
        _baseTest(isDirect, initialSupplyAmountUSD, borrowAmountUSD);
    }
    function _baseTest(
        bool _isDirect,
        uint256 _initialSupplyAmountUSD,
        uint256 _borrowAmountUSD
    ) internal {
        for (uint256 i = 0; i < vaults.length; ++i) {
            uint256 nftId = executeFluidVaultT1Open(
                address(vaults[i]),
                _initialSupplyAmountUSD,
                0,
                wallet,
                address(openContract)
            );

            IFluidVaultT1.ConstantViews memory constants = vaults[i].constantsView();

            uint256 borrowAmount = amountInUSDPrice(constants.borrowToken, _borrowAmountUSD);

            bytes memory executeActionCallData = executeActionCalldata(
                fluidVaultT1BorrowEncode(
                    address(vaults[i]),
                    nftId,
                    borrowAmount,
                    sender
                ),
                _isDirect
            );

            (IFluidVaultResolver.UserPosition memory userPositionBefore, ) = 
                IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(nftId);

            uint256 senderBorrowTokenBalanceBefore = balanceOf(constants.borrowToken, sender);
            uint256 walletBorrowTokenBalanceBefore = balanceOf(constants.borrowToken, walletAddr);

            wallet.execute(address(cut), executeActionCallData, 0);

            uint256 senderBorrowTokenBalanceAfter = balanceOf(constants.borrowToken, sender);
            uint256 walletBorrowTokenBalanceAfter = balanceOf(constants.borrowToken, walletAddr);

            (IFluidVaultResolver.UserPosition memory userPositionAfter, ) = 
                IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(nftId);

            assertEq(walletBorrowTokenBalanceAfter, walletBorrowTokenBalanceBefore);
            assertEq(senderBorrowTokenBalanceAfter, senderBorrowTokenBalanceBefore + borrowAmount);
            assertEq(userPositionBefore.borrow, 0);
            assertApproxEqRel(
                userPositionAfter.borrow,
                borrowAmount,
                1e15 // 0.1% tolerance
            );
        }
    }
}