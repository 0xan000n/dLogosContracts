// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IdLogos {
    struct Backer {
        address addr;
        uint256 amount;
        bool votesToReject;
        bool isDistributed; 
    }

    enum SpeakerStatus {
        Pending,
        Accepted,
        Declined
    }

    struct Speaker {
        address addr;
        uint16 fee; // in BPS
        string provider; // e.g. X, Discord etc.
        string handle;
        SpeakerStatus status;
    }

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
        string description;
        string discussion;
        string mediaAssetURL;
        address creator;
        uint scheduledAt;
        uint crowdfundStartAt;
        uint crowdfundEndAt;
        uint rejectionDeadline;
        address splits; // Splits Address
        Status status;
    }

    /// EVENTS
    event FeeUpdated(uint16 indexed _fee);
    event RejectThresholdUpdated(uint16 indexed _fee);
    event LogoCreated(
        address indexed _owner,
        uint indexed _logoID,
        uint indexed _crowdfundStartAt
    );
    event Crowdfund(address indexed _owner, uint indexed _amount);
    event CrowdfundToggled(
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
    event SplitsSet(address indexed _owner, address indexed _splitsAddress);
    event RewardsDistributed(
        address indexed _owner,
        address indexed _splitsAddress,
        uint256 indexed _totalRewards
    );
    event SpeakerStatusSet(uint indexed _logoID, address indexed _speaker, uint indexed _status);
    event RejectionSubmitted(uint indexed _logoID, address indexed _backer);
    event RefundInitiated(
        uint indexed _logoID, 
        bool _case1,
        bool _case2,
        bool _case3,
        bool _case4
    );
}