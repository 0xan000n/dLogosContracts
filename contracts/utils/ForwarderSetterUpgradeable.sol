// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

abstract contract ForwarderSetterUpgradeable is Initializable, Ownable2StepUpgradeable {
    address private _trustedForwarder; // Customized trusted forwarder address

    error ZeroAddress();

    event TrustedForwarderUpdated(address indexed trustedForwarder_);

    function __ForwarderSetterUpgradeable_init(address trustedForwarder_) internal onlyInitializing {
        __ForwarderSetterUpgradeable_init_unchained(trustedForwarder_);
    }

    function __ForwarderSetterUpgradeable_init_unchained(address trustedForwarder_) internal onlyInitializing {
        _setTrustedForwarder(trustedForwarder_);
    }

    function setTrustedForwarder(address trustedForwarder_) external onlyOwner {
        _setTrustedForwarder(trustedForwarder_);
    }

    function _setTrustedForwarder(address trustedForwarder_) internal {
        if (trustedForwarder_ == address(0)) revert ZeroAddress();
        _trustedForwarder = trustedForwarder_;
        emit TrustedForwarderUpdated(trustedForwarder_);
    }

    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }
}
