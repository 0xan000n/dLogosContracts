// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILogo {
    /// STRUCTS
    enum Status {
        Undefined,
        Backer,
        Speaker,
        Proposer
    }
    
    struct Info {
        uint256 logoId;
        Status status;
    }
    
    /// EVENTS
    event Minted(address indexed _to, uint256 indexed _tokenId, uint256 indexed _logoId, Status _status);
    event BaseURISet(string _baseURI);

    /// FUNCTIONS
    function tokenIdCounter() external view returns (uint256);
    function baseURI() external view returns (string memory);
    function dLogosOwner() external view returns (address);
    function getInfo(uint256) external view returns (Info memory);
    function setBaseURI(string calldata) external;
    function safeMintBatchByDLogosCore(address[] calldata, uint256, Status[] calldata) external;
    function safeMintBatch(address[] calldata, uint256, Status[] calldata) external;
    function pauseOrUnpause(bool) external;
}
