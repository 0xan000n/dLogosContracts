// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILogo {
    /// STRUCTS
    enum Status {
        Backer,
        Speaker
    }
    
    struct Info {
        address owner;
        uint256 logoId;
        Status status;
    }
    
    /// EVENTS
    event Minted(address indexed _to, uint256 indexed _tokenId, uint256 indexed _logoId, bool _isBacker);
    event BaseURISet(string _baseURI);

    /// FUNCTIONS
    function tokenIdCounter() external view returns (uint256);
    function baseURI() external view returns (string memory);
    function dLogosOwner() external view returns (address);
    function getInfo(uint256) external view returns (Info memory);
    function setBaseURI(string calldata) external;
    function safeMintBatch(address[] calldata, uint256, bool[] calldata) external;
    function pauseOrUnpause(bool) external;
}
