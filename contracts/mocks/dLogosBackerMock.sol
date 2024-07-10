// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosBacker} from "../interfaces/IdLogosBacker.sol";
import {IDLogosOwner} from "../interfaces/IdLogosOwner.sol";
import {ILogo} from "../interfaces/ILogo.sol";

contract DLogosBackerMock {
    address public referrer1;
    address public referrer2;
    address public dLogosOwner;
    address[] public backerAddrs = [
        0x2F6EfC44c5f00679C57FE2134f51755f9068B517,
        0xA272896E12F741c9E82C67eC702BBFF95D4004cD
    ];

    constructor(address _dLogosOwner) {
        IDLogosOwner(_dLogosOwner).setDLogosBacker(address(this));
        dLogosOwner = _dLogosOwner;
    }

    function logoRewards(uint256) external pure returns (uint256) {
        return 1e15;
    }

    function logoRejectedFunds(uint256) external pure returns (uint256) {
        return 6 * 1e14;
    }

    function getBackersForLogo(
        uint256
    ) external view returns (IDLogosBacker.Backer[] memory backers) {
        backers = new IDLogosBacker.Backer[](2);
        backers[0] = IDLogosBacker.Backer({
            addr: backerAddrs[0],
            referrer: referrer1,
            votesToReject: false,
            amount: 1e14
        });
        backers[1] = IDLogosBacker.Backer({
            addr: backerAddrs[1],
            referrer: referrer2,
            votesToReject: false,
            amount: 9 * 1e14
        });
    }

    function getBackerForLogo(
        uint256,
        address _backerAddr
    ) external view returns (IDLogosBacker.Backer memory backer) {
        backer = IDLogosBacker.Backer({
            addr: _backerAddr,
            referrer: referrer1,
            votesToReject: false,
            amount: _backerAddr == backerAddrs[0] || _backerAddr == backerAddrs[1] ? 1e14 : 0
        });
    }

    function setReferrers(address _referrer1, address _referrer2) external {
        referrer1 = _referrer1;
        referrer2 = _referrer2;
    }

    function withdrawByDLogosCore(
        address _to,
        uint256 _amount
    ) external {
        payable(_to).call{value: _amount}("");
    }
}
