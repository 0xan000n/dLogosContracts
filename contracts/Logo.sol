// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ILogo} from "./interfaces/ILogo.sol";
import {IDLogosCore} from "./interfaces/IdLogosCore.sol";
import {IDLogosOwner} from "./interfaces/IdLogosOwner.sol";
import "./Error.sol";

/// @custom:security-contact security@dlogos.xyz
contract Logo is 
    ILogo, 
    ERC721Upgradeable, 
    ERC721EnumerableUpgradeable, 
    ERC721URIStorageUpgradeable, 
    Ownable2StepUpgradeable,
    PausableUpgradeable 
{
    uint256 public override tokenIdCounter; // Starting from 1
    string public override baseURI;
    address public override dLogosOwner;

    mapping(uint256 => Info) public infos;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// MODIFIERS
    modifier notZeroAddress(address _addr) {
        if (_addr == address(0)) revert ZeroAddress();
        _;
    }

    function initialize(        
        address _dLogosOwner
    ) external initializer notZeroAddress(_dLogosOwner) {
        __Ownable_init(msg.sender);
        __ERC721_init("Logo", "LOGO");
        // __Pausable_init();
    
        IDLogosOwner(_dLogosOwner).setLogoNFT(address(this));
        dLogosOwner = _dLogosOwner;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        baseURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    function safeMintBatchByDLogosCore(
        address[] calldata _recipients, 
        uint256 _logoId,
        bool[] calldata _isBackers
    ) external {
        if (msg.sender != IDLogosOwner(dLogosOwner).dLogosCore()) revert CallerNotDLogosCore();
        if (_recipients.length != _isBackers.length) revert InvalidArrayArguments();

        uint256 _tokenIdCounter = tokenIdCounter;
        unchecked {
            for (uint256 i = 0; i < _recipients.length; i++) {
                _safeMint(_recipients[i], ++_tokenIdCounter);
                infos[_tokenIdCounter] = Info({
                    logoId: _logoId,
                    status: _isBackers[i] ? Status.Backer : Status.Speaker
                });
                emit Minted(_recipients[i], _tokenIdCounter, _logoId, _isBackers[i]);
            }
        }
        tokenIdCounter = _tokenIdCounter;
    }

    // function safeMintBatch(
    //     address[] calldata _recipients, 
    //     uint256 _logoId,
    //     bool[] calldata _isBackers
    // ) external {
    //     if (_recipients.length != _isBackers.length) revert InvalidArrayArguments();

    //     address dLogosCore = IDLogosOwner(dLogosOwner).dLogosCore();
    //     IDLogosCore.Logo memory l = IDLogosCore(dLogosCore).getLogo(_logoId);
    //     if (!l.status.isDistributed) revert LogoNotDistributed();
    // }

    function getInfo(uint256 _tokenId) external override view returns (Info memory i) {
        i = infos[_tokenId];
    }
    
    /**
     * @dev Pause or unpause the contract
     * Only `owner` can call
     */
    function pauseOrUnpause(bool _pause) external override onlyOwner {
        if (_pause) {
            super._pause();
        } else {
            super._unpause();
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address to, 
        uint256 tokenId, 
        address auth
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) whenNotPaused returns (address) {
        return ERC721EnumerableUpgradeable._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account, 
        uint128 amount
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        ERC721EnumerableUpgradeable._increaseBalance(account, amount);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
