// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IDSProxy.sol";
import "../DS/DSGuard.sol";
import "../DS/DSAuth.sol";
import "../utils/DFSProxyRegistry.sol";

contract DSProxyView {
    DFSProxyRegistry registry = DFSProxyRegistry(0x29474FdaC7142f9aB7773B8e38264FA15E3805ed);

    struct ProxyData {
        address proxy;
        bool correctDSGuardOwner;
        bool isUserOwner;
    }

    function checkDSGuardOwner(address _proxy) public view returns (bool) {
        if (_proxy == address(0)) return false;

        address currAuthority = address(DSAuth(_proxy).authority());

        return DSAuth(currAuthority).owner() == _proxy;
    }

    function isUserProxyOwner(address _user, address _proxy) public view returns (bool) {
        return IDSProxy(_proxy).owner() == _user;
    }

    function getProxiesAndCheckDSGuard(address _user)
        public
        view
        returns (ProxyData[] memory proxies)
    {
        (address mcdProxy, address[] memory otherProxies) = registry.getAllProxies(_user);

        proxies = new ProxyData[](otherProxies.length + 1);

        proxies[0] = ProxyData({
            proxy: mcdProxy,
            correctDSGuardOwner: checkDSGuardOwner(mcdProxy),
            isUserOwner: isUserProxyOwner(_user, mcdProxy)
        });

        for (uint256 i = 0; i < otherProxies.length; ++i) {
            proxies[i + 1] = ProxyData({
                proxy: otherProxies[i],
                correctDSGuardOwner: checkDSGuardOwner(otherProxies[i]),
                isUserOwner: isUserProxyOwner(_user, otherProxies[i])
            });
        }
    }
}
