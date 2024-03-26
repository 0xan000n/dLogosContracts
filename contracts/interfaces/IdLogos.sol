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

}