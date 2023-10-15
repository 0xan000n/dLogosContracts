// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IdLogos {

    struct Backer {
        address addr;
        uint256 amount; // ETH Contribution
        bool votesToReject;
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

    struct Status {
        bool isCrowdfunding;
        bool isUploaded;
        bool isAccepted;
    }

    /// @notice All onchain information for a Logo.
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
        //bool isCrowdfunding;
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
        //bool isUploaded;
        uint rejectionDeadline;
        // Logo Split Address
        address splits;
        //bool isAccepted;
        Status status;
    }

}