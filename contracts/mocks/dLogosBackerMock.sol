// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosBacker} from "../interfaces/IdLogosBacker.sol";
import {IDLogosOwner} from "../interfaces/IdLogosOwner.sol";

contract DLogosBackerMock {
    address public referrer1;
    address public referrer2;
    address public dLogosOwner;

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
            addr: 0xaDC87646f736d6A82e9a6539cddC488b2aA07f38,
            referrer: referrer1,
            votesToReject: false,
            amount: 1e14
        });
        backers[1] = IDLogosBacker.Backer({
            addr: 0x80f1B766817D04870f115fEBbcCADF8DBF75E017,
            referrer: referrer2,
            votesToReject: false,
            amount: 9 * 1e14
        });
    }

    function setReferrers(address _referrer1, address _referrer2) external {
        referrer1 = _referrer1;
        referrer2 = _referrer2;
    }
}
