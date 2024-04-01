// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IdLogos.sol";

/// @title Core dLogos contract
/// @author 0xan000n
contract dLogos is IdLogos, Ownable, Pausable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// STORAGE
    uint256 public logoID = 1; // Global Logo ID starting from 1
    mapping(uint256 => Logo) public logos; // Mapping of Owner addresses to Logo ID to Logo info 
    mapping(uint256 => mapping(address => Backer)) public logoBackers; // Mapping of Logo ID to address to Backer
    mapping(uint256 => EnumerableSet.AddressSet) private logoBackerAddresses;
    mapping(uint256 => Speaker[]) public logoSpeakers; // Mapping of Logo ID to list of Speakers
    uint16 public rejectThreshold = 5000; // backer rejection threshold in BPS (50%)

    /// FUNCTIONS
    /**
     * @dev Set reject threshold for dLogos.
     */
    function setRejectThreshold(uint16 _rejectThreshold) external nonReentrant onlyOwner {
        require(
            _rejectThreshold > 0 && _rejectThreshold <= 10000,
            "Reject threshold must be greater than 0 and less than 100."
        );
        rejectThreshold = _rejectThreshold;
        emit RejectThresholdUpdated(rejectThreshold);
    }

    /**
     * @dev Create new Logo onchain.
     */
    function createLogo(
        string calldata _title,
        string calldata _description,
        string calldata _discussion,
        uint _crowdfundNumberOfDays
    ) external nonReentrant whenNotPaused returns (uint256) {
        logos[logoID] = Logo({
            id: logoID,
            title: _title,
            description: _description,
            discussion: _discussion,
            creator: msg.sender,
            scheduledAt: 0,
            mediaAssetURL: "",
            minimumPledge: 0,
            crowdfundStartAt: block.timestamp,
            crowdfundEndAt: block.timestamp + _crowdfundNumberOfDays * 1 days,
            splits: address(0),
            rejectionDeadline: 0,
            status: Status({isUploaded: false, isCrowdfunding: true, isDistributed: false, isRefunded: false})
        });
        emit LogoCreated(msg.sender, logoID, block.timestamp);
        emit CrowdfundToggled(msg.sender, true);
        return logoID++; // Return and Increment Global Logo ID
    }

    /**
     * @dev Toggle crowdfund for Logo. Only the creator of the Logo is allowed to toggle a crowdfund.
     */
    function toggleCrowdfund(uint256 _logoID) external nonReentrant whenNotPaused {
        Logo storage l = logos[_logoID];
        require(!l.status.isUploaded, "Cannot toggle crowdfund after Logo asset is uploaded.");
        require(!l.status.isDistributed, "Cannot toggle crowdfund after rewards are distributed.");
        require(!l.status.isRefunded, "Cannot toggle crowdfund after Logo is refunded.");
        require(l.creator == msg.sender, "Only the Logo creator is allowed to toggle crowdfund.");
        l.status.isCrowdfunding = !l.status.isCrowdfunding;
        emit CrowdfundToggled(msg.sender, l.status.isCrowdfunding);
    }

    /**
     * @dev Payable function to add crowdfund.
     */
    function crowdfund(uint256 _logoID) external payable nonReentrant whenNotPaused {
        Logo memory l = logos[_logoID];
        require(l.status.isCrowdfunding, "Crowdfund is not open.");
        require(!l.status.isDistributed, "Cannot set date after rewards are distributed.");
        require(msg.value > l.minimumPledge, "Crowdfund value must be greater than the minimum pledge.");
        bool isBacker = logoBackerAddresses[_logoID].contains(msg.sender);
        if (isBacker){
            Backer storage backer = logoBackers[_logoID][msg.sender];
            unchecked {
                backer.amount += msg.value;
            }
        } else {
            // Record the value sent to the address.
            require (logoBackerAddresses[_logoID].length() < 1000, "A Logo can have at most 1000 backers.");
            Backer memory b = Backer({
                addr: msg.sender,
                amount: msg.value,
                votesToReject: false,
                isDistributed: false
            });
            logoBackerAddresses[_logoID].add(msg.sender);
            logoBackers[_logoID][msg.sender] = b;
        }
        emit Crowdfund(msg.sender, msg.value);    
    }

    /**
     * @dev Set minimum pledge for a conversation.
     */
    function setMinimumPledge(uint256 _logoID, uint256 _minimumPledge) external nonReentrant whenNotPaused {
        Logo storage l = logos[_logoID];
        require(l.status.isCrowdfunding, "Can only set minimum pledge during crowdfund.");
        require(l.creator == msg.sender, "msg.sender is not the Logo creator.");
        require(_minimumPledge > 0, "Minimum pledge must be greater than 0.");
        l.minimumPledge = _minimumPledge;
        emit MinimumPledgeSet(msg.sender, _minimumPledge);
    }

    /**
     * @dev Withdraw your pledge from a Logo.
     */
    function withdrawFunds(
        uint256 _logoID,
        uint256 _amount
    ) external nonReentrant whenNotPaused {
        Logo memory l = logos[_logoID];
        require(
            l.status.isCrowdfunding || l.status.isRefunded,
            "Logo must be crowdfunding or be refunded to withdraw."
        );
        require(_amount > 0, "Amount must be greater than 0."); 
        bool isBacker = logoBackerAddresses[_logoID].contains(msg.sender);
        require (isBacker, "msg.sender is not a backer.");
        Backer storage backer = logoBackers[_logoID][msg.sender];
        require(!backer.isDistributed, "Backer funds have already been distributed.");
        require(backer.amount == _amount, "Requested withdrawal amount does not match the backer's pledged amount.");
        uint256 amount = backer.amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw failed.");
        logoBackerAddresses[_logoID].remove(msg.sender);
        delete logoBackers[_logoID][msg.sender];
        emit FundsWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Allows a backer to reject an uploaded asset.
     */
    function reject(
        uint256 _logoID
    ) external nonReentrant whenNotPaused {
        Logo memory l = logos[_logoID];
        require(block.timestamp < l.rejectionDeadline, "Rejection deadline has passed.");
        bool isBacker = logoBackerAddresses[_logoID].contains(msg.sender);
        require (isBacker, "msg.sender is not a backer.");
        Backer storage backer = logoBackers[_logoID][msg.sender];
        backer.votesToReject = true;
        emit RejectionSubmitted(_logoID, msg.sender);
    }

    /**
     * @dev Internal function for polling backers, weighted by capital.
     */
    function _pollBackersForRefund(
        uint256 _logoID
    ) private view returns (bool) {
        EnumerableSet.AddressSet storage backerAddresses = logoBackerAddresses[_logoID];
        address[] memory backerArray = backerAddresses.values();
        uint256 total = 0;
        uint256 rejected = 0;
        for (uint i = 0; i < total; i++) {
            address bAddress = backerArray[i];
            Backer memory b = logoBackers[_logoID][bAddress];
            unchecked {
                if (b.votesToReject){
                    rejected += b.amount;
                }
                total += b.amount;
            }
        }
        uint256 threshold = rejected * 10_000 / total; // BPS
        return threshold > rejectThreshold;
    }

    /**
     * @dev Issue refund of the Logo.
     */
    function refund(
        uint256 _logoID
    ) external nonReentrant whenNotPaused {
        Logo storage l = logos[_logoID];
        require(!l.status.isDistributed, "Cannot refund after rewards are distributed.");
        bool c1 = l.creator == msg.sender; // Case 1: Logo creator can refund whenever.
        bool c2 = block.timestamp > l.crowdfundEndAt; // Case 2: Crowdfund end date reached and not distributed
        bool c3 = l.scheduledAt != 0 && (block.timestamp > l.scheduledAt + 7 * 1 days) && !l.status.isUploaded; // Case 3: >7 days have passed since schedule date and no asset uploaded.
        bool c4 = _pollBackersForRefund(_logoID); // Case 4: >50% of backers reject upload.
        require(c1 || c2 || c3 || c4, "No conditions met for refund.");
        l.status.isRefunded = true;
        emit RefundInitiated(_logoID, c1, c2, c3, c4);
    }

    /**
     * @dev Return the list of backers for a Logo.
     */
    function getBackersForLogo(
        uint256 _logoID
    ) external view returns (Backer[] memory) {
        EnumerableSet.AddressSet storage backerAddresses = logoBackerAddresses[_logoID];
        address[] memory backerArray = backerAddresses.values();
        Backer[] memory backers = new Backer[](backerArray.length);
        for (uint256 i = 0; i < backerArray.length; i++) {
            backers[i] = logoBackers[_logoID][backerArray[i]];
        }
        return backers;
    }

    /**
     * @dev Set speakers for a Logo.
     */
    function setSpeakers(
        uint256 _logoID,
        address[] calldata _speakers,
        uint16[] calldata _fees,
        string[] calldata _providers,
        string[] calldata _handles
    ) external nonReentrant whenNotPaused {
        Logo memory l = logos[_logoID];
        require(l.creator == msg.sender, "msg.sender is not the Logo creator.");
        require(_speakers.length > 0, "Please submit at least one speaker.");
        require(_speakers.length < 100, "Cannot have more than 100 speakers.");
        require(
            _speakers.length == _fees.length &&
            _fees.length == _providers.length &&
            _providers.length == _handles.length,
            "Length of calldata arrays must be equal."
        );
        delete logoSpeakers[_logoID]; // Reset to default (no speakers)
        for (uint i = 0; i < _speakers.length; i++) {
            Speaker memory s = Speaker({
                addr: _speakers[i],
                fee: _fees[i],
                provider: _providers[i],
                handle: _handles[i],
                status: SpeakerStatus.Pending
            });
            logoSpeakers[_logoID].push(s);
        }
        emit SpeakersSet(msg.sender, _speakers, _fees, _providers, _handles);
    }

    /**
     * @dev Set status of a speaker.
     */
    function setSpeakerStatus(uint256 _logoID, uint _status) external nonReentrant whenNotPaused {
        Speaker[] memory speakers = logoSpeakers[_logoID];
        for (uint i = 0; i < speakers.length; i++) {
            if (address(speakers[i].addr) == msg.sender) { 
                logoSpeakers[_logoID][i].status = SpeakerStatus(_status);
                emit SpeakerStatusSet(_logoID, msg.sender, _status);
                break;
            }
        }
    }

    /**
     * @dev Return the list of speakers for a Logo.
     */
    function getSpeakersForLogo(
        uint256 _logoID
    ) external view returns (Speaker[] memory) {
        return logoSpeakers[_logoID];
    }

    /**
     * @dev Set date for a conversation.
     */
    function setDate(uint256 _logoID, uint _scheduledAt) external nonReentrant whenNotPaused {
        Logo storage l = logos[_logoID];
        require(!l.status.isUploaded, "Cannot set date after Logo asset is uploaded.");
        require(!l.status.isDistributed, "Cannot set date after rewards are distributed.");
        require(!l.status.isRefunded, "Cannot set date after Logo is refunded.");
        require(l.creator == msg.sender, "msg.sender is not the Logo creator.");
        require(_scheduledAt > block.timestamp, "Proposed date must be in the future.");
        l.scheduledAt = _scheduledAt;
        l.status.isCrowdfunding = false; // Close crowdfund
        emit DateSet(msg.sender, _scheduledAt);
    }

    /**
     * @dev Sets media URL for a Logo.
     */
    function setMediaAsset(
        uint256 _logoID,
        string calldata _mediaAssetURL
    ) external nonReentrant whenNotPaused {
        Logo storage l = logos[_logoID];
        require(!l.status.isDistributed, "Cannot upload asset after rewards are distributed.");
        require(!l.status.isRefunded, "Cannot upload asset after Logo is refunded.");
        require(l.creator == msg.sender, "msg.sender is not the Logo creator.");
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
        uint256 _logoID,
        address _splitsAddress
    ) external nonReentrant whenNotPaused {
        Logo storage l = logos[_logoID];
        require(!l.status.isDistributed, "Cannot set splits after rewards are distributed.");
        require(!l.status.isRefunded, "Cannot set splits after Logo is refunded.");
        require(l.creator == msg.sender, "msg.sender is not the Logo creator.");
        l.splits = _splitsAddress;
        l.status.isCrowdfunding = false; // Close crowdfund
        l.rejectionDeadline = block.timestamp + 7 * 1 days;
        emit SplitsSet(msg.sender, _splitsAddress);
    }

    /**
     * @dev Calculate and distribute rewards to the Splits contract.
     */
    function distributeRewards(
        uint256 _logoID
    ) external nonReentrant whenNotPaused {
        Logo storage l = logos[_logoID];
        require(!l.status.isDistributed, "Logo has already been distributed.");
        require(!l.status.isRefunded, "Cannot distribute rewards after Logo is refunded.");
        require(block.timestamp > l.rejectionDeadline, "Rewards can only be distributed after rejection deadline has passed.");
        require(l.creator == msg.sender, "msg.sender is not the Logo creator.");
        require(l.splits != address(0), "Splits address must be set prior to distribution.");
        EnumerableSet.AddressSet storage backerAddresses = logoBackerAddresses[_logoID];
        address[] memory backerArray = backerAddresses.values();
        uint256 totalRewards;
        for (uint256 i = 0; i < backerArray.length; i++) {
            Backer storage b = logoBackers[_logoID][backerArray[i]];
            if (!b.isDistributed) {
                unchecked {
                    totalRewards += b.amount;
                }
                b.isDistributed = true;
            }
        }
        (bool success, ) = payable(l.splits).call{value: totalRewards}("");
        require(success, "Reward distribution failed.");
        l.status.isDistributed = true;
        emit RewardsDistributed(msg.sender, l.splits, totalRewards);
    }
}