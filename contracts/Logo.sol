// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Error.sol";

/// @custom:security-contact security@dlogos.xyz
contract Logo is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 public tokenIdCounter; // Starting from 1
    string public baseURI;
    address public dLogosCore;
    address public dLogosBacker;

    enum Status {
        Backer,
        Speaker
    }
    struct Info {
        address owner;
        uint256 logoId;
        Status status;
    }

    mapping(uint256 => Info) public infos;

    event Minted(address indexed _to, uint256 indexed _tokenId, uint256 indexed _logoId, bool _isBacker);
    event BaseURISet(string _baseURI);

    constructor(
        address _dLogosCore,
        address _dLogosBacker
    ) ERC721("Logo", "LOGO") Ownable(msg.sender) {
        if (_dLogosCore == address(0) || _dLogosBacker == address(0)) revert ZeroAddress();

        dLogosCore = _dLogosCore;
        dLogosBacker = _dLogosBacker;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string calldata baseURI_) external {
        baseURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    function safeMint(
        address _to, 
        string memory _uri,
        uint256 _logoId,
        bool _isBacker
    ) external {
        if (msg.sender != dLogosBacker && msg.sender != dLogosCore) revert CallerNotDLogos();

        uint256 tokenId = tokenIdCounter + 1;
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);
        infos[tokenId] = Info({
            owner: _to,
            logoId: _logoId,
            status: _isBacker ? Status.Backer : Status.Speaker
        });
        tokenIdCounter = tokenId;

        emit Minted(_to, tokenId, _logoId, _isBacker);
    }

    // The follong functions are overrides required by Solidity.
    function _update(
        address to, 
        uint256 tokenId, 
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return ERC721Enumerable._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account, 
        uint128 amount
    ) internal override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._increaseBalance(account, amount);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
