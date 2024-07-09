// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ILogo} from "./interfaces/ILogo.sol";

error NoRefundConditionsMet();

error Unauthorized();

error EmptyString();

error NotZero();

error ZeroAddress();

error InvalidLogoId();

error InvalidMaxDuration();

error CrowdfundDurationExceeded();

error InvalidRejectThreshold();

error LogoUploaded();

error LogoNotUploaded();

error LogoDistributed();

error LogoRefunded();

error LogoNotCrowdfunding();

error InsufficientFunds();

error TooManyBackers();

error LogoFundsCannotBeWithdrawn();

error InsufficientLogoRewards();

error AddBackerFailed();

error RemoveBackerFailed();

error EthTransferFailed();

error InvalidSpeakerNumber();

error InvalidArrayArguments();

error InvalidScheduleTime();

error InvalidSpeakerStatus();

error FeeExceeded();

error FeeSumNotMatch();

error NotAllSpeakersAccepted();

error CrowdfundEnded();

error CrowdfundClosed();

error AffiliateRewardsExceeded();

error InvalidRejectionWindow();

error RejectionDeadlineNotPassed();

error RejectionDeadlinePassed();

error BackerAlreadyRejected();

error LogoNotScheduled();

error ConvoNotHappened();

error CallerNotDLogosCore();

error DirectCallNotAllowed();

error LogoNotDistributed();

error NotEligibleForMint(address _addr, uint256 _logoId);

error AlreadyMinted(address _addr, uint256 _logoId, ILogo.Status status);

error UndefinedStatus(address _addr, uint256 _logoId);
