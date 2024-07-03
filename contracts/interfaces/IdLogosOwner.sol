// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDLogosOwner {
    /// EVENTS
    event DLogosBackerUpdated(address indexed _dLogosBacker);
    event DLogosCoreUpdated(address indexed _dLogosCore);
    event LogoNFTUpdated(address indexed _logoNFT);
    event DLogosAddressUpdated(address indexed _dLogos);
    event CommunityAddressUpdated(address indexed _community);
    event DLogosFeeUpdated(uint256 indexed _dLogosFee);
    event CommunityFeeUpdated(uint256 indexed _communityFee);
    event AffiliateFeeUpdated(uint256 indexed _affiliateFee);
    event RejectThresholdUpdated(uint32 indexed _fee);
    event MaxDurationUpdated(uint8 indexed _maxDuration);
    event RejectionWindowUpdated(uint8 indexed _rejectionWindow);
    event ZeroFeeProposersUpdated(address[] _proposers, bool[] _statuses);

    function dLogosBacker() external view returns (address);
    function dLogosCore() external view returns (address);
    function logoNFT() external view returns (address);
    function dLogos() external view returns (address);
    function community() external view returns (address);
    function dLogosFee() external view returns (uint256);
    function communityFee() external view returns (uint256);
    function affiliateFee() external view returns (uint256);
    function rejectThreshold() external view returns (uint32);
    function maxDuration() external view returns (uint8);
    function rejectionWindow() external view returns (uint8);
    function setDLogosBacker(address) external;
    function setDLogosCore(address) external;
    function setLogoNFT(address) external;
    function setRejectThreshold(uint32) external;
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
