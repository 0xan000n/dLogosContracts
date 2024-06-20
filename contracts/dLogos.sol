// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IDLogos} from "./interfaces/IdLogos.sol";
import {IPushSplitFactory} from "./splitsV2/interfaces/IPushSplitFactory.sol";
import {IPushSplit} from "./splitsV2/interfaces/IPushSplit.sol";
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
contract DLogos is IDLogos, Ownable2StepUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// CONSTANTS
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // Address of native token, inline with ERC7528
    uint256 public constant PERCENTAGE_SCALE = 1e6;
    uint256 public constant MAX_AFFILIATE_FEE = 2 * 1e5; // Max 20%

    /// STORAGE
    address public pushSplitFactory;
    address public dLogos;
    address public community;
    uint256 public dLogosFee; // DLogos (Labs) fee
    uint256 public communityFee; // Community fee
    uint256 public affiliateFee; // Affiliate fee
    uint256 public override logoId; // Global Logo ID
    uint16 public override rejectThreshold; // Backer rejection threshold in BPS
    uint8 public override maxDuration; // Max crowdfunding duration
    uint8 public rejectionWindow; // Reject deadline in days
    EnumerableSet.AddressSet private _zeroFeeProposers; // List of proposers who dLogos does not charge fees
    mapping(uint256 => Logo) public logos; // Mapping of Owner addresses to Logo ID to Logo info
    mapping(uint256 => mapping(address => Backer)) public logoBackers; // Mapping of Logo ID to address to Backer
    mapping(uint256 => EnumerableSet.AddressSet) private _logoBackerAddresses;
    mapping(uint256 => Speaker[]) public logoSpeakers; // Mapping of Logo ID to list of Speakers
    mapping(uint256 => uint256) public logoRewards; // Mapping of Logo ID to accumulated rewards
    mapping(uint256 => uint256) public logoRejectedFunds; // Mapping of Logo ID to accumulated rejected funds

    function initialize(
        address _pushSplitFactory,
        address _dLogos,
        address _community
    ) external override initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        
        if (_pushSplitFactory == address(0) || _dLogos == address(0) || _community == address(0)) revert ZeroAddress();

        pushSplitFactory = _pushSplitFactory;
        dLogos = _dLogos;
        community = _community;
        dLogosFee = 1e5; // 10%
        communityFee = 1e5; // 10%
        affiliateFee = 5 * 1e4; // 5%        
        logoId = 1; // Starting from 1
        rejectThreshold = 5000; // 50%
        maxDuration = 60; // 60 days
        rejectionWindow = 7; // 7 days        
    }

    /// MODIFIERS
    modifier validLogoId(uint256 _logoId) {
        if (_logoId >= logoId) revert InvalidLogoId();
        _;
    }

    modifier onlyLogoProposer(uint256 _logoId) {
        if (logos[_logoId].proposer != msg.sender) revert Unauthorized();
        _;
    }

    /// FUNCTIONS
    // TODO allow direct Eth deposit? will decide after meta tx r&d is complete
    receive() external payable {}
    
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

    function setRejectionWindow(uint8 _rejectionWindow) external onlyOwner {
        // Zero possible
        rejectionWindow = _rejectionWindow;
        emit RejectinoWindowUpdated(_rejectionWindow);
    }

    function setDLogosAddress(address _dLogos) external onlyOwner {
        if (_dLogos == address(0)) revert ZeroAddress();

        dLogos = _dLogos;
        emit DLogosAddressUpdated(_dLogos);
    }

    function setCommunityAddress(address _community) external onlyOwner {
        if (_community == address(0)) revert ZeroAddress();

        community = _community;
        emit CommunityAddressUpdated(_community);
    }

    function setDLogosFee(uint256 _dLogosFee) external onlyOwner {
        if (_dLogosFee > PERCENTAGE_SCALE) revert FeeExceeded();

        dLogosFee = _dLogosFee;
        emit DLogosFeeUpdated(_dLogosFee);
    }

    function setCommunityFee(uint256 _communityFee) external onlyOwner {
        if (_communityFee + dLogosFee > PERCENTAGE_SCALE) revert FeeExceeded();

        communityFee = _communityFee;
        emit CommunityFeeUpdated(_communityFee);
    }  

    function setAffiliateFee(uint256 _affiliateFee) external onlyOwner {
        if (_affiliateFee > MAX_AFFILIATE_FEE) revert FeeExceeded();

        affiliateFee = _affiliateFee;
        emit AffiliateFeeUpdated(_affiliateFee);
    }

    function setZeroFeeProposers(
        address[] calldata _proposers,
        bool[] calldata _statuses
    ) external onlyOwner {
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
     * @dev Create a new Logo onchain.
     */
    function createLogo(
        uint256 _proposerFee,
        string calldata _title,
        uint8 _crowdfundNumberOfDays
    ) external override whenNotPaused returns (uint256) {
        if (bytes(_title).length == 0) revert EmptyString();
        if (_crowdfundNumberOfDays > maxDuration) revert CrowdfundDurationExceeded();
        if (_isZeroFeeProposer(msg.sender)) {
            if (_proposerFee + communityFee > PERCENTAGE_SCALE) revert FeeExceeded();
        } else {
            if (_proposerFee + dLogosFee + communityFee > PERCENTAGE_SCALE) revert FeeExceeded();
        }

        uint256 _logoId = logoId;
        logos[_logoId] = Logo({
            id: _logoId,
            title: _title,
            proposer: msg.sender,
            proposerFee: _proposerFee,
            scheduledAt: 0,
            mediaAssetURL: "",
            minimumPledge: 10000000000000, // 0.00001 ETH
            crowdfundStartAt: block.timestamp,
            crowdfundEndAt: block.timestamp + _crowdfundNumberOfDays * 1 days,
            splitForAffiliate: address(0),
            splitForSpeaker: address(0),
            rejectionDeadline: 0,
            status: Status({
                isCrowdfunding: true,
                isUploaded: false,
                isDistributed: false,
                isRefunded: false
            })
        });
        emit LogoCreated(msg.sender, _logoId, block.timestamp);
        emit CrowdfundToggled(msg.sender, true);
        return logoId++; // Return and Increment Global Logo ID
    }

    /**
     * @dev Toggle crowdfund for Logo. Only the proposer of the Logo is allowed to toggle a crowdfund.
     */
    function toggleCrowdfund(
        uint256 _logoId
    ) external override whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        Logo memory l = logos[_logoId];
        if (l.scheduledAt != 0) revert CrowdfundEnded();
        
        logos[_logoId].status.isCrowdfunding = !l.status.isCrowdfunding;
        emit CrowdfundToggled(msg.sender, !l.status.isCrowdfunding);
    }

    /**
     * @dev Crowdfund.
     */
    function crowdfund(
        uint256 _logoId,
        address _referrer
    ) external override payable nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];

        if (!l.status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (msg.value < l.minimumPledge) revert InsufficientFunds();
                
        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);

        if (isBacker) {
            // Ignore `_referrer` because it was already set
            Backer storage backer = logoBackers[_logoId][msg.sender];
            unchecked {
                backer.amount += msg.value;
            }
        } else {
            // Record the value sent to the address.
            if (_logoBackerAddresses[_logoId].length() >= 1000) revert TooManyBackers();

            Backer memory b = Backer({
                addr: msg.sender,
                referrer: _referrer, // Zero address possible
                amount: msg.value
            });
            bool added = _logoBackerAddresses[_logoId].add(msg.sender);

            if (!added) revert AddBackerFailed();
            
            logoBackers[_logoId][msg.sender] = b;
        }

        // Increase total rewards of Logo.
        unchecked {
            logoRewards[_logoId] = logoRewards[_logoId] + msg.value;
        }
        emit Crowdfund(_logoId, msg.sender, msg.value);
    }

    /**
     * @dev Set minimum pledge for a conversation.
     */
    function setMinimumPledge(
        uint256 _logoId,
        uint256 _minimumPledge
    ) external override whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        Logo memory l = logos[_logoId];
        if (!l.status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (_minimumPledge == 0) revert NotZero();

        logos[_logoId].minimumPledge = _minimumPledge;
        emit MinimumPledgeSet(msg.sender, _minimumPledge);
    }

    /**
     * @dev Withdraw your pledge from a Logo.
     */
    function withdrawFunds(uint256 _logoId) external override nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        if (
            (l.scheduledAt != 0 && !l.status.isRefunded) ||
            l.status.isDistributed
        ) revert LogoFundsCannotBeWithdrawn();
        
        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);

        if (!isBacker) revert Unauthorized();

        Backer memory backer = logoBackers[_logoId][msg.sender];
        
        if (backer.amount == 0) revert InsufficientFunds();
        if (logoRewards[_logoId] < backer.amount) revert InsufficientLogoReward();
        
        bool removed = _logoBackerAddresses[_logoId].remove(msg.sender);

        if (!removed) revert RemoveBackerFailed();
        
        delete logoBackers[_logoId][msg.sender];
        // Decrease total rewards of Logo.
        logoRewards[_logoId] = logoRewards[_logoId] - backer.amount;
        (bool success, ) = payable(msg.sender).call{value: backer.amount}("");

        if (!success) revert EthTransferFailed();
        
        emit FundsWithdrawn(msg.sender, backer.amount);
    }

    /**
     * @dev Allows a backer to reject an uploaded asset.
     */
    function reject(uint256 _logoId) external override whenNotPaused validLogoId(_logoId) {
        /* Only Mainnet
        Logo memory l = logos[_logoId];
        // TODO check again
        if (l.rejectionDeadline > 0) {
            if (block.timestamp > l.rejectionDeadline) revert RejectionDeadlinePassed();
        }
        */

        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);

        if (!isBacker) revert Unauthorized();

        Backer memory backer = logoBackers[_logoId][msg.sender];
        // Increase rejected funds.
        unchecked {
            logoRejectedFunds[_logoId] = logoRejectedFunds[_logoId] + backer.amount;
        }
        
        emit RejectionSubmitted(_logoId, msg.sender);
    }

    /**
     * @dev Issue refund of the Logo.
     */
    function refund(uint256 _logoId) external override whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        if (l.status.isDistributed) revert LogoDistributed();

        bool c1 = l.proposer == msg.sender; // Case 1: Logo proposer can refund whenever.
        bool c2 = block.timestamp > l.crowdfundEndAt; // Case 2: Crowdfund end date reached and not distributed.
        bool c3 = l.scheduledAt != 0 &&
            (block.timestamp > l.scheduledAt + 7 * 1 days) &&
            !l.status.isUploaded; // Case 3: >7 days have passed since schedule date and no asset uploaded.
        bool c4 = _pollBackersForRefund(_logoId); // Case 4: >50% of backer funds reject upload.
        
        if (!c1 && !c2 && !c3 && !c4) revert NoRefundConditionsMet();

        logos[_logoId].status.isRefunded = true;

        emit RefundInitiated(_logoId, c1, c2, c3, c4);
    }

    /**
     * @dev Return the list of backers for a Logo.
     */
    function getBackersForLogo(uint256 _logoId) external override view returns (Backer[] memory) {
        EnumerableSet.AddressSet storage backerAddresses = _logoBackerAddresses[_logoId];
        address[] memory backerArray = backerAddresses.values();
        Backer[] memory backers = new Backer[](backerArray.length);
        for (uint256 i = 0; i < backerArray.length; i++) {
            backers[i] = logoBackers[_logoId][backerArray[i]];
        }
        return backers;
    }

    /**
     * @dev Set speakers for a Logo.
     */
    function setSpeakers(
        uint256 _logoId,
        address[] calldata _speakers,
        uint256[] calldata _fees,
        string[] calldata _providers,
        string[] calldata _handles
    ) external override whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        if (!logos[_logoId].status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (_speakers.length == 0 || _speakers.length >= 100) revert InvalidSpeakerNumber();
        if (
            _speakers.length != _fees.length ||
            _fees.length != _providers.length ||
            _providers.length != _handles.length
        ) revert InvalidArrayArguments();
        
        delete logoSpeakers[_logoId]; // Reset to default (no speakers)

        uint256 speakerFeesSum;
        for (uint i = 0; i < _speakers.length; i++) {
            speakerFeesSum += _fees[i];
            Speaker memory s = Speaker({
                addr: _speakers[i],
                fee: _fees[i],
                provider: _providers[i],
                handle: _handles[i],
                status: SpeakerStatus.Pending
            });
            logoSpeakers[_logoId].push(s);
        }

        if (_isZeroFeeProposer(msg.sender)) {
            if (
                communityFee + logos[_logoId].proposerFee + speakerFeesSum 
                != 
                PERCENTAGE_SCALE
            ) revert FeeSumNotMatch();
        } else {
            if (
                dLogosFee + communityFee + logos[_logoId].proposerFee + speakerFeesSum 
                != 
                PERCENTAGE_SCALE
            ) revert FeeSumNotMatch();
        }

        emit SpeakersSet(msg.sender, _speakers, _fees, _providers, _handles);
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
        if (!logos[_logoId].status.isCrowdfunding) revert LogoNotCrowdfunding();

        Speaker[] memory speakers = logoSpeakers[_logoId];
        for (uint256 i = 0; i < speakers.length; i++) {
            if (address(speakers[i].addr) == msg.sender) {
                logoSpeakers[_logoId][i].status = SpeakerStatus(_speakerStatus);
                emit SpeakerStatusSet(_logoId, msg.sender, _speakerStatus);
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
    ) external override whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        Logo memory l = logos[_logoId];
        if (l.status.isUploaded) revert LogoUploaded();
        if (l.status.isDistributed) revert LogoDistributed();
        if (l.status.isRefunded) revert LogoRefunded();
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
        emit DateSet(msg.sender, _scheduledAt);
    }

    /**
     * @dev Sets media URL for a Logo.
     */
    function setMediaAsset(
        uint256 _logoId,
        string calldata _mediaAssetURL
    ) external override whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        Logo memory ml = logos[_logoId];
        if (ml.status.isDistributed) revert LogoDistributed();
        if (ml.status.isRefunded) revert LogoRefunded();
        
        Logo storage sl = logos[_logoId];
        sl.mediaAssetURL = _mediaAssetURL;
        sl.status.isCrowdfunding = false; // Close crowdfund.
        sl.status.isUploaded = true;
        sl.rejectionDeadline = block.timestamp + rejectionWindow * 1 days;

        emit MediaAssetSet(msg.sender, _mediaAssetURL);
    }

    /**
     * @dev Distribute rewards to the Splits contract.
     * Create splits and distribute in 1 tx.
     */
    function distributeRewards(
        uint256 _logoId
    ) external override nonReentrant whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        Logo memory l = logos[_logoId];
        if (l.status.isDistributed) revert LogoDistributed();
        if (l.status.isRefunded) revert LogoRefunded();
        if (!l.status.isUploaded) revert LogoNotUploaded();
        if (block.timestamp < l.rejectionDeadline) revert RejectionDeadlineNotPassed();

        uint256 totalRewards = logoRewards[_logoId];
        address splitForAffiliate;
        address splitForSpeaker;        

        if (totalRewards != 0) {
            SplitV2Lib.Split memory splitParams;
            // PushSplit for affiliate fee distribution
            (
                uint256 totalRefRewards, 
                address[] memory referrers, 
                uint256[] memory refAllocations
            ) = _getAffiliates(_logoId);

            if (totalRewards < totalRefRewards) revert AffiliateRewardsExceeded();

            splitParams = SplitV2Lib.Split({
                recipients: referrers,
                allocations: refAllocations,
                totalAllocation: PERCENTAGE_SCALE,
                distributionIncentive: 0 // set to 0
            });
            // Deploy
            splitForAffiliate = IPushSplitFactory(pushSplitFactory).createSplit(splitParams, owner(), address(this));
            emit SplitForAffiliateCreated(splitForAffiliate, splitParams, owner(), address(this));
            // Send Eth to PushSplit
            (bool success, ) = payable(splitForAffiliate).call{value: totalRefRewards}("");        
            if (!success) revert EthTransferFailed();
            // Distribute
            IPushSplit(splitForAffiliate).distribute(
                splitParams,
                NATIVE_TOKEN,
                address(0) // distributor address
            );

            // PushSplit for dlogos, community and speaker fee distribution
            Speaker[] memory speakers = logoSpeakers[_logoId];
            address[] memory recipients = new address[](3 + speakers.length);
            uint256[] memory allocations = new uint256[](3 + speakers.length);
            // Assign recipients array
            recipients[0] = dLogos;
            recipients[1] = community;
            recipients[2] = l.proposer;
            for (uint256 i = 0; i < speakers.length; i++) {
                recipients[i + 3] = speakers[i].addr;
            }
            // Assign allocations array
            uint256 totalAllocation;
            if (_isZeroFeeProposer(msg.sender)) {
                allocations[0] = 0;
            } else {
                allocations[0] = dLogosFee;
            }
            allocations[1] = communityFee;
            allocations[2] = l.proposerFee;
            totalAllocation += dLogosFee + communityFee + l.proposerFee;
            for (uint256 i = 0; i < speakers.length; i++) {
                allocations[i + 3] = speakers[i].fee;
                totalAllocation += speakers[i].fee;
            }
            // Check total allocation equals to 1e6
            if (totalAllocation != PERCENTAGE_SCALE) revert TotalAllocationExceeded();

            splitParams = SplitV2Lib.Split({
                recipients: recipients,
                allocations: allocations,
                totalAllocation: PERCENTAGE_SCALE,
                distributionIncentive: 0 // set to 0
            });
            // Deploy
            // Split owner can pause and unpause the contract
            // Split creator does not mean anything
            splitForSpeaker = IPushSplitFactory(pushSplitFactory).createSplit(splitParams, owner(), address(this));
            emit SplitForSpeakerCreated(splitForSpeaker, splitParams, owner(), address(this));
            // Send Eth to PushSplit
            (success, ) = payable(splitForSpeaker).call{value: totalRewards - totalRefRewards}("");        
            if (!success) revert EthTransferFailed();
            // Distribute
            IPushSplit(splitForSpeaker).distribute(
                splitParams,
                NATIVE_TOKEN,
                address(0) // distributor address
            );
        }     
        
        Logo storage sl = logos[_logoId];
        sl.status.isDistributed = true;
        sl.splitForSpeaker = splitForSpeaker;
        sl.splitForAffiliate = splitForAffiliate;

        emit RewardsDistributed(msg.sender, splitForSpeaker, splitForAffiliate, totalRewards);
    }    

    /**
     * @dev Pause the contract
     * Only `owner` can call
     */
    function pause() external override onlyOwner {
        super._pause();
    }

    /**
     * @dev Unpause the contract
     * Only `owner` can call
     */
    function unpause() external override onlyOwner {
        super._unpause();
    }

    /**
     * @dev Query zero fee proposer status
     */
    function isZeroFeeProposer(address _proposer) external view returns(bool) {
        return _isZeroFeeProposer(_proposer);
    }

    /**
     * @dev Private function for polling backers, weighted by capital.
     */
    function _pollBackersForRefund(uint256 _logoId) private view returns (bool) {
        uint256 threshold = logoRejectedFunds[_logoId] * 10_000 / logoRewards[_logoId]; // BPS
        return threshold > rejectThreshold;
    }

    function _isZeroFeeProposer(address _proposer) private view returns (bool) {
        return _zeroFeeProposers.contains(_proposer);
    }

    function _getAffiliates(uint256 _logoId) private view returns (
        uint256 totalRefRewards,
        address[] memory referrers,
        uint256[] memory allocations
    ) {
        EnumerableSet.AddressSet storage backerAddresses = _logoBackerAddresses[_logoId];
        address[] memory backerArray = backerAddresses.values();
        referrers = new address[](backerArray.length + 1);
        allocations  = new uint256[](backerArray.length + 1);
        uint256[] memory refRewards  = new uint256[](backerArray.length + 1);

        uint256 _totalAllocation;

        unchecked {
            for (uint256 i = 0; i < backerArray.length; i++) {
                Backer memory b = logoBackers[_logoId][backerArray[i]];
                address r = b.referrer;
                referrers[i] = r;
                if (r == address(0)) {
                    refRewards[i] = 0;
                } else {
                    refRewards[i] = b.amount * affiliateFee / PERCENTAGE_SCALE;
                }

                totalRefRewards += refRewards[i];
            }

            for (uint256 i = 0; i < backerArray.length; i++) {
                allocations[i] = refRewards[i] * PERCENTAGE_SCALE / totalRefRewards;
                _totalAllocation += allocations[i];
            }

            // Slippage
            if (_totalAllocation < PERCENTAGE_SCALE) {
                // TODO check n+1 referrer address
                referrers[backerArray.length] = address(this);
                allocations[backerArray.length] = PERCENTAGE_SCALE - _totalAllocation;
            }            
        }
    }
}
