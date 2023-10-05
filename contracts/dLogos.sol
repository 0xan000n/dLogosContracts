// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/* OPEN QUESTIONS 
    1. Does there need to be a dedicated contribution address for each conversation?
    2. May be useful to have a mapping from conversation ID to convo metadata.
    3. Does all the conversatio metadata need to be stored in SC?
    4. Convo Array vs mapping (looks like best practice is separate for metadata)
    5. createDelegatedConvo (onlyOwner can create on behalf of an address)
    6. Separate gov address from revenue address
    7. Only allow txs if crowdfund enabled
*/

/// @title Core dLogos contract
/// @author 0xan000n
contract dLogos is ReentrancyGuard {
    struct Backer {
        address addr;
        uint256 amount; // ETH Contribution
        bool isDistributed; // Funds have been distributed
    }

    enum SpeakerStatus {
        Pending,
        Accepted,
        Declined
    }

    struct Speaker {
        address addr;
        uint16 fee; // Speaker reward BPS
        string provider; // e.g. X, Discord etc.
        string handle;
        SpeakerStatus status; // Status of the speaker 0 = pending, 1 = accepted, 2 = declined
    }

    struct Host {
        address addr;
        uint16 fee; // Host reward BPS
    }

    /// @notice All on-chain information for a Logo.
    struct Logo {
        // Meta
        uint256 id;
        string title;
        string description;
        string discussion;
        // Roles
        address creator;
        uint scheduledAt;
        // Crowdfunding Attributes
        uint crowdfundStartAt;
        uint crowdfundEndAt;
        bool isCrowdfunding;
        /*
        address[] speakers;
        address[] backers;      // BackerInfo[] backers;
    
        

        // Scheduling Attributes
        uint scheduledAt;
        uint scheduleFailedRefundAt; // Date to allow refund if conversation is not scheduled.
        bool isScheduled;
        
        // Media Upload Attributes
        uint uploadFailureRefundAt; // Date to allow refund if conversation is not uploaded.
        
        */
        string mediaAssetURL;
        bool isUploaded;
        // Logo Split Address
        address splits;
    }

    // Global Logo ID starting from 1
    uint256 public logoID = 1;
    // Mapping of Owner addresses to Logo ID to Logo info
    mapping(uint256 => Logo) public logos;
    // Mapping of Logo ID to list of Backers
    mapping(uint256 => Backer[]) public logoBackers;
    // Mapping of Logo ID to list of Speakers
    mapping(uint256 => Speaker[]) public logoSpeakers;
    // Mapping of Logo ID to list of Hosts
    mapping(uint256 => Host[]) public logoHosts;
    // dLogos fees in BPS (3%)
    uint16 public dLogosServiceFee = 300;

    /* Events */

    // Default
    event LogUpdateFee(uint16 indexed _fee);
    event LogoCreated(
        address indexed _owner,
        uint indexed _logoID,
        uint indexed _crowdfundStartAt
    );

    // Crowdfund
    event Crowdfund(address indexed _owner, uint indexed _amount);
    event CrowdfundToggle(
        address indexed _owner,
        bool indexed _crowdfundIsOpen
    );

    // Funds
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
    event SpeakerStatusSet(address indexed _speaker, uint indexed _status);

    function setServiceFee(uint16 _dLogosServiceFee) external {
        /* TODO: (1) onlyOwner */
        require(
            _dLogosServiceFee > 0 && _dLogosServiceFee <= 10000,
            "dLogos: DLOGOS_SERVICE_FEE_INVALID"
        );
        dLogosServiceFee = _dLogosServiceFee;
        emit LogUpdateFee(dLogosServiceFee);
    }

    // Returns logoID
    function createLogo(
        string calldata _title,
        string calldata _description,
        string calldata _discussion,
        string calldata _mediaAssetURL,
        uint _crowdfundNumberOfDays
    ) external returns (uint256) {
        /* TODO: (1) Requires (2) right role */
        logos[logoID] = Logo({
            id: logoID,
            title: _title,
            description: _description,
            discussion: _discussion,
            creator: msg.sender,
            scheduledAt: 0, // TODO: Correct default
            mediaAssetURL: _mediaAssetURL,
            isUploaded: false,
            isCrowdfunding: true,
            crowdfundStartAt: block.timestamp,
            crowdfundEndAt: block.timestamp + _crowdfundNumberOfDays * 1 days,
            splits: address(0)
        });

        emit LogoCreated(msg.sender, logoID, block.timestamp);
        emit CrowdfundToggle(msg.sender, true);

        return logoID++; // Return and Increment Global Logo ID
    }

    /**
     * @dev Open crowdfund for Logo. Only the owner of the Logo is allowed to open a crowdfund.
     * returns if successful.
     */
    function toggleCrowdfund(uint256 _logoID) external returns (bool) {
        Logo memory l = logos[_logoID];
        l.isCrowdfunding = !l.isCrowdfunding;
        logos[_logoID] = l;

        emit CrowdfundToggle(msg.sender, l.isCrowdfunding);

        return true;
    }

    function crowdfund(uint256 _logoID) external payable nonReentrant {
        // TODO: Requires and Roles
        Logo memory l = logos[_logoID];
        require(l.isCrowdfunding == true, "Crowdfund is not open.");

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
                isDistributed: false
            });
            logoBackers[_logoID].push(b);
        }

        emit Crowdfund(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw your pledge from a logo.
     */
    function withdrawFunds(
        uint256 _logoID,
        uint256 _amount
    ) external nonReentrant {
        // Can only withdraw while crowdfund is open.
        Logo memory l = logos[_logoID];
        require(
            l.isCrowdfunding == true,
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
     * @dev Return the list of backers for a logo.
     */
    function getBackersForLogo(
        uint256 _logoID
    ) external view returns (Backer[] memory) {
        return logoBackers[_logoID];
    }

    /**
     * @dev Return the list of convos for a creator.
     */
    // function getConvo(address _creator) external view returns(Convo[] memory) {
    //     return conversations[_creator][];
    // }

    /**
     * @dev Set speakers for a logo.
     */
    function setSpeakers(
        uint256 _logoID,
        address[] calldata _speakers,
        uint16[] calldata _fees,
        string[] calldata _providers,
        string[] calldata _handles
    ) external {
        Logo memory l = logos[_logoID];
        require(l.creator == msg.sender); // Require msg sender to be the creator
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
    function setSpeakerStatus(uint256 _logoID, uint _status) external returns (bool) {
        
        Speaker[] memory speakers = logoSpeakers[_logoID];
        
        for (uint i = 0; i < speakers.length; i++) {
            if (address(speakers[i].addr) == msg.sender) { 
                logoSpeakers[_logoID][i].status = SpeakerStatus(_status);
                emit SpeakerStatusSet(msg.sender, _status);
                break;
            }
        }

        return true;
    }

    /**
     * @dev Return the list of speakers for a logo.
     */
    function getSpeakersForLogo(
        uint256 _logoID
    ) external view returns (Speaker[] memory) {
        return logoSpeakers[_logoID];
    }

    /**
     * @dev Set date for a conversation.
     */
    function setDate(uint256 _logoID, uint _scheduledAt) external {
        Logo memory l = logos[_logoID];

        require(l.creator == msg.sender); // Require msg sender to be the creator

        l.scheduledAt = _scheduledAt;
        logos[_logoID] = l;

        emit DateSet(msg.sender, _scheduledAt);
    }

    /*
     * @dev Sets media URL for a logo.
     */
    function setMediaAsset(
        uint256 _logoID,
        string calldata _mediaAssetURL
    ) external {
        Logo memory l = logos[_logoID];

        require(l.creator == msg.sender); // Require msg sender to be the creator

        l.mediaAssetURL = _mediaAssetURL;
        logos[_logoID] = l; // add check prior to this

        emit MediaAssetSet(msg.sender, _mediaAssetURL);
    }

    function setSplitsAndDistributeRewards(
        uint256 _logoID,
        address _splitsAddress
    ) external nonReentrant {
        Logo memory l = logos[_logoID];
        require(l.creator == msg.sender); // Require msg sender to be the creator
        require(_splitsAddress != address(0)); // Require splits address to be non zero

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
        l.isCrowdfunding = false;
        logos[_logoID] = l;

        emit SplitsSetAndRewardsDistributed(msg.sender, l.splits, totalRewards);
    }
}
