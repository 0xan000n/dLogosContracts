// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosCore} from "../interfaces/IdLogosCore.sol";
import {IDLogosOwner} from "../interfaces/IdLogosOwner.sol";
import {ILogo} from "../interfaces/ILogo.sol";

contract DLogosCoreMock {
    address public dLogosOwner;
    address[] public recipients = [
        0x3E64F4Fa20a0673d982EceECC2D29B2c242c9508,
        0xcc2Fd4442d7A3AB38144D13565D4489601E73cD5,
        0x2F6EfC44c5f00679C57FE2134f51755f9068B517
    ];
    ILogo.Status[] public statuses = [
        ILogo.Status.Backer, 
        ILogo.Status.Speaker,
        ILogo.Status.Proposer
    ];
    // Used for safeMintBatchByDLogosCore() failure.
    ILogo.Status[] private _statusesIAA = [
        ILogo.Status.Backer
    ];
    ILogo.Status[] private _statusesIS = [
        ILogo.Status.Backer, 
        ILogo.Status.Speaker,
        ILogo.Status.Undefined
    ];

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
        crowdfundStartAt: block.timestamp,
        crowdfundEndAt: block.timestamp + 40 * 1 days,
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

    constructor(address _dLogosOwner) {
        IDLogosOwner(_dLogosOwner).setDLogosCore(address(this));
        dLogosOwner = _dLogosOwner;
    }

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
        l4.mediaAssetURL = "http://x.com/dlogos-xyz-1";
        logos[4] = l4;
        // 5th logo is distributed
        IDLogosCore.Logo memory l5 = sl;
        l5.status.isDistributed = true;
        logos[5] = l5;
    }
    
    function getLogo(uint256 _logoId) external view returns (IDLogosCore.Logo memory l) {
        l = logos[_logoId];
    }

    function distributeRewards(uint256 _logoId, bool) external {
        address logoNFT = IDLogosOwner(dLogosOwner).logoNFT();
        ILogo(logoNFT).safeMintBatchByDLogosCore(
            recipients,
            _logoId,
            statuses
        );
    }
    
    // This function call is to fail by InvalidArrayArguments error
    function distributeRewardsToFailByIAA(uint256 _logoId, bool) external {
        address logoNFT = IDLogosOwner(dLogosOwner).logoNFT();
        ILogo(logoNFT).safeMintBatchByDLogosCore(
            recipients,
            _logoId,
            _statusesIAA
        );
    }

    // This function call is to fail by InvalidStatus error
    function distributeRewardsToFailByIS(uint256 _logoId, bool) external {
        address logoNFT = IDLogosOwner(dLogosOwner).logoNFT();
        ILogo(logoNFT).safeMintBatchByDLogosCore(
            recipients,
            _logoId,
            _statusesIS
        );
    }
}
