// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosCore} from "../interfaces/IdLogosCore.sol";

contract DLogosCoreMock {
    mapping(uint256 => IDLogosCore.Logo) public logos;

    // default logo
    IDLogosCore.Logo sl = IDLogosCore.Logo({
        id: 1,
        title: "",
        mediaAssetURL: "",
        proposer: msg.sender,
        proposerFee: 0,
        scheduledAt: 0,
        minimumPledge: 10000000000000, // 0.00001 ETH
        crowdfundStartAt: 0,
        crowdfundEndAt: 0,
        rejectionDeadline: 0,
        splitForSpeaker: address(0),
        splitForAffiliate: address(0),
        status: IDLogosCore.LogoStatus(
            {
                isCrowdfunding: true,
                isUploaded: false,
                isDistributed: false,
                isRefunded: false
            }
        )
    });

    function init() external {
        // 1st logo is default
        IDLogosCore.Logo memory l1 = sl;
        l1.rejectionDeadline = block.timestamp + 7 days;
        logos[1] = l1;
        // 2nd logo is not crowdfunding
        IDLogosCore.Logo memory l2 = sl;
        l2.status.isCrowdfunding = false;
        logos[2] = l2;
        // 3rd logo is not created
        IDLogosCore.Logo memory l3 = sl;
        l3.proposer = address(0);
        logos[3] = l3;
        // 4th logo is uploaded and not refunded
        IDLogosCore.Logo memory l4 = sl;
        l4.scheduledAt = 12345678; // dummy timestamp
        logos[4] = l4;
        // 5th logo is distributed
        IDLogosCore.Logo memory l5 = sl;
        l5.status.isDistributed = true;
        logos[5] = l5;
    }
    
    function getLogo(uint256 _logoId) external view returns (IDLogosCore.Logo memory l) {
        l = logos[_logoId];
    }
}
