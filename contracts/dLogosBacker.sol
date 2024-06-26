// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IDLogos} from "./interfaces/IdLogos.sol";
import {IDLogosBacker} from "./interfaces/IdLogosBacker.sol";
import {IDLogosStorage} from "./interfaces/IdLogosStorage.sol";
import {DLogos} from "./dLogos.sol";
import "./Error.sol";

// TODO biconomy support

contract DLogosBacker is IDLogosBacker, Ownable2StepUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// STORAGE
    address public dLogosStorage;
    address public dLogos;

    mapping(uint256 => mapping(address => Backer)) public logoBackers; // Mapping of Logo ID to address to Backer
    mapping(uint256 => EnumerableSet.AddressSet) private _logoBackerAddresses;
    mapping(uint256 => uint256) public override logoRewards; // Mapping of Logo ID to accumulated rewards
    mapping(uint256 => uint256) public override logoRejectedFunds; // Mapping of Logo ID to accumulated rejected funds
    
    function initialize(        
        address _dLogosStorage,
        address _dLogos
    ) external initializer {
        // Initialize tx is not gasless
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        
        if (_dLogosStorage == address(0) || _dLogos == address(0)) revert ZeroAddress();

        dLogosStorage = _dLogosStorage;
        dLogos = _dLogos;
    }

    /// MODIFIERS
    modifier validLogoId(uint256 _logoId) {
        if (_logoId >= IDLogos(dLogos).logoId()) revert InvalidLogoId();
        _;
    }

    /**
     * @dev Crowdfund.
     */
    function crowdfund(
        uint256 _logoId,
        address _referrer
    ) external override payable nonReentrant whenNotPaused validLogoId(_logoId) {
        IDLogos.Logo memory l = IDLogos(dLogos).getLogo(_logoId);
        
        if (!l.status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (msg.value < l.minimumPledge) revert InsufficientFunds();
        
        address msgSender = _msgSender();
        bool isBacker = _logoBackerAddresses[_logoId].contains(msgSender);

        if (isBacker) {
            // Ignore `_referrer` because it was already set
            Backer storage backer = logoBackers[_logoId][msgSender];
            unchecked {
                backer.amount += msg.value;
            }
        } else {
            // Record the value sent to the address.
            if (_logoBackerAddresses[_logoId].length() >= 1000) revert TooManyBackers();

            Backer memory b = Backer({
                addr: msgSender,
                referrer: _referrer, // Zero address possible
                amount: msg.value,
                votesToReject: false
            });
            bool added = _logoBackerAddresses[_logoId].add(msgSender);

            if (!added) revert AddBackerFailed();
            
            logoBackers[_logoId][msgSender] = b;
        }

        // Increase total rewards of Logo.
        unchecked {
            logoRewards[_logoId] = logoRewards[_logoId] + msg.value;
        }
        emit Crowdfund(_logoId, msgSender, msg.value);
    }

    /**
     * @dev Withdraw your pledge from a Logo.
     */
    function withdrawFunds(uint256 _logoId) external override nonReentrant whenNotPaused validLogoId(_logoId) {
        IDLogos.Logo memory l = IDLogos(dLogos).getLogo(_logoId);
        if (
            (l.scheduledAt != 0 && !l.status.isRefunded) ||
            l.status.isDistributed
        ) revert LogoFundsCannotBeWithdrawn();
        
        address msgSender = _msgSender();
        bool isBacker = _logoBackerAddresses[_logoId].contains(msgSender);

        if (!isBacker) revert Unauthorized();

        Backer memory backer = logoBackers[_logoId][msgSender];
        
        if (backer.amount == 0) revert InsufficientFunds();
        if (logoRewards[_logoId] < backer.amount) revert InsufficientLogoReward();
        
        bool removed = _logoBackerAddresses[_logoId].remove(msgSender);

        if (!removed) revert RemoveBackerFailed();
        
        delete logoBackers[_logoId][msgSender];
        // Decrease total rewards of Logo.
        logoRewards[_logoId] = logoRewards[_logoId] - backer.amount;
        (bool success, ) = payable(msgSender).call{value: backer.amount}("");

        if (!success) revert EthTransferFailed();
        
        emit FundsWithdrawn(msgSender, backer.amount);
    }

    /**
     * @dev Allows a backer to reject an uploaded asset.
     */
    function reject(uint256 _logoId) external override whenNotPaused validLogoId(_logoId) {
        IDLogos.Logo memory l = IDLogos(dLogos).getLogo(_logoId);
        if (block.timestamp > l.rejectionDeadline) revert RejectionDeadlinePassed();

        address msgSender = _msgSender();
        bool isBacker = _logoBackerAddresses[_logoId].contains(msgSender);

        if (!isBacker) revert Unauthorized();

        Backer memory backer = logoBackers[_logoId][msgSender];
        // Backer can not reject more than once
        if (backer.votesToReject) revert BackerAlreadyRejected();
        // Increase rejected funds.
        unchecked {
            logoRejectedFunds[_logoId] = logoRejectedFunds[_logoId] + backer.amount;
        }
        logoBackers[_logoId][msgSender].votesToReject = true;
        
        emit RejectionSubmitted(_logoId, msgSender);
    }

    /**
     * @dev Return the list of backers for a Logo.
     */
    function getBackersForLogo(uint256 _logoId) public override view returns (Backer[] memory) {
        EnumerableSet.AddressSet storage backerAddresses = _logoBackerAddresses[_logoId];
        address[] memory backerArray = backerAddresses.values();
        Backer[] memory backers = new Backer[](backerArray.length);
        for (uint256 i = 0; i < backerArray.length; i++) {
            backers[i] = logoBackers[_logoId][backerArray[i]];
        }
        return backers;
    }
}
