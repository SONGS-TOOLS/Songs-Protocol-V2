// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Module, Keycode, toKeycode} from "../Kernel.sol";

interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/// @notice Whitelisted ERC20 Tokens management module
contract W20TKNS is Module {
    mapping(address => bool) public whitelistedTokens;
    address public authorizedCaller;

    // Events from original ERC20Whitelist
    event TokenWhitelisted(address indexed token, string name, string symbol);
    event TokenRemovedFromWhitelist(address indexed token);
    event AuthorizedCallerSet(address indexed caller);
    
    constructor(Kernel kernel_) Module(kernel_) {}

    /// @notice Initialize module
    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("W20T");
    }

    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    // Original function names from ERC20Whitelist
    function whitelistToken(address token_) external permissioned {
        require(token_ != address(0), "W20T: invalid token");
        require(!whitelistedTokens[token_], "W20T: already whitelisted");
        
        IERC20Metadata tokenMetadata = IERC20Metadata(token_);
        string memory name = tokenMetadata.name();
        string memory symbol = tokenMetadata.symbol();
        
        whitelistedTokens[token_] = true;
        emit TokenWhitelisted(token_, name, symbol);
    }

    function removeTokenFromWhitelist(address token_) external permissioned {
        require(whitelistedTokens[token_], "W20T: not whitelisted");
        whitelistedTokens[token_] = false;
        emit TokenRemovedFromWhitelist(token_);
    }

    function setAuthorizedCaller(address caller_) external permissioned {
        authorizedCaller = caller_;
        emit AuthorizedCallerSet(caller_);
    }

    // View functions
    function isTokenWhitelisted(address token_) external view returns (bool) {
        return whitelistedTokens[token_];
    }

    function getWhitelistedTokenCount() external view returns (uint256) {
        uint256 count;
        // Note: This is a simplified version. In production, consider using EnumerableSet
        for (uint256 i = 0; i < 2**160; i++) {
            address token = address(uint160(i));
            if (whitelistedTokens[token]) count++;
            if (token == address(type(uint160).max)) break;
        }
        return count;
    }
}
