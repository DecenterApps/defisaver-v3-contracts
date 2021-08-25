// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "../../../interfaces/curve/IAddressProvider.sol";
import "../../../interfaces/curve/ISwaps.sol";

contract CurveHelper {
    int128 constant MAX_COINS = 8;
    uint256 constant CALC_INPUT_SIZE = 100;

    address public constant AddressProviderAddr = 0x0000000022D53366457F9d5E68Ec105046FC4383;
    IAddressProvider public constant AddressProvider = IAddressProvider(AddressProviderAddr);

    function getSwaps() internal view returns (ISwaps) {
        return ISwaps(AddressProvider.get_address(2));
    }

    /*
    function getRegistry() internal view returns (IRegistry) {
        return IRegistry(AddressProvider.get_registry());
    }
    */
}