// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosBacker} from "../interfaces/IdLogosBacker.sol";

contract DLogosBackerMock {
    function logoRewards(uint256) external pure returns (uint256) {
        return 1e15;
    }

    function logoRejectedFunds(uint256) external pure returns (uint256) {
        return 6 * 1e14;
    }

    function getBackersForLogo(uint256) external pure returns (IDLogosBacker.Backer[] memory backers) {
        backers = new IDLogosBacker.Backer[](2);
        backers[0] = IDLogosBacker.Backer({
            addr: 0xaDC87646f736d6A82e9a6539cddC488b2aA07f38,
            referrer: 0x0285B37453F73f8dE94De0cAEf8108bC8431BE34,
            votesToReject: false,
            amount: 1e14
        });
        backers[0] = IDLogosBacker.Backer({
            addr: 0x80f1B766817D04870f115fEBbcCADF8DBF75E017,
            referrer: 0x6291497D1206618fC810900d2e7e9AF6Aa1F1b99,
            votesToReject: false,
            amount: 9 * 1e14
        });
    }
}
