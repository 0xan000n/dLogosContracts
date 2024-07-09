// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDLogosBacker {
    /// STRUCTS
    struct Backer {
        address addr;
        address referrer;
        bool votesToReject;
        uint256 amount;
    }
    
    /// EVENTS
    event Crowdfund(
        uint256 indexed _logoId,
        address indexed _owner, 
        uint256 indexed _amount
    );
    event FundsWithdrawn(
        uint256 indexed _logoId,
        address indexed _owner, 
        uint256 indexed _amount
    );
    event RejectionSubmitted(
        uint256 indexed _logoId, 
        address indexed _backer
    );

    /// FUNCTIONS
    function dLogosOwner() external view returns (address);
    function logoRewards(uint256) external view returns (uint256);
    function logoRejectedFunds(uint256) external view returns (uint256);
    function crowdfund(uint256, address) external payable;
    function withdrawFunds(uint256) external;
    function reject(uint256) external;
    function getBackersForLogo(uint256) external view returns (Backer[] memory);
    function getBackerForLogo(uint256, address) external view returns (Backer memory);
    function pauseOrUnpause(bool) external;
}
