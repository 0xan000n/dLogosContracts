// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IdLogos.sol";

/// @title Core dLogos contract
/// @author 0xan000n
contract dLogos is IdLogos, ReentrancyGuard {
    uint256 public logoID = 1; // Global Logo ID starting from 1
    mapping(uint256 => Logo) public logos; // Mapping of Owner addresses to Logo ID to Logo info
    mapping(uint256 => Backer[]) public logoBackers;  // Mapping of Logo ID to list of Backers
    mapping(uint256 => Speaker[]) public logoSpeakers; // Mapping of Logo ID to list of Speakers
    uint16 public dLogosServiceFee = 300; // dLogos fees in BPS (3%)
    uint16 public rejectThreshold = 5000; // backer rejection threshold in BPS (50%)
    
    /// EVENTS
    event LogUpdateFee(uint16 indexed _fee);
    event LogoCreated(
        address indexed _owner,
        uint indexed _logoID,
        uint indexed _crowdfundStartAt
    );
    event Crowdfund(address indexed _owner, uint indexed _amount);
    event CrowdfundToggle(
        address indexed _owner,
        bool indexed _crowdfundIsOpen
    );
    event FundsWithdrawn(address indexed _owner, uint indexed _amount);
    event SpeakersSet(
        address indexed _owner,
        address[] _speakers,
        uint16[] _fees,
        string[] _providers,
        string[] _handles
    );
    event DateSet(address indexed _owner, uint indexed _scheduledAt);
    event MediaAssetSet(address indexed _owner, string indexed _mediaAssetURL);
    event SplitsSetAndRewardsDistributed(
        address indexed _owner,
        address indexed _splitsAddress,
        uint256 indexed _totalRewards
    );
    event SpeakerStatusSet(uint indexed _logoID, address indexed _speaker, uint indexed _status);
    event RefundIssued(
        uint indexed _logoID, 
        address indexed _owner, 
        uint indexed _amount,
        bool _case1,
        bool _case2,
        bool _case3,
        bool _case4
    );
    
    /**
     * @dev Set service fee for dLogos.
     */
    function setServiceFee(uint16 _dLogosServiceFee) external nonReentrant {
        /* TODO: (1) onlyOwner */
        require(
            _dLogosServiceFee > 0 && _dLogosServiceFee <= 10000,
            "dLogos: DLOGOS_SERVICE_FEE_INVALID"
        );
        dLogosServiceFee = _dLogosServiceFee;
        emit LogUpdateFee(dLogosServiceFee);
    }

    /**
     * @dev Create new Logo onchain.
     */
    function createLogo(
        string calldata _title,
        string calldata _description,
        string calldata _discussion,
        string calldata _mediaAssetURL,
        uint _crowdfundNumberOfDays
    ) external nonReentrant returns (uint256) {
        /* TODO: (1) Requires (2) right role */
        logos[logoID] = Logo({
            id: logoID,
            title: _title,
            description: _description,
            discussion: _discussion,
            creator: msg.sender,
            scheduledAt: 0,
            mediaAssetURL: _mediaAssetURL, // TODO: remove this from calldata
            crowdfundStartAt: block.timestamp,
            crowdfundEndAt: block.timestamp + _crowdfundNumberOfDays * 1 days,
            splits: address(0),
            rejectionDeadline: 0,
            status: Status({isUploaded: false, isCrowdfunding: true, isAccepted: false})
        });

        emit LogoCreated(msg.sender, logoID, block.timestamp);
        emit CrowdfundToggle(msg.sender, true);

        return logoID++; // Return and Increment Global Logo ID
    }

    /**
     * @dev Toggle crowdfund for Logo. Only the owner of the Logo is allowed to toggle a crowdfund.
     * returns if successful.
     */
    function toggleCrowdfund(uint256 _logoID) external nonReentrant {
        Logo memory l = logos[_logoID];
        l.status.isCrowdfunding = !l.status.isCrowdfunding;
        logos[_logoID] = l;

        emit CrowdfundToggle(msg.sender, l.status.isCrowdfunding);
    }

    /**
     * @dev Payable function to add crowdfund.
     */
    function crowdfund(uint256 _logoID) external payable nonReentrant {
        // TODO: Requires and Roles
        Logo memory l = logos[_logoID];
        require(l.status.isCrowdfunding == true, "Crowdfund is not open.");

        bool isBacker = false;
        Backer[] storage backers = logoBackers[_logoID];
        for (uint i = 0; i < backers.length; i++) {
            if (!backers[i].isDistributed && backers[i].addr == msg.sender) {
                backers[i].amount += msg.value; // Add to existing backer. Must not be distributed.
                isBacker = true;
            }
        }

        if (!isBacker) {
            // Record the value sent to the address.
            Backer memory b = Backer({
                addr: msg.sender,
                amount: msg.value,
                votesToReject: false,
                isDistributed: false
            });
            logoBackers[_logoID].push(b);
        }

        emit Crowdfund(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw your pledge from a Logo.
     */
    function withdrawFunds(
        uint256 _logoID,
        uint256 _amount
    ) external nonReentrant {
        // Can only withdraw while crowdfund is open.
        Logo memory l = logos[_logoID];
        require(
            l.status.isCrowdfunding == true,
            "Cannot withdraw after crowdfund is closed."
        );

        Backer[] storage backers = logoBackers[_logoID];

        for (uint i = 0; i < backers.length; i++) {
            if (
                !backers[i].isDistributed &&
                backers[i].addr == msg.sender &&
                backers[i].amount == _amount
            ) {
                uint256 amount = backers[i].amount;
                (bool success, ) = payable(msg.sender).call{value: amount}("");
                require(success, "Withdraw failed.");
                delete backers[i];
                emit FundsWithdrawn(msg.sender, amount);
                break;
            }
        }
    }
    
    /**
     * @dev Allows a backer to reject an uploaded asset.
     */
    function reject(
        uint256 _logoID
    ) external nonReentrant {
        Logo memory l = logos[_logoID];
        require(block.timestamp < l.rejectionDeadline, "Rejection deadline has passed.");

        Backer[] storage backers = logoBackers[_logoID];
        
        for (uint i = 0; i < backers.length; i++) {
            if (backers[i].addr == msg.sender){
                backers[i].votesToReject = true;
                return;
            }
        }
        require(false, "msg.sender is not a backer.");
    }

    /**
     * @dev Internal function for polling backers.
     */
    function _pollBackersForRefund(
        uint256 _logoID
    ) private view returns (bool) {
        Logo memory l = logos[_logoID];
        require(block.timestamp < l.rejectionDeadline, "Rejection deadline has passed.");
        
        Backer[] storage backers = logoBackers[_logoID];
        uint total = backers.length;
        uint rejected = 0;
        for (uint i = 0; i < backers.length; i++) {
            if (backers[i].votesToReject){
                rejected += 1;
            }
        }
        uint threshold = rejected * 10_000 / total; // BPS
        return threshold >= rejectThreshold;
    }

    /**
     * @dev Issue refund of the Logo.
     */
    function refund(
        uint256 _logoID
    ) external nonReentrant {
        Logo memory l = logos[_logoID];
        
        bool c1 = l.creator == msg.sender; // Case 1: Logo admin can refund whenever.
        bool c2 = (block.timestamp > l.crowdfundEndAt) && !l.status.isAccepted; // Case 2: Crowdfund due date reached and not accepted by backers
        bool c3 = l.scheduledAt != 0 && (block.timestamp > l.scheduledAt + 7 * 1 days) && !l.status.isUploaded; // Case 3: >7 days have passed since schedule date and no asset uploaded.
        bool c4 = _pollBackersForRefund(_logoID); // Case 4: >50% of backers reject upload.
        require(c1 || c2 || c3 || c4, "No conditions met for refund.");
        
        Backer[] storage backers = logoBackers[_logoID];
        
        for (uint i = 0; i < backers.length; i++) {
            require(
                backers[i].isDistributed == false,
                "Cannot refund backer funds that are already distributed."
            );

            uint256 amount = backers[i].amount;
            address addr = backers[i].addr;
            (bool success, ) = payable(addr).call{value: amount}("");
            require(success, "Refund failed.");
            delete backers[i];
            emit RefundIssued(_logoID, addr, amount, c1, c2, c3, c4);
        }
    }

    /**
     * @dev Return the list of backers for a Logo.
     */
    function getBackersForLogo(
        uint256 _logoID
    ) external view returns (Backer[] memory) {
        return logoBackers[_logoID];
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
    ) external nonReentrant {
        Logo memory l = logos[_logoID];
        require(l.creator == msg.sender, "msg.sender is not owner"); // Require msg sender to be the creator
        require(_speakers.length == _fees.length); // Equal speakers and fees

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
    function setSpeakerStatus(uint256 _logoID, uint _status) external nonReentrant {
        
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
    function setDate(uint256 _logoID, uint _scheduledAt) external nonReentrant {
        Logo memory l = logos[_logoID];
        // TODO: prevent admin from continually pushing back date.
        // TODO: make sure this is a future date
        require(l.creator == msg.sender, "msg.sender is not owner"); // Require msg sender to be the creator

        l.scheduledAt = _scheduledAt;
        l.status.isCrowdfunding = false; // Close crowdfund
        logos[_logoID] = l;

        emit DateSet(msg.sender, _scheduledAt);
    }

    /*
     * @dev Sets media URL for a Logo.
     */
    function setMediaAsset(
        uint256 _logoID,
        string calldata _mediaAssetURL
    ) external nonReentrant {
        Logo memory l = logos[_logoID];

        require(l.creator == msg.sender, "msg.sender is not owner"); // Require msg sender to be the creator

        l.mediaAssetURL = _mediaAssetURL;
        l.status.isUploaded = true;
        l.rejectionDeadline = block.timestamp + 7 * 1 days;
        l.status.isAccepted = true; // TODO: separate function
        logos[_logoID] = l; // add check prior to this

        emit MediaAssetSet(msg.sender, _mediaAssetURL);
    }

    function setSplitsAndDistributeRewards(
        uint256 _logoID,
        address _splitsAddress
    ) external nonReentrant {
        Logo memory l = logos[_logoID];
        require(l.creator == msg.sender, "msg.sender is not owner"); // Require msg sender to be the creator
        // TODO: consider adding final check to 
        // Save Splits address
        l.splits = _splitsAddress;

        // Distribute Rewards
        uint256 totalRewards = 0;
        Backer[] storage backers = logoBackers[_logoID];
        for (uint i = 0; i < backers.length; i++) {
            if (!backers[i].isDistributed) {
                // Only add if not distributed
                totalRewards += backers[i].amount;
                backers[i].isDistributed = true; /* TODO: Move this as clean up after the payable tx */
            }
        }
        (bool success, ) = payable(l.splits).call{value: totalRewards}("");
        require(success, "Distribute failed.");

        // Close crowdfund.
        l.status.isCrowdfunding = false;
        logos[_logoID] = l;

        emit SplitsSetAndRewardsDistributed(msg.sender, l.splits, totalRewards);
    }
}
