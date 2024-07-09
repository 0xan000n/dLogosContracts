// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IDLogosOwner} from "../interfaces/IdLogosOwner.sol";
import {ILogo} from "../interfaces/ILogo.sol";

contract LogoMock {
    address public dLogosOwner;

    constructor(address _dLogosOwner) {
        IDLogosOwner(_dLogosOwner).setLogoNFT(address(this));
        dLogosOwner = _dLogosOwner;
    }

    function safeMintBatchByDLogosCore(
        address[] calldata, 
        uint256, 
        ILogo.Status[] calldata
    ) external {}
}
