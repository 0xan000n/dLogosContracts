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

    // Constants
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // address of native token, inline with ERC7528
    uint256 public constant PERCENTAGE_SCALE = 1e6;
    uint256 public constant PROPOSER_FEE = 5 * 1e4; // Logo proposer fee 5%

    /// STORAGE
    address public pushSplitFactory;
    address public dLogos;
    address public community;
    uint256 public dLogosFee; // DLogos (company) fee
    uint256 public communityFee; // Community fee
    uint256 public override logoId; // Global Logo ID
    uint16 public override rejectThreshold; // Backer rejection threshold in BPS
    uint8 public override durationThreshold; // Max crowdfunding duration
    mapping(uint256 => Logo) public logos; // Mapping of Owner addresses to Logo ID to Logo info
    mapping(uint256 => mapping(address => Backer)) public logoBackers; // Mapping of Logo ID to address to Backer
    mapping(uint256 => EnumerableSet.AddressSet) private _logoBackerAddresses;
    mapping(uint256 => Speaker[]) public logoSpeakers; // Mapping of Logo ID to list of Speakers
    mapping(uint256 => uint256) public logoRewards; // Mapping of Logo ID to accumulated rewards
    mapping(uint256 => uint256) public logoRejectedFunds; // Mapping of Logo ID to accumulated rejected funds
    mapping(address => bool) public zeroFeeProposers; // Mapping of proposer address to zero fee status

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
        logoId = 1; // Starting from 1
        rejectThreshold = 5000; // 50%
        durationThreshold = 60; // 60 days        
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
    // TODO allow direct Eth deposit?
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
    function setDurationThreshold(uint8 _durationThreshold) external override onlyOwner {
        if (_durationThreshold == 0 || _durationThreshold >= 100) revert InvalidDurationThreshold();

        durationThreshold = _durationThreshold;
        emit DurationThresholdUpdated(_durationThreshold);
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

    function setZeroFeeProposers(
        address[] calldata _proposers,
        bool[] calldata _statuses
    ) external onlyOwner {
        if (_proposers.length != _statuses.length) revert InvalidArrayArguments();

        for (uint256 i = 0; i < _proposers.length; i++) {
            zeroFeeProposers[_proposers[i]] = _statuses[i];
        }

        emit ZeroFeeProposersSet(_proposers, _statuses);
    }

    /**
     * @dev Create a new Logo onchain.
     */
    function createLogo(
        string calldata _title,
        uint8 _crowdfundNumberOfDays
    ) external override whenNotPaused returns (uint256) {
        if (bytes(_title).length == 0) revert EmptyString();
        if (_crowdfundNumberOfDays > durationThreshold) revert CrowdfundDurationExceeded();

        bool isZeroFee = zeroFeeProposers[msg.sender];
        uint256 _logoId = logoId;
        logos[_logoId] = Logo({
            id: _logoId,
            title: _title,
            proposer: msg.sender,
            proposerFee: isZeroFee? 0 : PROPOSER_FEE,
            scheduledAt: 0,
            mediaAssetURL: "",
            minimumPledge: 10000000000000, // 0.00001 ETH
            crowdfundStartAt: block.timestamp,
            crowdfundEndAt: block.timestamp + _crowdfundNumberOfDays * 1 days,
            splits: address(0),
            rejectionDeadline: 0,
            status: Status({
                isCrowdfunding: true,
                isUploaded: false,
                isDistributed: false,
                isRefunded: false
            })
        });
        emit LogoCreated(msg.sender, _logoId, block.timestamp);
        // TODO what is toggle?
        emit CrowdfundToggled(msg.sender, true);
        return logoId++; // Return and Increment Global Logo ID
    }

    function setProposerFee(
        uint256 _logoId,
        uint256 _proposerFee
    ) external whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        if (zeroFeeProposers[msg.sender]) revert ZeroFeeProposer();
        // Proposer can set his fee only during crowdfunding
        if (!logos[_logoId].status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (dLogosFee + communityFee + _proposerFee > PERCENTAGE_SCALE) revert FeeExceeded();

        logos[_logoId].proposerFee = _proposerFee;
        emit ProposerFeeUpdated(msg.sender, _logoId, _proposerFee);
    }

    /**
     * @dev Toggle crowdfund for Logo. Only the proposer of the Logo is allowed to toggle a crowdfund.
     */
    // TODO toggle means pause/unpause?
    function toggleCrowdfund(
        uint256 _logoId
    ) external override whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        Logo memory l = logos[_logoId];
        if (l.status.isUploaded) revert LogoUploaded();
        // TODO check again: first check includes following 2 checks
        // if (l.status.isDistributed) revert LogoDistributed();
        // if (l.status.isRefunded) revert LogoRefunded();
        
        logos[_logoId].status.isCrowdfunding = !l.status.isCrowdfunding;
        emit CrowdfundToggled(msg.sender, !l.status.isCrowdfunding);
    }

    /**
     * @dev Crowdfund.
     */
    function crowdfund(
        uint256 _logoId
    ) external override payable nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];

        if (!l.status.isCrowdfunding) revert LogoNotCrowdfunding();
        if (msg.value < l.minimumPledge) revert InsufficientFunds();
                
        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);

        if (isBacker) {
            Backer storage backer = logoBackers[_logoId][msg.sender];
            unchecked {
                backer.amount += msg.value;
            }
        } else {
            // Record the value sent to the address.
            if (_logoBackerAddresses[_logoId].length() >= 1000) revert TooManyBackers();

            Backer memory b = Backer({
                addr: msg.sender,
                amount: msg.value,
                votesToReject: false
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
        // TODO check again
        if (
            !l.status.isCrowdfunding &&
            !l.status.isRefunded &&
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
    // TODO add time check
    function reject(uint256 _logoId) external override whenNotPaused validLogoId(_logoId) {
        /* Only Mainnet
        Logo memory l = logos[_logoId];
        require(block.timestamp < l.rejectionDeadline, "Rejection deadline has passed.");
        */

        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);

        if (!isBacker) revert Unauthorized();

        Backer memory backer = logoBackers[_logoId][msg.sender];
        // Increase rejected funds.
        unchecked {
            logoRejectedFunds[_logoId] = logoRejectedFunds[_logoId] + backer.amount;
        }
        logoBackers[_logoId][msg.sender].votesToReject = true;
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
    // TODO add time condition
    function setSpeakers(
        uint256 _logoId,
        address[] calldata _speakers,
        uint256[] calldata _fees,
        string[] calldata _providers,
        string[] calldata _handles
    ) external override whenNotPaused validLogoId(_logoId) onlyLogoProposer(_logoId) {
        if (_speakers.length == 0 || _speakers.length >= 100) revert InvalidSpeakers();
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
        if (dLogosFee + communityFee + logos[_logoId].proposerFee + speakerFeesSum > PERCENTAGE_SCALE) revert FeeExceeded();

        emit SpeakersSet(msg.sender, _speakers, _fees, _providers, _handles);
    }

    /**
     * @dev Set status of a speaker.
     */
    // TODO add time condition
    function setSpeakerStatus(
        uint256 _logoId,
        uint8 _speakerStatus
    ) external override whenNotPaused validLogoId(_logoId) {
        // Speaker status should be either Accepted or Rejected
        if (_speakerStatus == 0) revert InvalidSpeakerStatus();

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
        // TODO able to set media asset only after logo uploaded?
                
        Logo storage sl = logos[_logoId];
        sl.mediaAssetURL = _mediaAssetURL;
        sl.status.isCrowdfunding = false; // Close crowdfund.
        sl.status.isUploaded = true;
        sl.rejectionDeadline = block.timestamp + 7 * 1 days;

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
        // TODO allow distribution only after logo uploaded?
        
        // Create a new PushSplit
        Speaker[] memory speakers = logoSpeakers[_logoId];
        address[] memory recipients = new address[](speakers.length + 3);
        uint256[] memory allocations = new uint256[](speakers.length + 3);
        // Assign recipients array
        recipients[0] = dLogos;
        recipients[1] = community;
        recipients[2] = l.proposer;
        for (uint256 i = 3; i < recipients.length; i++) {
            recipients[i] = speakers[i - 3].addr;
        }
        // Assign allocations array
        uint256 totalAllocation;
        allocations[0] = dLogosFee;
        allocations[1] = communityFee;
        allocations[2] = l.proposerFee;
        totalAllocation += dLogosFee + communityFee + l.proposerFee;
        for (uint256 i = 3; i < allocations.length; i++) {
            allocations[i] = speakers[i - 3].fee;
            totalAllocation += speakers[i - 3].fee;
        }
        // Check total allocation equals to 1e6
        if (totalAllocation > PERCENTAGE_SCALE) revert TotalAllocationExceeded();
        // TODO add last allocation to fill margin        

        SplitV2Lib.Split memory splitParams = SplitV2Lib.Split({
            recipients: recipients,
            allocations: allocations,
            totalAllocation: PERCENTAGE_SCALE,
            distributionIncentive: 0 // set to 0
        });

        // Split owner can pause and unpause the contract
        // Split creator does not mean anything
        address split = IPushSplitFactory(pushSplitFactory).createSplit(splitParams, owner(), address(this));
        emit PushSplitCreated(split, splitParams, owner(), address(this));

        // Send Eth to PushSplit
        uint256 totalRewards = logoRewards[_logoId];
        (bool success, ) = payable(split).call{value: totalRewards}("");        
        if (!success) revert EthTransferFailed();

        // TODO check distributor rewards for msg.sender
        IPushSplit(split).distribute(
            splitParams,
            NATIVE_TOKEN,
            address(0) // distributor address
        );

        /* Only Mainnet
        require(block.timestamp > l.rejectionDeadline, "Rewards can only be distributed after rejection deadline has passed.");
        */
        
        Logo storage sl = logos[_logoId];
        sl.status.isDistributed = true;
        sl.splits = split;
        sl.status.isCrowdfunding = false; // Close crowdfund
        // sl.rejectionDeadline = block.timestamp + 7 * 1 days;

        emit RewardsDistributed(msg.sender, split, totalRewards);
    }

    /**
     * @dev Private function for polling backers, weighted by capital.
     */
    function _pollBackersForRefund(uint256 _logoId) private view returns (bool) {
        uint256 threshold = logoRejectedFunds[_logoId] * 10_000 / logoRewards[_logoId]; // BPS
        return threshold > rejectThreshold;
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
}
