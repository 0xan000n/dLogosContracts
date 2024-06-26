// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDLogosOwner {
    /// EVENTS
    event DLogosAddressUpdated(address _dLogos);
    event CommunityAddressUpdated(address _community);
    event DLogosFeeUpdated(uint256 _dLogosFee);
    event CommunityFeeUpdated(uint256 _communityFee);
    event AffiliateFeeUpdated(uint256 _affiliateFee);
    event RejectThresholdUpdated(uint16 indexed _fee);
    event MaxDurationUpdated(uint8 _maxDuration);
    event RejectinoWindowUpdated(uint8 _rejectionWindow);
    event ZeroFeeProposersSet(address[] _proposers, bool[] _statuses);

    function dLogos() external view returns (address);
    function community() external view returns (address);
    function dLogosFee() external view returns (uint256);
    function communityFee() external view returns (uint256);
    function affiliateFee() external view returns (uint256);
    function rejectThreshold() external view returns (uint16);
    function maxDuration() external view returns (uint8);
    function rejectionWindow() external view returns (uint8);
    function setRejectThreshold(uint16) external;
    function setMaxDuration(uint8) external;
    function setRejectionWindow(uint8) external;
    function setDLogosAddress(address) external;
    function setCommunityAddress(address) external;
    function setDLogosFee(uint256) external;
    function setCommunityFee(uint256) external;
    function setAffiliateFee(uint256) external;
    function setZeroFeeProposers(
        address[] calldata,
        bool[] calldata
    ) external;
    function isZeroFeeProposer(address) external view returns (bool);
}
