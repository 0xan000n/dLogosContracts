// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosCore} from "../interfaces/IdLogosCore.sol";

contract DLogosCoreMock {
    mapping(uint256 => IDLogosCore.Logo) public logos;

    function init() external {
        // default logo
        IDLogosCore.Logo memory l1 = IDLogosCore.Logo({
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
        // 1st logo is default
        logos[1] = l1;
        // 2nd logo is not crowdfunding
        IDLogosCore.Logo memory l2 = l1;
        l2.status.isCrowdfunding = false;
        logos[2] = l2;
        // 3rd logo is not created
        IDLogosCore.Logo memory l3 = l1;
        l3.proposer = address(0);
        logos[3] = l3;
    }
    
    function getLogo(uint256 _logoId) external view returns (IDLogosCore.Logo memory l) {
        l = logos[_logoId];
    }
}
