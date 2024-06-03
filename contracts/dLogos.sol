// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IDlogos} from "./interfaces/IdLogos.sol";
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
contract Dlogos is IDlogos, Ownable, Pausable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// STORAGE
    uint256 public logoId = 1; // Global Logo ID starting from 1
    uint16 public rejectThreshold = 5000; // backer rejection threshold in BPS (50%)
    mapping(uint256 => Logo) public logos; // Mapping of Owner addresses to Logo ID to Logo info
    mapping(uint256 => mapping(address => Backer)) public logoBackers; // Mapping of Logo ID to address to Backer
    mapping(uint256 => EnumerableSet.AddressSet) private _logoBackerAddresses;
    mapping(uint256 => Speaker[]) public logoSpeakers; // Mapping of Logo ID to list of Speakers
    mapping(uint256 => uint256) public logoRewards; // Mapping of Logo ID to accumulated rewards
    mapping(uint256 => uint256) public logoRejectedFunds; // Mapping of Logo ID to accumulated rejected funds

    /// MODIFIERS
    modifier validLogoId(uint256 _logoId) {
        if (_logoId >= logoId) revert InvalidLogoId();
        _;
    }

    /// FUNCTIONS
    /**
     * @dev Set reject threshold for dLogos.
     */
    function setRejectThreshold(
        uint16 _rejectThreshold
    ) external nonReentrant onlyOwner {
        require(
            _rejectThreshold > 0 && _rejectThreshold <= 10000,
            "Reject threshold must be greater than 0 and less than 100."
        );
        rejectThreshold = _rejectThreshold;
        emit RejectThresholdUpdated(rejectThreshold);
    }

    /**
     * @dev Create a new Logo onchain.
     */
    // TODO check _crowdfundNumberOfDays limit
    function createLogo(
        string calldata _title,
        uint _crowdfundNumberOfDays
    ) external nonReentrant whenNotPaused returns (uint256) {
        if (bytes(_title).length == 0) revert EmptyString();

        logos[logoId] = Logo({
            id: logoId,
            title: _title,
            proposer: msg.sender,
            scheduledAt: 0,
            mediaAssetURL: "",
            minimumPledge: 10000000000000, // 0.00001 ETH
            crowdfundStartAt: block.timestamp,
            crowdfundEndAt: block.timestamp + _crowdfundNumberOfDays * 1 days,
            splits: address(0),
            rejectionDeadline: 0,
            status: Status({
                isUploaded: false,
                isCrowdfunding: true,
                isDistributed: false,
                isRefunded: false
            })
        });
        emit LogoCreated(msg.sender, logoId, block.timestamp);
        emit CrowdfundToggled(msg.sender, true);
        return logoId++; // Return and Increment Global Logo ID
    }

    /**
     * @dev Toggle crowdfund for Logo. Only the proposer of the Logo is allowed to toggle a crowdfund.
     */
    function toggleCrowdfund(
        uint256 _logoId
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo storage l = logos[_logoId];
        require(
            !l.status.isUploaded,
            "Cannot toggle crowdfund after Logo asset is uploaded."
        );
        require(
            !l.status.isDistributed,
            "Cannot toggle crowdfund after rewards are distributed."
        );
        require(
            !l.status.isRefunded,
            "Cannot toggle crowdfund after Logo is refunded."
        );
        require(
            l.proposer == msg.sender,
            "Only the Logo proposer is allowed to toggle crowdfund."
        );
        l.status.isCrowdfunding = !l.status.isCrowdfunding;
        emit CrowdfundToggled(msg.sender, l.status.isCrowdfunding);
    }

    /**
     * @dev Crowdfund.
     */
    function crowdfund(
        uint256 _logoId
    ) external payable nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        require(l.status.isCrowdfunding, "Crowdfund is not open.");
        require(
            !l.status.isDistributed,
            "Cannot set date after rewards are distributed."
        );
        require(
            msg.value >= l.minimumPledge,
            "Crowdfund value must be >= than the minimum pledge."
        );
        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);
        if (isBacker) {
            Backer storage backer = logoBackers[_logoId][msg.sender];
            unchecked {
                backer.amount += msg.value;
            }
        } else {
            // Record the value sent to the address.
            require(
                _logoBackerAddresses[_logoId].length() < 1000,
                "A Logo can have at most 1000 backers."
            );
            Backer memory b = Backer({
                addr: msg.sender,
                amount: msg.value,
                votesToReject: false
            });
            bool added = _logoBackerAddresses[_logoId].add(msg.sender);
            require(added, "Failed to add backer");
            logoBackers[_logoId][msg.sender] = b;
        }
        // Increase total rewards of logo
        unchecked {
            logoRewards[_logoId] = logoRewards[_logoId] + msg.value;
        }
        emit Crowdfund(msg.sender, msg.value);
    }

    /**
     * @dev Set minimum pledge for a conversation.
     */
    function setMinimumPledge(
        uint256 _logoId,
        uint256 _minimumPledge
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo storage l = logos[_logoId];
        require(
            l.status.isCrowdfunding,
            "Can only set minimum pledge during crowdfund."
        );
        require(
            l.proposer == msg.sender,
            "msg.sender is not the Logo proposer."
        );
        require(_minimumPledge > 0, "Minimum pledge must be greater than 0.");
        l.minimumPledge = _minimumPledge;
        emit MinimumPledgeSet(msg.sender, _minimumPledge);
    }

    /**
     * @dev Withdraw your pledge from a Logo.
     */
    function withdrawFunds(
        uint256 _logoId
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        require(
            l.status.isCrowdfunding ||
                l.status.isRefunded ||
                !l.status.isDistributed,
            "Logo must be crowdfunding, refunded or not distributed to withdraw."
        );
        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);
        require(isBacker, "msg.sender is not a backer.");
        Backer memory backer = logoBackers[_logoId][msg.sender];
        require(backer.amount > 0, "Backer amount must be greater than 0.");
        require(
            logoRewards[_logoId] >= backer.amount,
            "Backer amount exceeds total rewards"
        );
        bool removed = _logoBackerAddresses[_logoId].remove(msg.sender);
        require(removed, "Failed to remove backer.");
        delete logoBackers[_logoId][msg.sender];
        (bool success, ) = payable(msg.sender).call{value: backer.amount}("");
        require(success, "Withdraw failed.");
        // Decrease total rewards of logo
        logoRewards[_logoId] = logoRewards[_logoId] - backer.amount;
        emit FundsWithdrawn(msg.sender, backer.amount);
    }

    /**
     * @dev Allows a backer to reject an uploaded asset.
     */
    function reject(uint256 _logoId) external nonReentrant whenNotPaused validLogoId(_logoId) {
        /* Only Mainnet
        Logo memory l = logos[_logoId];
        require(block.timestamp < l.rejectionDeadline, "Rejection deadline has passed.");
        */
        bool isBacker = _logoBackerAddresses[_logoId].contains(msg.sender);
        require(isBacker, "msg.sender is not a backer.");
        Backer storage backer = logoBackers[_logoId][msg.sender];
        backer.votesToReject = true;
        // Increase rejected funds
        unchecked {
            logoRejectedFunds[_logoId] =
                logoRejectedFunds[_logoId] +
                backer.amount;
        }
        emit RejectionSubmitted(_logoId, msg.sender);
    }

    /**
     * @dev Issue refund of the Logo.
     */
    function refund(uint256 _logoId) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo storage l = logos[_logoId];
        require(
            !l.status.isDistributed,
            "Cannot refund after rewards are distributed."
        );
        bool c1 = l.proposer == msg.sender; // Case 1: Logo proposer can refund whenever.
        bool c2 = block.timestamp > l.crowdfundEndAt; // Case 2: Crowdfund end date reached and not distributed
        bool c3 = l.scheduledAt != 0 &&
            (block.timestamp > l.scheduledAt + 7 * 1 days) &&
            !l.status.isUploaded; // Case 3: >7 days have passed since schedule date and no asset uploaded.
        bool c4 = _pollBackersForRefund(_logoId); // Case 4: >50% of backers reject upload.
        require(c1 || c2 || c3 || c4, "No conditions met for refund.");
        l.status.isRefunded = true;
        emit RefundInitiated(_logoId, c1, c2, c3, c4);
    }

    /**
     * @dev Return the list of backers for a Logo.
     */
    function getBackersForLogo(
        uint256 _logoId
    ) external view returns (Backer[] memory) {
        EnumerableSet.AddressSet storage backerAddresses = _logoBackerAddresses[
            _logoId
        ];
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
        uint16[] calldata _fees,
        string[] calldata _providers,
        string[] calldata _handles
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo memory l = logos[_logoId];
        require(
            l.proposer == msg.sender,
            "msg.sender is not the Logo proposer."
        );
        require(_speakers.length > 0, "Please submit at least one speaker.");
        require(_speakers.length < 100, "Cannot have more than 100 speakers.");
        require(
            _speakers.length == _fees.length &&
                _fees.length == _providers.length &&
                _providers.length == _handles.length,
            "Length of calldata arrays must be equal."
        );
        delete logoSpeakers[_logoId]; // Reset to default (no speakers)
        for (uint i = 0; i < _speakers.length; i++) {
            Speaker memory s = Speaker({
                addr: _speakers[i],
                fee: _fees[i],
                provider: _providers[i],
                handle: _handles[i],
                status: SpeakerStatus.Pending
            });
            logoSpeakers[_logoId].push(s);
        }
        emit SpeakersSet(msg.sender, _speakers, _fees, _providers, _handles);
    }

    /**
     * @dev Set status of a speaker.
     */
    function setSpeakerStatus(
        uint256 _logoId,
        uint _speakerStatus
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Speaker[] memory speakers = logoSpeakers[_logoId];
        for (uint i = 0; i < speakers.length; i++) {
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
    function getSpeakersForLogo(
        uint256 _logoId
    ) external view returns (Speaker[] memory) {
        return logoSpeakers[_logoId];
    }

    /**
     * @dev Set date for a conversation.
     */
    function setDate(
        uint256 _logoId,
        uint _scheduledAt
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo storage l = logos[_logoId];
        require(
            !l.status.isUploaded,
            "Cannot set date after Logo asset is uploaded."
        );
        require(
            !l.status.isDistributed,
            "Cannot set date after rewards are distributed."
        );
        require(
            !l.status.isRefunded,
            "Cannot set date after Logo is refunded."
        );
        require(
            l.proposer == msg.sender,
            "msg.sender is not the Logo proposer."
        );
        require(
            _scheduledAt > block.timestamp,
            "Proposed date must be in the future."
        );
        l.scheduledAt = _scheduledAt;
        l.status.isCrowdfunding = false; // Close crowdfund
        emit DateSet(msg.sender, _scheduledAt);
    }

    /**
     * @dev Sets media URL for a Logo.
     */
    function setMediaAsset(
        uint256 _logoId,
        string calldata _mediaAssetURL
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo storage l = logos[_logoId];
        require(
            !l.status.isDistributed,
            "Cannot upload asset after rewards are distributed."
        );
        require(
            !l.status.isRefunded,
            "Cannot upload asset after Logo is refunded."
        );
        require(
            l.proposer == msg.sender,
            "msg.sender is not the Logo proposer."
        );
        l.mediaAssetURL = _mediaAssetURL;
        l.status.isCrowdfunding = false; // Close crowdfund
        l.status.isUploaded = true;
        l.rejectionDeadline = block.timestamp + 7 * 1 days;
        emit MediaAssetSet(msg.sender, _mediaAssetURL);
    }

    /**
     * @dev Sets splits address for a Logo.
     */
    function setSplitsAddress(
        uint256 _logoId,
        address _splitsAddress
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo storage l = logos[_logoId];
        require(
            !l.status.isDistributed,
            "Cannot set splits after rewards are distributed."
        );
        require(
            !l.status.isRefunded,
            "Cannot set splits after Logo is refunded."
        );
        require(
            l.proposer == msg.sender,
            "msg.sender is not the Logo proposer."
        );
        l.splits = _splitsAddress;
        l.status.isCrowdfunding = false; // Close crowdfund
        l.rejectionDeadline = block.timestamp + 7 * 1 days;
        emit SplitsSet(msg.sender, _splitsAddress);
    }

    /**
     * @dev Calculate and distribute rewards to the Splits contract.
     */
    function distributeRewards(
        uint256 _logoId
    ) external nonReentrant whenNotPaused validLogoId(_logoId) {
        Logo storage l = logos[_logoId];
        require(!l.status.isDistributed, "Logo has already been distributed.");
        require(
            !l.status.isRefunded,
            "Cannot distribute rewards after Logo is refunded."
        );
        /* Only Mainnet
        require(block.timestamp > l.rejectionDeadline, "Rewards can only be distributed after rejection deadline has passed.");
        */
        require(
            l.proposer == msg.sender,
            "msg.sender is not the Logo proposer."
        );
        require(
            l.splits != address(0),
            "Splits address must be set prior to distribution."
        );

        // TODO check again
        // EnumerableSet.AddressSet storage backerAddresses = _logoBackerAddresses[_logoId];
        // address[] memory backerArray = backerAddresses.values();
        // uint256 totalRewards = 0;
        // for (uint256 i = 0; i < backerArray.length; i++) {
        //     Backer memory b = logoBackers[_logoId][backerArray[i]];
        //     unchecked {
        //         totalRewards += b.amount;
        //     }
        // }
        uint256 totalRewards = logoRewards[_logoId];

        l.status.isDistributed = true;
        (bool success, ) = payable(l.splits).call{value: totalRewards}("");
        require(success, "Reward distribution failed.");
        emit RewardsDistributed(msg.sender, l.splits, totalRewards);
    }

    /**
     * @dev Private function for polling backers, weighted by capital.
     */
    function _pollBackersForRefund(
        uint256 _logoId
    ) private view returns (bool) {
        // TODO check again
        // uint256 total = 0;
        uint256 total = logoRewards[_logoId];

        // TODO check again
        uint256 rejected = logoRejectedFunds[_logoId];
        // EnumerableSet.AddressSet storage backerAddresses = _logoBackerAddresses[_logoId];
        // address[] memory backerArray = backerAddresses.values();
        // uint256 rejected = 0;
        // for (uint i = 0; i < backerArray.length; i++) {
        //     address bAddress = backerArray[i];
        //     Backer memory b = logoBackers[_logoId][bAddress];
        //     unchecked {
        //         if (b.votesToReject) {
        //             rejected += b.amount;
        //         }
        //         // total += b.amount;
        //     }
        // }
        uint256 threshold = (rejected * 10_000) / total; // BPS
        return threshold > rejectThreshold;
    }

    /**
     * @dev Pause the contract
     * Only `owner` can call
     */
    function pause() external onlyOwner {
        super._pause();
    }

    /**
     * @dev Unpause the contract
     * Only `owner` can call
     */
    function unpause() external onlyOwner {
        super._unpause();
    }
}
