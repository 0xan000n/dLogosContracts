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
    address public override dLogosBacker;
    address public override dLogosCore;
    address public override logoNFT;
    address public override dLogos;
    address public override community;
    uint256 public override dLogosFee; // DLogos (Labs) fee
    uint256 public override communityFee; // Community fee
    uint256 public override affiliateFee; // Affiliate fee
    uint32 public override rejectThreshold; // Backer rejected funds threshold
    uint8 public override maxDuration; // Max crowdfunding duration
    uint8 public override rejectionWindow; // Reject deadline in days

    EnumerableSet.AddressSet private _zeroFeeProposers; // List of proposers for whom the dLogosFee is waived

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _dLogos,
        address _community
    ) external initializer notZeroAddress(_dLogos) notZeroAddress(_community) {
        __Ownable_init(msg.sender);

        dLogos = _dLogos;
        community = _community;
        dLogosFee = 1e5; // 10%
        communityFee = 1e5; // 10%
        affiliateFee = 5 * 1e4; // 5%
        rejectThreshold = 5 * 1e5; // 50%
        maxDuration = 60; // 60 days
        rejectionWindow = 7; // 7 days
    }

    modifier onlyOwnerOrigin() {
        if (owner() != tx.origin) revert Unauthorized();
        _;
    }

    modifier onlyInternalTx() {
        if (tx.origin == msg.sender) revert DirectCallNotAllowed();
        _;
    }

    modifier notZeroAddress(address _addr) {
        if (_addr == address(0)) revert ZeroAddress();
        _;
    }

    /**
     * @dev This function will be called within the DLogosBacker deployment context.
     */
    function setDLogosBacker(
        address _dLogosBacker
    ) external onlyOwnerOrigin onlyInternalTx notZeroAddress(_dLogosBacker) {
        dLogosBacker = _dLogosBacker;
        emit DLogosBackerUpdated(_dLogosBacker);
    }

    /**
     * @dev This function will be called within the DLogosCore deployment context.
     */
    function setDLogosCore(
        address _dLogosCore
    ) external onlyOwnerOrigin onlyInternalTx notZeroAddress(_dLogosCore) {
        dLogosCore = _dLogosCore;
        emit DLogosCoreUpdated(_dLogosCore);
    }

    /**
     * @dev This function will be called within the LogoNFT deployment context.
     */
    function setLogoNFT(
        address _logoNFT
    ) external onlyOwnerOrigin onlyInternalTx notZeroAddress(_logoNFT) {
        logoNFT = _logoNFT;
        emit LogoNFTUpdated(_logoNFT);
    }

    function setRejectThreshold(
        uint32 _rejectThreshold
    ) external override onlyOwner {
        if (_rejectThreshold == 0 || _rejectThreshold > PERCENTAGE_SCALE)
            revert InvalidRejectThreshold();

        rejectThreshold = _rejectThreshold;
        emit RejectThresholdUpdated(rejectThreshold);
    }

    function setMaxDuration(uint8 _maxDuration) external override onlyOwner {
        if (_maxDuration == 0 || _maxDuration >= 100)
            revert InvalidMaxDuration();

        maxDuration = _maxDuration;
        emit MaxDurationUpdated(_maxDuration);
    }

    function setRejectionWindow(
        uint8 _rejectionWindow
    ) external override onlyOwner {
        // Zero possible
        rejectionWindow = _rejectionWindow;
        emit RejectionWindowUpdated(_rejectionWindow);
    }

    function setDLogosAddress(
        address _dLogos
    ) external override onlyOwner notZeroAddress(_dLogos) {
        dLogos = _dLogos;
        emit DLogosAddressUpdated(_dLogos);
    }

    function setCommunityAddress(
        address _community
    ) external override onlyOwner notZeroAddress(_community) {
        community = _community;
        emit CommunityAddressUpdated(_community);
    }

    function setDLogosFee(uint256 _dLogosFee) external override onlyOwner {
        if (_dLogosFee > PERCENTAGE_SCALE) revert FeeExceeded();

        dLogosFee = _dLogosFee;
        emit DLogosFeeUpdated(_dLogosFee);
    }

    function setCommunityFee(
        uint256 _communityFee
    ) external override onlyOwner {
        if (_communityFee + dLogosFee > PERCENTAGE_SCALE) revert FeeExceeded();

        communityFee = _communityFee;
        emit CommunityFeeUpdated(_communityFee);
    }

    function setAffiliateFee(
        uint256 _affiliateFee
    ) external override onlyOwner {
        if (_affiliateFee > MAX_AFFILIATE_FEE) revert FeeExceeded();

        affiliateFee = _affiliateFee;
        emit AffiliateFeeUpdated(_affiliateFee);
    }

    function setZeroFeeProposers(
        address[] calldata _proposers,
        bool[] calldata _statuses
    ) external override onlyOwner {
        if (_proposers.length != _statuses.length)
            revert InvalidArrayArguments();

        for (uint256 i = 0; i < _proposers.length; i++) {
            if (_statuses[i] && !_isZeroFeeProposer(_proposers[i])) {
                _zeroFeeProposers.add(_proposers[i]);
            } else if (!_statuses[i] && _isZeroFeeProposer(_proposers[i])) {
                _zeroFeeProposers.remove(_proposers[i]);
            }
        }

        emit ZeroFeeProposersUpdated(_proposers, _statuses);
    }

    /**
     * @dev Query zero fee proposer status.
     */
    function isZeroFeeProposer(
        address _proposer
    ) external view override returns (bool) {
        return _isZeroFeeProposer(_proposer);
    }

    function _isZeroFeeProposer(address _proposer) private view returns (bool) {
        return _zeroFeeProposers.contains(_proposer);
    }
}
