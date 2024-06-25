// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

// NoRefundConditionsMet
error NoRefundConditionsMet();

// Unauthorized
error Unauthorized();

// EmptyString
error EmptyString();

// NotZero
error NotZero();

// ZeroAddress
error ZeroAddress();

// InvalidLogoId
error InvalidLogoId();

// InvalidMaxDuration
error InvalidMaxDuration();

// CrowdfundDurationExceeded
error CrowdfundDurationExceeded();

// InvalidRejectThreshold
error InvalidRejectThreshold();

// LogoUploaded
error LogoUploaded();

// LogoNotUploaded
error LogoNotUploaded();

// LogoDistributed
error LogoDistributed();

// LogoRefunded
error LogoRefunded();

// LogoNotCrowdfunding
error LogoNotCrowdfunding();
// error LNC();

// InsufficientFunds
error InsufficientFunds();

// TooManyBackers
error TooManyBackers();

// LogoFundsCannotBeWithdrawn
error LogoFundsCannotBeWithdrawn();

// InsufficientLogoReward
error InsufficientLogoReward();

// AddBackerFailed
error AddBackerFailed();

// RemoveBackerFailed
error RemoveBackerFailed();

// EthTransferFailed
error EthTransferFailed();

// InvalidSpeakerNumber
error InvalidSpeakerNumber();

// InvalidArrayArguments
error InvalidArrayArguments();

// InvalidScheduleTime
error InvalidScheduleTime();

// InvalidSpeakerStatus
error InvalidSpeakerStatus();

// FeeExceeded
error FeeExceeded();

// FeeSumNotMatch
error FeeSumNotMatch();

// NotAllSpeakersAccepted
error NotAllSpeakersAccepted();

// CrowdfundEnded
error CrowdfundEnded();

// AffiliateRewardsExceeded
error AffiliateRewardsExceeded();

// InvalidRejectionWindow
error InvalidRejectionWindow();

// RejectionDeadlineNotPassed
error RejectionDeadlineNotPassed();

// RejectionDeadlinePassed
error RejectionDeadlinePassed();

// BackerAlreadyRejected
error BackerAlreadyRejected();
