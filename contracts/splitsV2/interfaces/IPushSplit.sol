// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {SplitV2Lib} from "../libraries/SplitV2.sol";

interface IPushSplit {
    function distribute(
        SplitV2Lib.Split calldata _split, 
        address _token, 
        address _distributor
    ) external;

    function distribute(
        SplitV2Lib.Split calldata _split,
        address _token,
        uint256 _distributeAmount,
        bool _performWarehouseTransfer,
        address _distributor
    ) external;

    function updateSplit(
        SplitV2Lib.Split calldata _split
    ) external;
}
