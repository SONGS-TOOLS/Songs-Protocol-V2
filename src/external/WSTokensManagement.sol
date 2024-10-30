// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Token management instance for each wrapped song
contract WSTokensManagement is ERC1155Supply, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant SONG_CONCEPT_ID = 0;
    uint256 public constant SONG_SHARES_ID = 1;
    uint256 public constant SONG_SELL_ID = 2;

    // Instance state
    uint256 public totalShares;
    IERC20 public stableCoin;
    address public creator;

    // Events
    event SharesCreated(uint256 amount);
    event SharesTransferred(address indexed from, address indexed to, uint256 amount);
    event SellTokenCreated(uint256 amount);

    constructor(
        address owner_, // WrappedSongSmartAccount address
        address creator_,
        address stableCoin_,
        uint256 totalShares_
    ) ERC1155("") Ownable(owner_) {
        creator = creator_;
        stableCoin = IERC20(stableCoin_);
        totalShares = totalShares_;

        // Mint SONG_CONCEPT_ID to the WrappedSongSmartAccount (owner)
        _mint(owner_, SONG_CONCEPT_ID, 1, "");
        // Mint SONG_SHARES_ID to the creator
        _mint(creator_, SONG_SHARES_ID, totalShares_, "");
        
        emit SharesCreated(totalShares_);
    }

    // Token functions
    function transferShares(address to_, uint256 amount_) external {
        require(balanceOf(msg.sender, SONG_SHARES_ID) >= amount_, "Insufficient balance");
        _safeTransferFrom(msg.sender, to_, SONG_SHARES_ID, amount_, "");
        emit SharesTransferred(msg.sender, to_, amount_);
    }

    // Create additional sell tokens
    function createSellToken(uint256 amount_) external onlyOwner {
        require(amount_ > 0, "Invalid amount");
        _mint(creator, SONG_SELL_ID, amount_, "");
        emit SellTokenCreated(amount_);
    }

    // View functions
    function getShareBalance(address account_) external view returns (uint256) {
        return balanceOf(account_, SONG_SHARES_ID);
    }

    function getSellTokenBalance(address account_) external view returns (uint256) {
        return balanceOf(account_, SONG_SELL_ID);
    }

    function getCreator() external view returns (address) {
        return creator;
    }

    // ERC1155 receiver functions
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
} 