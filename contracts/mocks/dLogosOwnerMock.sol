// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

contract DLogosOwnerMock {
    mapping(address => bool) public zeroFeeProposers;

    address public community;

    function setZeroFeeProposer(
        address _proposer,
        bool _status
    ) external {
        zeroFeeProposers[_proposer] = _status;
    }

    function maxDuration() external pure returns (uint256) {
        return 60;
    }

    function communityFee() external pure returns (uint256) {
        return 1e5;
    }

    function dLogosFee() external pure returns (uint256) {
        return 1e5;
    }

    function isZeroFeeProposer(address _proposer) external view returns (bool) {
        return zeroFeeProposers[_proposer];
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

    function setCommunity(address _community) external {
        community = _community;
    }
}
