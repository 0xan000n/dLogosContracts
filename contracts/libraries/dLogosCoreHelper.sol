// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosOwner} from "../interfaces/IdLogosOwner.sol";
import {IDLogosCore} from "../interfaces/IdLogosCore.sol";
import {IDLogosBacker} from "../interfaces/IdLogosBacker.sol";
import {ILogo} from "../interfaces/ILogo.sol";
import {SplitV2Lib} from "../splitsV2/libraries/SplitV2.sol";
import {IPushSplitFactory} from "../splitsV2/interfaces/IPushSplitFactory.sol";
import {IPushSplit} from "../splitsV2/interfaces/IPushSplit.sol";

library DLogosCoreHelper {
    // Address of native token, inline with ERC7528
    address internal constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant PERCENTAGE_SCALE = 1e6;
    address internal constant PUSH_SPLIT_FACTORY =
        0xaDC87646f736d6A82e9a6539cddC488b2aA07f38; // Base

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

    event SplitForAffiliateCreated(
        address indexed split,
        SplitV2Lib.Split,
        address owner,
        address creator
    );
    error TotalAllocationExceeded();
    error EthTransferFailed();

    function getAffiliatesSplitInfo(
        IDLogosBacker.Backer[] memory backers,
        uint256 affiliateFee
    )
        external
        view
        returns (uint256 totalRefRewards, SplitV2Lib.Split memory splitParam)
    {
        address[] memory referrers;
        uint256[] memory allocations;
        unchecked {
            referrers = new address[](backers.length + 1);
            allocations = new uint256[](backers.length + 1);
            uint256[] memory refRewards = new uint256[](backers.length + 1);

            uint256 _totalAllocation;

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

            if (totalRefRewards != 0) {
                for (uint256 i = 0; i < backers.length; i++) {
                    allocations[i] =
                        (refRewards[i] * PERCENTAGE_SCALE) /
                        totalRefRewards;
                    _totalAllocation += allocations[i];
                }

                // Slippage
                // {_totalAllocation} SHOULD not be greater than {PERCENTAGE_SCALE}
                if (_totalAllocation < PERCENTAGE_SCALE) {
                    // return to distributor
                    referrers[backers.length] = msg.sender;
                    allocations[backers.length] =
                        PERCENTAGE_SCALE -
                        _totalAllocation;
                }                
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
    ) external pure returns (SplitV2Lib.Split memory splitParam) {
        uint256 totalAllocation;
        address[] memory recipients;
        uint256[] memory allocations;

        unchecked {
            uint256 i;
            recipients = new address[](3 + param.speakers.length);
            allocations = new uint256[](3 + param.speakers.length);
            // Assign recipients array
            recipients[0] = param.dLogos;
            recipients[1] = param.community;
            recipients[2] = param.proposer;
            for (i = 0; i < param.speakers.length; i++) {
                recipients[i + 3] = param.speakers[i].addr;
            }
            // Assign allocations array
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
        }

        // Check total allocation equals to 1e6
        if (totalAllocation != PERCENTAGE_SCALE)
            revert TotalAllocationExceeded();

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
        emit SplitForAffiliateCreated(
            split,
            splitParam,
            address(this),
            address(this)
        );
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

    function safeMintNFT(
        address _dLogosOwner,
        uint256 _logoId,
        address _proposer,
        IDLogosBacker.Backer[] memory _backers,
        IDLogosCore.Speaker[] memory _speakers
    ) external {
        address[] memory nftRecipients;
        ILogo.Persona[] memory personas;

        unchecked {
            uint256 len = _backers.length + _speakers.length + 1;
            nftRecipients = new address[](len);
            personas = new ILogo.Persona[](len);

            for (uint256 i = 0; i < _backers.length; i++) {
                nftRecipients[i] = _backers[i].addr;
                personas[i] = ILogo.Persona.Backer;
            }
            for (uint256 i = 0; i < _speakers.length; i++) {
                uint256 _i = i + _backers.length;
                nftRecipients[_i] = _speakers[i].addr;
                personas[_i] = ILogo.Persona.Speaker;
            }
            
            nftRecipients[len - 1] = _proposer;
            personas[len - 1] = ILogo.Persona.Proposer;
        }

        address logoNFT = IDLogosOwner(_dLogosOwner).logoNFT();
        ILogo(logoNFT).safeMintBatchByDLogosCore(nftRecipients, _logoId, personas);
    }
}
