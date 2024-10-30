// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IWrappedSongEarnings {
    function receiveEarnings(address song_, address token_, uint256 amount_) external payable;
    function claimEarnings(address song_, address account_, address token_) external;
    function updateEarnings(address song_, address account_) external;
} 