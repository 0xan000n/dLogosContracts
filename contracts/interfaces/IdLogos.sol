// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SplitV2Lib} from "../splitsV2/libraries/SplitV2.sol";

interface IDLogos {
    struct Backer {
        address addr;
        address referrer;
        bool votesToReject;
        uint256 amount;
    }

    enum SpeakerStatus {
        Pending,
        Accepted,
        Declined
    }

    struct Speaker {
        address addr;
        uint256 fee;
        string provider; // e.g. X, Discord etc.
        string handle;
        SpeakerStatus status;
    }

    // isUploaded && isDistributed for a successful logo
    // isUploaded && isRefunded for an uploaded and refunded logo
    struct Status {
        bool isCrowdfunding;
        bool isUploaded;
        bool isDistributed;
        bool isRefunded;
    }

    /// @notice All onchain information for a Logo.
    struct Logo {
        uint256 id;
        string title;
        string mediaAssetURL;
        address proposer;
        uint256 proposerFee;
        uint256 scheduledAt;
        uint256 minimumPledge;
        uint256 crowdfundStartAt;
        uint256 crowdfundEndAt;
        uint256 rejectionDeadline;
        address splitForSpeaker; // PUshSplit address for dlogos, community, speakers
        address splitForAffiliate; // PUshSplit address for affiliates
        Status status;
    }

    /// EVENTS
    event DLogosAddressUpdated(address _dLogos);
    event CommunityAddressUpdated(address _community);
    event DLogosFeeUpdated(uint256 _dLogosFee);
    event CommunityFeeUpdated(uint256 _communityFee);
    event AffiliateFeeUpdated(uint256 _affiliateFee);
    event RejectThresholdUpdated(uint16 indexed _fee);
    event MaxDurationUpdated(uint8 _maxDuration);
    event RejectinoWindowUpdated(uint8 _rejectionWindow);
    event ZeroFeeProposersSet(address[] _proposers, bool[] _statuses);
    event LogoCreated(
        address indexed _owner,
        uint256 indexed _logoId,
        uint256 indexed _crowdfundStartAt
    );
    event ProposerFeeUpdated(address indexed _proposer, uint256 indexed _logoId, uint256 _proposerFee);
    event MinimumPledgeSet(address indexed _owner, uint256 indexed _minimumPledge);
    event Crowdfund(
        uint256 indexed _logoId,
        address indexed _owner, 
        uint256 indexed _amount
    );
    event CrowdfundToggled(
        address indexed _owner,
        bool indexed _crowdfundIsOpen
    );
    event FundsWithdrawn(address indexed _owner, uint256 indexed _amount);
    event SpeakersSet(
        address indexed _owner,
        address[] _speakers,
        uint256[] _fees,
        string[] _providers,
        string[] _handles
    );
    event DateSet(address indexed _owner, uint256 indexed _scheduledAt);
    event MediaAssetSet(address indexed _owner, string indexed _mediaAssetURL);
    event RewardsDistributed(
        address indexed _proposer, 
        address _splitForSpeaker, 
        address _splitForAffiliate, 
        uint256 _totalRewards
    );
    event SpeakerStatusSet(uint256 indexed _logoId, address indexed _speaker, uint256 indexed _status);
    event RejectionSubmitted(uint256 indexed _logoId, address indexed _backer);
    event RefundInitiated(
        uint256 indexed _logoId, 
        bool _case1,
        bool _case2,
        bool _case3,
        bool _case4
    );
    event SplitForAffiliateCreated(
        address indexed _split, 
        SplitV2Lib.Split _splitParams, 
        address _owner, 
        address _creator
    );
    event SplitForSpeakerCreated(
        address indexed _split, 
        SplitV2Lib.Split _splitParams, 
        address _owner, 
        address _creator
    );
    event TrustedForwarderUpdated(address trustedForwarder_);

    function logoId() external view returns (uint256);

    function rejectThreshold() external view returns (uint16);

    function maxDuration() external view returns (uint8);

    function initialize(
        address _pushSplitFactory,
        address _dLogos,
        address _community,
        address trustedForwarder_
    ) external;  

    function setRejectThreshold(uint16) external;

    function setMaxDuration(uint8) external;

    function createLogo(uint256, string calldata, uint8) external returns (uint256);  

    function toggleCrowdfund(uint256) external;

    function crowdfund(uint256, address) external payable;

    function setMinimumPledge(uint256, uint256) external;

    function withdrawFunds(uint256) external;

    function reject(uint256) external;

    function refund(uint256) external;

    function getBackersForLogo(uint256) external view returns (Backer[] memory);

    function setSpeakers(
        uint256, 
        address[] calldata, 
        uint256[] calldata, 
        string[] calldata, 
        string[] calldata
    ) external;

    function setSpeakerStatus(
        uint256,
        uint8
    ) external;

    function getSpeakersForLogo(uint256) external view returns (Speaker[] memory);

    function setDate(
        uint256,
        uint256
    ) external;

    function setMediaAsset(
        uint256,
        string calldata
    ) external;

    function distributeRewards(
        uint256
    ) external;

    function pause() external;

    function unpause() external;
}
