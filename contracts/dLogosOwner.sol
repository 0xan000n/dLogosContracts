// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IDLogosOwner} from "./interfaces/IdLogosOwner.sol";
import "./Error.sol";

contract DLogosOwner is IDLogosOwner, Ownable2StepUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// CONSTANTS
    uint256 public constant PERCENTAGE_SCALE = 1e6;
    uint256 public constant MAX_AFFILIATE_FEE = 2 * 1e5; // Max 20%
    /// Storage
    address public override dLogos;
    address public override community;
    uint256 public override dLogosFee; // DLogos (Labs) fee
    uint256 public override communityFee; // Community fee
    uint256 public override affiliateFee; // Affiliate fee    
    uint16 public override rejectThreshold; // Backer rejection threshold in BPS
    uint8 public override maxDuration; // Max crowdfunding duration
    uint8 public override rejectionWindow; // Reject deadline in days

    EnumerableSet.AddressSet private _zeroFeeProposers; // List of proposers who dLogos does not charge fees

    function initialize(
        address _dLogos,
        address _community
    ) external initializer {
        __Ownable_init(msg.sender);

        if (_dLogos == address(0) || _community == address(0)) revert ZeroAddress();

        dLogos = _dLogos;
        community = _community;
        dLogosFee = 1e5; // 10%
        communityFee = 1e5; // 10%
        affiliateFee = 5 * 1e4; // 5%        
        
        rejectThreshold = 5000; // 50%
        maxDuration = 60; // 60 days
        rejectionWindow = 7; // 7 days        
    }

    /**
     * @dev Set reject threshold for dLogos.
     */
    function setRejectThreshold(
        uint16 _rejectThreshold
    ) external override onlyOwner {
        if (_rejectThreshold == 0 || _rejectThreshold > 10000) revert InvalidRejectThreshold();
        
        rejectThreshold = _rejectThreshold;
        emit RejectThresholdUpdated(rejectThreshold);
    }

    /**
     * @dev Set crowdfund duration limit
     */
    function setMaxDuration(uint8 _maxDuration) external override onlyOwner {
        if (_maxDuration == 0 || _maxDuration >= 100) revert InvalidMaxDuration();

        maxDuration = _maxDuration;
        emit MaxDurationUpdated(_maxDuration);
    }

    function setRejectionWindow(uint8 _rejectionWindow) external override onlyOwner {
        // Zero possible
        rejectionWindow = _rejectionWindow;
        emit RejectinoWindowUpdated(_rejectionWindow);
    }

    function setDLogosAddress(address _dLogos) external override onlyOwner {
        if (_dLogos == address(0)) revert ZeroAddress();

        dLogos = _dLogos;
        emit DLogosAddressUpdated(_dLogos);
    }

    function setCommunityAddress(address _community) external override onlyOwner {
        if (_community == address(0)) revert ZeroAddress();

        community = _community;
        emit CommunityAddressUpdated(_community);
    }

    function setDLogosFee(uint256 _dLogosFee) external override onlyOwner {
        if (_dLogosFee > PERCENTAGE_SCALE) revert FeeExceeded();

        dLogosFee = _dLogosFee;
        emit DLogosFeeUpdated(_dLogosFee);
    }

    function setCommunityFee(uint256 _communityFee) external override onlyOwner {
        if (_communityFee + dLogosFee > PERCENTAGE_SCALE) revert FeeExceeded();

        communityFee = _communityFee;
        emit CommunityFeeUpdated(_communityFee);
    }  

    function setAffiliateFee(uint256 _affiliateFee) external override onlyOwner {
        if (_affiliateFee > MAX_AFFILIATE_FEE) revert FeeExceeded();

        affiliateFee = _affiliateFee;
        emit AffiliateFeeUpdated(_affiliateFee);
    }

    function setZeroFeeProposers(
        address[] calldata _proposers,
        bool[] calldata _statuses
    ) external override onlyOwner {
        if (_proposers.length != _statuses.length) revert InvalidArrayArguments();

        for (uint256 i = 0; i < _proposers.length; i++) {
            if (_statuses[i] && !_isZeroFeeProposer(_proposers[i])) {
                _zeroFeeProposers.add(_proposers[i]);
            } else if (!_statuses[i] && _isZeroFeeProposer(_proposers[i])) {
                _zeroFeeProposers.remove(_proposers[i]);
            }
        }

        emit ZeroFeeProposersSet(_proposers, _statuses);
    }

    /**
     * @dev Query zero fee proposer status
     */
    function isZeroFeeProposer(address _proposer) external override view returns (bool) {
        return _isZeroFeeProposer(_proposer);
    }

    function _isZeroFeeProposer(address _proposer) private view returns (bool) {
        return _zeroFeeProposers.contains(_proposer);
    }
}
