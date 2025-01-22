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
    address public override operator;

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

    modifier onlyOperator() {
        if (msg.sender != operator) revert CallerNotOperator();
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
        operator = msg.sender;
        emit OperatorUpdated(msg.sender);
    }

    function setOperator(address _op) external onlyOwner {
        // Zero address possible
        operator = _op;
        emit OperatorUpdated(_op);
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        baseURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    function setTokenURI(
        uint256 _tokenId, 
        string memory _tokenURI
    ) external onlyOperator {
        super._setTokenURI(_tokenId, _tokenURI);
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
        uint256 firstTokenId = _tokenIdCounter + 1;
        uint256 lastTokenId = _tokenIdCounter + _recipients.length;
        
        unchecked {
            for (uint256 i = 0; i < _recipients.length; i++) {
                _safeMint(
                    SafeMintParam({
                        to: _recipients[i],
                        firstTokenId: firstTokenId,
                        tokenId: ++_tokenIdCounter,
                        lastTokenId: lastTokenId,
                        logoId: _logoId,
                        persona: _personas[i]
                    })
                );
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
        if (IDLogosCore(dLogosCore).getLogo(_logoId).splitForSpeaker == address(0)) revert LogoNotDistributed();

        uint256 _tokenIdCounter = tokenIdCounter;
        uint256 firstTokenId = _tokenIdCounter + 1;
        uint256 lastTokenId = _tokenIdCounter + _recipients.length;

        SafeMintParam memory param;

        IDLogosCore.Speaker[] memory speakers = IDLogosCore(dLogosCore)
            .getSpeakersForLogo(_logoId);
        for (uint256 i = 0; i < _recipients.length; i++) {
            address to = _recipients[i];
            Persona persona = _personas[i];

            if (persona != Persona.Undefined && persona == logoPersonas[_logoId][to]) 
                revert AlreadyMinted(to, _logoId, persona);

            param = SafeMintParam({
                to: to,
                firstTokenId: firstTokenId,
                tokenId: ++_tokenIdCounter,
                lastTokenId: lastTokenId,
                logoId: _logoId,
                persona: persona
            });

            if (persona == Persona.Backer) {
                if (
                    IDLogosBacker(dLogosBacker)
                        .getBackerForLogo(_logoId, to)
                        .amount != 0
                ) {
                    _safeMint(param);
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
                    _safeMint(param);
                } else {
                    revert NotEligibleForMint(to, _logoId);
                }                
            } else if (persona == Persona.Proposer) {
                address proposer = IDLogosCore(dLogosCore).getLogo(_logoId).proposer;
                if (proposer == to) {
                    _safeMint(param);
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

    function _safeMint(SafeMintParam memory _param) private {
        if (_param.persona == Persona.Undefined) revert UndefinedPersona(_param.to, _param.logoId);

        infos[_param.tokenId] = Info({
            logoId: _param.logoId, 
            persona: _param.persona
        });
        logoPersonas[_param.logoId][_param.to] = _param.persona;
        super._safeMint(_param.to, _param.tokenId);
        emit Minted(
            _param.to, 
            _param.firstTokenId, 
            _param.tokenId, 
            _param.lastTokenId, 
            _param.logoId, 
            _param.persona
        );    
    }
    
    // The following functions are overrides required by Solidity.
    function _update(
        address _to,
        uint256 _tokenId,
        address _auth
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
        returns (address)
    {
        address from = ERC721EnumerableUpgradeable._update(_to, _tokenId, _auth);
        Info memory info = infos[_tokenId];
        delete logoPersonas[info.logoId][from];
        logoPersonas[info.logoId][_to] = info.persona;
        emit TransferWithLogoId(from, _to, _tokenId, info.logoId);
        return from;
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
