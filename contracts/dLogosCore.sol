// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IDLogosCore} from "./interfaces/IdLogosCore.sol";
import {IDLogosOwner} from "./interfaces/IdLogosOwner.sol";
import {IDLogosBacker} from "./interfaces/IdLogosBacker.sol";
import {DLogosSplitsHelper} from "./libraries/dLogosSplitsHelper.sol";
import {ForwarderSetterUpgradeable} from "./utils/ForwarderSetterUpgradeable.sol";
import {SplitV2Lib} from "./splitsV2/libraries/SplitV2.sol";
import "./Error.sol";

/*                                                           
                                     ..........................                                     
                                ....................................                                
                            ............................................                            
                         ..................:===:...........................                         
                      .....................-====..............................                      
                    .......................=====:...............................                    
                  .........................=====-.................................                  
                 ..........................-=====..................................                 
               ............................-=====....................................               
              .............................:=====:....................................              
             ..............................:=====:.....................................             
            ...............................:=====-......................................            
           .................................=====-.......................................           
           .................................=====-.......................................           
          ..................................=====-........................................          
          ..................................=====-........................................          
          ..................................=====-........................................          
          ..................................=====-........................................          
          ..................................=====-........................................          
          .................................:=====:........................................          
          .................................-=====:........................................          
           ................................======........................................           
           ...............................-=====-........................................           
            ..................:--------:..======:.......................................            
             ...............-====------========-.......................................             
              .............-===-.......-=======-::....................................              
               ............:====-----========-=======----::::::::::--==-.............               
                ............:==============:....:-====================:.............                
                  ............:-======--:...........::--=======---::..............                  
                    ............................................................                    
                      ........................................................                      
                         ..................................................                         
                            ............................................                            
                                 ..................................                                 
                                     .........................                                                                                                                                 
*/
/// @title Core DLogos contract
/// @author 0xan000n
contract DLogosCore is 
    IDLogosCore, 
    Ownable2StepUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    ERC2771ContextUpgradeable, 
    ForwarderSetterUpgradeable 
{
    /// CONSTANTS
    uint256 public constant PERCENTAGE_SCALE = 1e6;

    /// STORAGE
    address public dLogosOwner;
    address public dLogosBacker;
    uint256 public override logoId; // Global Logo ID
    mapping(uint256 => Logo) public logos; // Mapping of Owner addresses to Logo ID to Logo info    
    mapping(uint256 => Speaker[]) public logoSpeakers; // Mapping of Logo ID to list of Speakers

    // The contract does not use `trustedForwarder` that is defined in ERC2771ContextUpgradeable
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    function initialize(        
        address trustedForwarder_,
        address _dLogosOwner,
        address _dLogosBacker
    ) external initializer {
        // Initialize tx is not gasless
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        __ForwarderSetterUpgradeable_init(trustedForwarder_);
        
        if (_dLogosOwner == address(0) || _dLogosBacker == address(0)) 
            revert ZeroAddress();

        dLogosOwner = _dLogosOwner;
        dLogosBacker = _dLogosBacker;
        logoId = 1; // Starting from 1
    }

    /// MODIFIERS
    modifier validLogoId(uint256 _logoId) {
        if (_logoId >= logoId) revert InvalidLogoId();
        _;
    }    

    /// FUNCTIONS

    function getLogo(uint256 _logoId) external override view returns (Logo memory l) {
        l = logos[_logoId];
    }

    /**
     * @dev Create a new Logo onchain.
     */
    function createLogo(
        uint256 _proposerFee,
        string calldata _title,
        uint8 _crowdfundNumberOfDays
    ) external override whenNotPaused returns (uint256) {
        if (bytes(_title).length == 0) revert EmptyString();
        if (_crowdfundNumberOfDays > IDLogosOwner(dLogosOwner).maxDuration()) revert CrowdfundDurationExceeded();
        address msgSender = _msgSender();
        uint256 communityFee = IDLogosOwner(dLogosOwner).communityFee();
        uint256 dLogosFee = IDLogosOwner(dLogosOwner).dLogosFee();
        if (IDLogosOwner(dLogosOwner).isZeroFeeProposer(msgSender)) {
            if (_proposerFee + communityFee > PERCENTAGE_SCALE) revert FeeExceeded();
        } else {
            if (_proposerFee + dLogosFee + communityFee > PERCENTAGE_SCALE) revert FeeExceeded();
        }

        uint256 _logoId = logoId;
        logos[_logoId] = Logo({
            id: _logoId,
            title: _title,
            proposer: msgSender,
            proposerFee: _proposerFee,
            scheduledAt: 0,
            mediaAssetURL: "",
            minimumPledge: 10000000000000, // 0.00001 ETH
            crowdfundStartAt: block.timestamp,
            crowdfundEndAt: block.timestamp + _crowdfundNumberOfDays * 1 days,
            splitForAffiliate: address(0),
            splitForSpeaker: address(0),
            rejectionDeadline: 0,
            status: LogoStatus({
                isCrowdfunding: true,
                isUploaded: false,
                isDistributed: false,
                isRefunded: false
            })
        });
        emit LogoCreated(msgSender, _logoId, block.timestamp);
        emit CrowdfundToggled(msgSender, true);
        return logoId++; // Return and Increment Global Logo ID
    }

    /**
     * @dev Toggle crowdfund for Logo. Only the proposer of the Logo is allowed to toggle a crowdfund.
     */
    function toggleCrowdfund(
        uint256 _logoId
    ) external override whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        address msgSender = _msgSender();
        if (l.proposer != msgSender) revert Unauthorized();
        if (l.scheduledAt != 0) revert CrowdfundClosed();
        if (l.crowdfundEndAt > block.timestamp) revert CrowdfundEnded();
        
        logos[_logoId].status.isCrowdfunding = !l.status.isCrowdfunding;
        emit CrowdfundToggled(msgSender, !l.status.isCrowdfunding);
    }   

    /**
     * @dev Set minimum pledge for a conversation.
     */
    function setMinimumPledge(
        uint256 _logoId,
        uint256 _minimumPledge
    ) external override whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        address msgSender = _msgSender();
        if (l.proposer != msgSender) revert Unauthorized();
        if (!l.status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (l.crowdfundEndAt > block.timestamp) revert CrowdfundEnded();
        if (_minimumPledge == 0) revert NotZero();

        logos[_logoId].minimumPledge = _minimumPledge;
        emit MinimumPledgeSet(msgSender, _minimumPledge);
    }
    
    /**
     * @dev Issue refund of the Logo.
     */
    function refund(uint256 _logoId) external override whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        if (l.status.isDistributed) revert LogoDistributed();
        if (l.status.isRefunded) revert LogoRefunded();

        // Case 1: Logo proposer can refund whenever.
        bool c1 = l.proposer == _msgSender();
        // Case 2: Crowdfund end date reached and not distributed.
        bool c2 = block.timestamp > l.crowdfundEndAt;
        // Case 3: >7 days have passed since schedule date and no asset uploaded.
        bool c3 = 
            l.scheduledAt != 0 
            && 
            block.timestamp > l.scheduledAt + IDLogosOwner(dLogosOwner).rejectionWindow() * 1 days
            && 
            !l.status.isUploaded;
        // Case 4: >50% of backer funds reject upload.
        uint256 logoRewards = IDLogosBacker(dLogosBacker).logoRewards(_logoId);
        uint256 logoRejectedFunds = IDLogosBacker(dLogosBacker).logoRejectedFunds(_logoId);
        bool c4 = 
            logoRejectedFunds * 10_000 / logoRewards
            > 
            IDLogosOwner(dLogosOwner).rejectThreshold();
        
        if (!c1 && !c2 && !c3 && !c4) revert NoRefundConditionsMet();

        logos[_logoId].status.isRefunded = true;

        emit RefundInitiated(_logoId, c1, c2, c3, c4);
    }    

    /**
     * @dev Set speakers for a Logo.
     */
    function setSpeakers(
        SetSpeakersParam calldata _param
    ) external override whenNotPaused validLogoId(_param.logoId) {
        Logo memory l = logos[_param.logoId];
        address msgSender = _msgSender();
        if (l.proposer != msgSender) revert Unauthorized();
        if (!l.status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (l.crowdfundEndAt > block.timestamp) revert CrowdfundEnded();
        if (_param.speakers.length == 0 || _param.speakers.length >= 100) revert InvalidSpeakerNumber();
        if (
            _param.speakers.length != _param.fees.length ||
            _param.fees.length != _param.providers.length ||
            _param.providers.length != _param.handles.length
        ) revert InvalidArrayArguments();
        
        delete logoSpeakers[_param.logoId]; // Reset to default (no speakers)

        uint256 speakerFeesSum;
        for (uint i = 0; i < _param.speakers.length; i++) {
            speakerFeesSum += _param.fees[i];
            Speaker memory s = Speaker({
                addr: _param.speakers[i],
                fee: _param.fees[i],
                provider: _param.providers[i],
                handle: _param.handles[i],
                status: SpeakerStatus.Pending
            });
            logoSpeakers[_param.logoId].push(s);
        }        
        {
            uint256 communityFee = IDLogosOwner(dLogosOwner).communityFee();
            if (IDLogosOwner(dLogosOwner).isZeroFeeProposer(msgSender)) {
                if (
                    communityFee + l.proposerFee + speakerFeesSum 
                    != 
                    PERCENTAGE_SCALE
                ) revert FeeSumNotMatch();
            } else {
                if (
                    IDLogosOwner(dLogosOwner).dLogosFee() + communityFee + l.proposerFee + speakerFeesSum
                    != 
                    PERCENTAGE_SCALE
                ) revert FeeSumNotMatch();
            }
        }

        emit SpeakersSet(msgSender, _param.speakers, _param.fees, _param.providers, _param.handles);
    }

    /**
     * @dev Set status of a speaker.
     */
    function setSpeakerStatus(
        uint256 _logoId,
        uint8 _speakerStatus
    ) external override whenNotPaused validLogoId(_logoId) {
        // Speaker status should be either Accepted or Rejected
        if (_speakerStatus == 0) revert InvalidSpeakerStatus();
        Logo memory l = logos[_logoId];
        if (!l.status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (l.crowdfundEndAt > block.timestamp) revert CrowdfundEnded();

        address msgSender = _msgSender();
        Speaker[] memory speakers = logoSpeakers[_logoId];
        for (uint256 i = 0; i < speakers.length; i++) {
            if (address(speakers[i].addr) == msgSender) {
                logoSpeakers[_logoId][i].status = SpeakerStatus(_speakerStatus);
                emit SpeakerStatusSet(_logoId, msgSender, _speakerStatus);
                break;
            }
        }
    }

    /**
     * @dev Return the list of speakers for a Logo.
     */
    function getSpeakersForLogo(uint256 _logoId) external override view returns (Speaker[] memory) {
        return logoSpeakers[_logoId];
    }

    /**
     * @dev Set date for a conversation.
     */
    function setDate(
        uint256 _logoId,
        uint _scheduledAt
    ) external override whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        address msgSender = _msgSender();
        if (l.proposer != msgSender) revert Unauthorized();
        if (l.status.isUploaded) revert LogoUploaded();
        if (l.status.isDistributed) revert LogoDistributed();
        if (l.status.isRefunded) revert LogoRefunded();
        if (l.crowdfundEndAt > block.timestamp) revert CrowdfundEnded();
        if (_scheduledAt <= block.timestamp) revert InvalidScheduleTime();

        Speaker[] memory speakers = logoSpeakers[_logoId];
        // Need to be sure the logo has more than one speaker
        if (speakers.length == 0) revert InvalidSpeakerNumber();
        // Need to be sure all speakers accepted
        for (uint256 i = 0; i < speakers.length; i++) {
            if (speakers[i].status != SpeakerStatus.Accepted) revert NotAllSpeakersAccepted();
        }
        
        logos[_logoId].scheduledAt = _scheduledAt;
        logos[_logoId].status.isCrowdfunding = false; // Close crowdfund.
        emit DateSet(msgSender, _scheduledAt);
    }

    /**
     * @dev Sets media URL for a Logo.
     */
    function setMediaAsset(
        uint256 _logoId,
        string calldata _mediaAssetURL
    ) external override whenNotPaused validLogoId(_logoId) {
        Logo memory ml = logos[_logoId];
        address msgSender = _msgSender();
        if (ml.proposer != msgSender) revert Unauthorized();
        if (ml.status.isDistributed) revert LogoDistributed();
        if (ml.status.isRefunded) revert LogoRefunded();
        if (ml.scheduledAt == 0) revert LogoNotScheduled();
        if (ml.crowdfundEndAt > block.timestamp) revert CrowdfundEnded();
        
        Logo storage sl = logos[_logoId];
        sl.mediaAssetURL = _mediaAssetURL;
        sl.status.isUploaded = true;
        sl.rejectionDeadline = block.timestamp + IDLogosOwner(dLogosOwner).rejectionWindow() * 1 days;

        emit MediaAssetSet(msgSender, _mediaAssetURL);
    }

    /**
     * @dev Distribute rewards to the Splits contract.
     * Create splits and distribute in 1 tx.
     */
    function distributeRewards(
        uint256 _logoId
    ) external override nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        address msgSender = _msgSender();
        if (l.proposer != msgSender) revert Unauthorized();
        if (l.status.isDistributed) revert LogoDistributed();
        if (l.status.isRefunded) revert LogoRefunded();
        if (!l.status.isUploaded) revert LogoNotUploaded();
        if (block.timestamp < l.rejectionDeadline) revert RejectionDeadlineNotPassed();

        uint256 totalRewards = IDLogosBacker(dLogosBacker).logoRewards(_logoId);
        address splitForAffiliate;
        address splitForSpeaker;        

        if (totalRewards != 0) {
            SplitV2Lib.Split memory splitParam;
            // PushSplit for affiliate fee distribution
            uint256 totalRefRewards;

            {
                // Prepare params to call DLogosSplitsHelper
                (totalRefRewards, splitParam) = DLogosSplitsHelper.getAffiliatesSplitInfo(
                    IDLogosBacker(dLogosBacker).getBackersForLogo(_logoId), 
                    IDLogosOwner(dLogosOwner).affiliateFee()
                );

                if (totalRewards < totalRefRewards) revert AffiliateRewardsExceeded();
            }

            splitForAffiliate = DLogosSplitsHelper.deploySplitV2AndDistribute(splitParam, totalRefRewards);

            // PushSplit for dlogos, community and speaker fee distribution
            DLogosSplitsHelper.GetSpeakersSplitInfoParam memory param = DLogosSplitsHelper.GetSpeakersSplitInfoParam({
                speakers: logoSpeakers[_logoId],
                dLogos: IDLogosOwner(dLogosOwner).dLogos(),
                community: IDLogosOwner(dLogosOwner).community(),
                proposer: l.proposer,
                isZeroFeeProposer: IDLogosOwner(dLogosOwner).isZeroFeeProposer(msgSender),
                dLogosFee: IDLogosOwner(dLogosOwner).dLogosFee(),
                communityFee: IDLogosOwner(dLogosOwner).communityFee(),
                proposerFee: l.proposerFee

            });
            splitParam = DLogosSplitsHelper.getSpeakersSplitInfo(param);
            splitForSpeaker = DLogosSplitsHelper.deploySplitV2AndDistribute(splitParam, totalRewards - totalRefRewards);
        }     
        
        Logo storage sl = logos[_logoId];
        sl.status.isDistributed = true;
        sl.splitForSpeaker = splitForSpeaker;
        sl.splitForAffiliate = splitForAffiliate;

        emit RewardsDistributed(msgSender, splitForSpeaker, splitForAffiliate, totalRewards);
    }    

    /**
     * @dev Pause or unpause the contract
     * Only `owner` can call
     */
    function pauseOrUnpause(bool _pause) external override onlyOwner {
        if (_pause) {
            super._pause();
        } else {
            super._unpause();
        }
    }

    // ----------------------------------------------Biconomy meta tx helpers----------------------------------------------
    /**
     * @dev Override of `trustedForwarder()`
     */
    function trustedForwarder() public view override(ERC2771ContextUpgradeable, ForwarderSetterUpgradeable) returns (address) {
        return ForwarderSetterUpgradeable.trustedForwarder();
    }
    
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (uint256) {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }
}
