// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

contract DLogosOwnerMock {
    function maxDuration() external pure returns (uint256) {
        return 60;
    }

    function communityFee() external pure returns (uint256) {
        return 1e5;
    }

    function dLogosFee() external pure returns (uint256) {
        return 1e5;
    }

    function isZeroFeeProposer(address) external pure returns (bool) {
        return true;
    }

    function rejectThreshold() external pure returns (uint256) {
        return 5000;
    }

    function rejectionWindow() external pure returns (uint256) {
        return 7;
    }

    function affiliateFee() external pure returns (uint256) {
        return 5 * 1e4;
    }

    function dLogos() external pure returns (address) {
        return 0xaDC87646f736d6A82e9a6539cddC488b2aA07f38; // random address
    }

    function community() external pure returns (address) {
        return 0x0285B37453F73f8dE94De0cAEf8108bC8431BE34; // random address
    }
}
