// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

contract TransparentFactory is Ownable, Multicall {
    ProxyAdmin private _proxyAdmin;

    constructor() Ownable(msg.sender) {
        _proxyAdmin = new ProxyAdmin(msg.sender);
    }

    function createContract(
        address logicContract,
        bytes memory initData
    ) public returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            logicContract,
            address(_proxyAdmin),
            initData
        );
        return address(proxy);
    }

    function upgradeContract(
        address proxyAddress,
        address newLogicContract,
        bytes memory initData
    ) public onlyOwner {
        _proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxyAddress),
            newLogicContract,
            initData
        );
    }
}
