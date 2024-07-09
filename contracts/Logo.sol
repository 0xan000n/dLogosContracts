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
import {IDLogosBacker} from "./interfaces/IdLogosBacker.sol";
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

    mapping(uint256 => Info) public infos; // Mapping of token id to logo related info 
    mapping(uint256 => mapping(address => Persona)) public logoPersonas; // Mapping of logo id to address to persona

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
        Persona[] calldata _personas
    ) external override {
        if (msg.sender != IDLogosOwner(dLogosOwner).dLogosCore())
            revert CallerNotDLogosCore();
        if (_recipients.length != _personas.length)
            revert InvalidArrayArguments();

        uint256 _tokenIdCounter = tokenIdCounter;
        unchecked {
            for (uint256 i = 0; i < _recipients.length; i++) {
                _safeMint(_recipients[i], ++_tokenIdCounter, _logoId, _personas[i]);
            }
        }
        tokenIdCounter = _tokenIdCounter;
    }

    function safeMintBatch(
        address[] calldata _recipients,
        uint256 _logoId,
        Persona[] calldata _personas
    ) external override {
        if (_recipients.length != _personas.length)
            revert InvalidArrayArguments();

        address dLogosCore = IDLogosOwner(dLogosOwner).dLogosCore();
        address dLogosBacker = IDLogosOwner(dLogosOwner).dLogosBacker();
        IDLogosCore.Logo memory l = IDLogosCore(dLogosCore).getLogo(_logoId);
        if (!l.status.isDistributed) revert LogoNotDistributed();

        uint256 _tokenIdCounter = tokenIdCounter;
        IDLogosCore.Speaker[] memory speakers = IDLogosCore(dLogosCore)
            .getSpeakersForLogo(_logoId);
        for (uint256 i = 0; i < _recipients.length; i++) {
            address to = _recipients[i];
            Persona persona = _personas[i];

            if (persona != Persona.Undefined && persona == logoPersonas[_logoId][to]) 
                revert AlreadyMinted(to, _logoId, persona);

            if (persona == Persona.Backer) {
                if (
                    IDLogosBacker(dLogosBacker)
                        .getBackerForLogo(_logoId, to)
                        .amount != 0
                ) {
                    _safeMint(to, ++_tokenIdCounter, _logoId, persona);
                } else {
                    revert NotEligibleForMint(to, _logoId);
                }
            } else if (persona == Persona.Speaker) {
                uint256 j;
                for (j = 0; j < speakers.length; j++) {
                    if (to == speakers[j].addr) {
                        break;
                    }
                }
                if (j < speakers.length) {
                    _safeMint(to, ++_tokenIdCounter, _logoId, persona);
                } else {
                    revert NotEligibleForMint(to, _logoId);
                }
            } else if (persona == Persona.Proposer) {
                address proposer = IDLogosCore(dLogosCore).getLogo(_logoId).proposer;
                if (proposer == to) {
                    _safeMint(to, ++_tokenIdCounter, _logoId, persona);
                } else {
                    revert NotEligibleForMint(to, _logoId);
                }
            } else {
                // Persona is {Persona.Undefined}
                revert UndefinedPersona(to, _logoId);
            }
        }

        tokenIdCounter = _tokenIdCounter;
    }

    function getInfo(
        uint256 _tokenId
    ) external view override returns (Info memory i) {
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

    function _safeMint(
        address _to,
        uint256 _tokenId,
        uint256 _logoId,
        Persona _persona
    ) private {
        if (_persona == Persona.Undefined) revert UndefinedPersona(_to, _logoId);

        super._safeMint(_to, _tokenId);
        infos[_tokenId] = Info({
            logoId: _logoId, 
            persona: _persona
        });
        logoPersonas[_logoId][_to] = _persona;
        emit Minted(_to, _tokenId, _logoId, _persona);
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
        returns (address)
    {
        return ERC721EnumerableUpgradeable._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 amount
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        ERC721EnumerableUpgradeable._increaseBalance(account, amount);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
