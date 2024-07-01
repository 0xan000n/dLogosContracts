// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosCore} from "../interfaces/IdLogosCore.sol";
import {IDLogosBacker} from "../interfaces/IdLogosBacker.sol";
import {SplitV2Lib} from "../splitsV2/libraries/SplitV2.sol";
import {IPushSplitFactory} from "../splitsV2/interfaces/IPushSplitFactory.sol";
import {IPushSplit} from "../splitsV2/interfaces/IPushSplit.sol";

library DLogosSplitsHelper {
    // Address of native token, inline with ERC7528
    address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant PERCENTAGE_SCALE = 1e6;
    address internal constant PUSH_SPLIT_FACTORY = 0xaDC87646f736d6A82e9a6539cddC488b2aA07f38; // Base

    struct GetSpeakersSplitInfoParam {
        IDLogosCore.Speaker[] speakers;
        address dLogos;
        address community;
        address proposer;
        bool isZeroFeeProposer;
        uint256 dLogosFee;
        uint256 communityFee;
        uint256 proposerFee;
    }

    event SplitForAffiliateCreated(address indexed split, SplitV2Lib.Split, address owner, address creator);
    error TotalAllocationExceeded();
    error EthTransferFailed();

    function getAffiliatesSplitInfo(
        IDLogosBacker.Backer[] memory backers,
        uint256 affiliateFee
    ) external pure returns (
        uint256 totalRefRewards,
        SplitV2Lib.Split memory splitParam
    ) {
        address[] memory referrers = new address[](backers.length + 1);
        uint256[] memory allocations = new uint256[](backers.length + 1);
        uint256[] memory refRewards = new uint256[](backers.length + 1);

        uint256 _totalAllocation;

        unchecked {
            for (uint256 i = 0; i < backers.length; i++) {
                IDLogosBacker.Backer memory b = backers[i];
                address r = b.referrer;
                referrers[i] = r;
                if (r == address(0)) {
                    refRewards[i] = 0;
                } else {
                    refRewards[i] =
                        (b.amount * affiliateFee) /
                        PERCENTAGE_SCALE;
                }

                totalRefRewards += refRewards[i];
            }

            for (uint256 i = 0; i < backers.length; i++) {
                allocations[i] =
                    (refRewards[i] * PERCENTAGE_SCALE) /
                    totalRefRewards;
                _totalAllocation += allocations[i];
            }

            // Slippage
            // {_totalAllocation} SHOULD not be greater than {PERCENTAGE_SCALE}
            if (_totalAllocation < PERCENTAGE_SCALE) {
                // TODO check n+1 referrer address
                referrers[backers.length] = address(0);
                allocations[backers.length] =
                    PERCENTAGE_SCALE -
                    _totalAllocation;
            }
        }

        splitParam = SplitV2Lib.Split({
            recipients: referrers,
            allocations: allocations,
            totalAllocation: PERCENTAGE_SCALE,
            distributionIncentive: 0 // Set to 0
        });
    }

    function getSpeakersSplitInfo(
        GetSpeakersSplitInfoParam memory param
    )
        external
        pure
        returns (
            SplitV2Lib.Split memory splitParam
        )
    {
        uint256 i;
        address[] memory recipients = new address[](3 + param.speakers.length);
        uint256[] memory allocations = new uint256[](3 + param.speakers.length);
        // Assign recipients array
        recipients[0] = param.dLogos;
        recipients[1] = param.community;
        recipients[2] = param.proposer;
        for (i = 0; i < param.speakers.length; i++) {
            recipients[i + 3] = param.speakers[i].addr;
        }
        // Assign allocations array
        uint256 totalAllocation;
        if (param.isZeroFeeProposer) {
            allocations[0] = 0;
        } else {
            allocations[0] = param.dLogosFee;
        }
        allocations[1] = param.communityFee;
        allocations[2] = param.proposerFee;
        totalAllocation += allocations[0] + allocations[1] + allocations[2];
        for (i = 0; i < param.speakers.length; i++) {
            allocations[i + 3] = param.speakers[i].fee;
            totalAllocation += param.speakers[i].fee;
        }
        // Check total allocation equals to 1e6
        if (totalAllocation != PERCENTAGE_SCALE) revert TotalAllocationExceeded();

        splitParam = SplitV2Lib.Split({
            recipients: recipients,
            allocations: allocations,
            totalAllocation: PERCENTAGE_SCALE,
            distributionIncentive: 0 // Set to 0
        });
    }

    function deploySplitV2AndDistribute(
        SplitV2Lib.Split memory splitParam,
        uint256 amount
    ) external returns (address split) {
        split = IPushSplitFactory(PUSH_SPLIT_FACTORY).createSplit(
            splitParam, 
            address(this), // We do not need to set split owner 
            address(this) // creator
        );
        emit SplitForAffiliateCreated(split, splitParam, address(this), address(this));
        // Send Eth to PushSplit
        (bool success, ) = payable(split).call{value: amount}("");        
        if (!success) revert EthTransferFailed();
        // Distribute
        IPushSplit(split).distribute(
            splitParam,
            NATIVE_TOKEN,
            address(0) // distributor address
        );
    }
}
