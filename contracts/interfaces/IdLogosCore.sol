// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SplitV2Lib} from "../splitsV2/libraries/SplitV2.sol";

interface IDLogosCore {
    /// STRUCTS
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
    struct LogoStatus {
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
        address splitForSpeaker; // PushSplit address for dlogos, community, speakers
        address splitForAffiliate; // PushSplit address for affiliates
        LogoStatus status;
    }

    struct SetSpeakersParam {
        uint256 logoId;
        address[] speakers;
        uint256[] fees;
        string[] providers;
        string[] handles;
    }
    
    /// EVENTS
    event LogoCreated(
        address indexed _owner,
        uint256 indexed _logoId,
        uint256 indexed _crowdfundStartAt
    );
    event ProposerFeeUpdated(address indexed _proposer, uint256 indexed _logoId, uint256 _proposerFee);
    event MinimumPledgeSet(address indexed _owner, uint256 indexed _minimumPledge);
    event CrowdfundToggled(
        address indexed _owner,
        bool indexed _crowdfundIsOpen
    );    
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
    event SpeakerStatusSetByOp(
        uint256 indexed _logoId, 
        uint8[] _indexes, 
        address[] _addresses, 
        uint8[] _statuses
    );    
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
    event OperatorUpdated(address indexed _operator);
    
    /// FUNCTIONS
    function dLogosOwner() external view returns (address);
    function operator() external view returns (address);
    function logoId() external view returns (uint256);
    function getLogo(uint256) external view returns (Logo memory);
    function createLogo(uint256, string calldata, uint8) external returns (uint256);  
    // function toggleCrowdfund(uint256) external;
    function setMinimumPledge(uint256, uint256) external;
    function refund(uint256) external;
    function setSpeakers(SetSpeakersParam calldata) external;
    function setSpeakerStatus(uint256, uint8) external;
    function setStatusForSpeakers(uint256, uint8[] calldata, address[] calldata, uint8[] calldata) external;
    function getSpeakersForLogo(uint256) external view returns (Speaker[] memory);
    function setDate(uint256, uint256) external;
    function setMediaAsset(uint256, string calldata) external;
    function distributeRewards(uint256, bool) external;
    function pauseOrUnpause(bool) external;
    function setOperator(address) external;
}
