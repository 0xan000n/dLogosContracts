// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

// NoRefundConditionsMet
error NRCM();

// Unauthorized
error U();

// EmptyString
error ES();

// NotZero
error NZ();

// ZeroAddress
error ZA();

// InvalidLogoId
error ILI();

// InvalidMaxDuration
error IMD();

// CrowdfundDurationExceeded
error CDE();

// InvalidRejectThreshold
error IRT();

// LogoUploaded
error LU();

// LogoNotUploaded
error LNU();

// LogoDistributed
error LD();

// LogoRefunded
error LR();

// LogoNotCrowdfunding
error LNC();

// InsufficientFunds
error IF();

// TooManyBackers
error TMB();

// LogoFundsCannotBeWithdrawn
error LFCBW();

// InsufficientLogoReward
error ILR();

// AddBackerFailed
error ABF();

// RemoveBackerFailed
error RBF();

// EthTransferFailed
error ETF();

// InvalidSpeakerNumber
error ISN();

// InvalidArrayArguments
error IAA();

// InvalidScheduleTime
error IST();

// InvalidSpeakerStatus
error ISS();

// TotalAllocationExceeded
error TAE();

// FeeExceeded
error FE();

// ZeroFeeProposer
error ZFP();

// FeeSumNotMatch
error FSNM();

// AffiliateFeeExceeded
error AFE();

// NotAllSpeakersAccepted
error NASA();

// CrowdfundEnded
error CE();

// AffiliateRewardsExceeded
error ARE();

// InvalidRejectionWindow
error IRW();

// RejectionDeadlineNotPassed
error RDNP();

// RejectionDeadlinePassed
error RDP();
