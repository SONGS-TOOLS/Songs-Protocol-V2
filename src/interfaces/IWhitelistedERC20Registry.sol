// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IWhitelistedERC20Registry {
    function isTokenWhitelisted(address token_) external view returns (bool);
    function whitelistToken(address token_) external;
    function removeTokenFromWhitelist(address token_) external;
    function setAuthorizedCaller(address caller_) external;
} 