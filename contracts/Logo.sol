// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILogo} from "./interfaces/ILogo.sol";
import {IDLogosOwner} from "./interfaces/IdLogosOwner.sol";
import "./Error.sol";

/// @custom:security-contact security@dlogos.xyz
contract Logo is ILogo, ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 public override tokenIdCounter; // Starting from 1
    string public override baseURI;
    address public override dLogosOwner;

    mapping(uint256 => Info) public infos;

    constructor(
        address _dLogosOwner
    ) ERC721("Logo", "LOGO") Ownable(msg.sender) {
        if (_dLogosOwner == address(0)) revert ZeroAddress();

        IDLogosOwner(_dLogosOwner).setLogoNFT(address(this));
        dLogosOwner = _dLogosOwner;
    }   

    function setBaseURI(string calldata baseURI_) external {
        baseURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    function safeMint(
        address _to, 
        uint256 _logoId,
        bool _isBacker
    ) external {
        if (
            msg.sender != IDLogosOwner(dLogosOwner).dLogosBacker() 
            && 
            msg.sender != IDLogosOwner(dLogosOwner).dLogosCore()
        ) revert CallerNotDLogos();

        uint256 tokenId = tokenIdCounter + 1;
        _safeMint(_to, tokenId);
        infos[tokenId] = Info({
            owner: _to,
            logoId: _logoId,
            status: _isBacker ? Status.Backer : Status.Speaker
        });
        tokenIdCounter = tokenId;

        emit Minted(_to, tokenId, _logoId, _isBacker);
    }

    function getInfo(uint256 _tokenId) external override view returns (Info memory i) {
        i = infos[_tokenId];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
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
