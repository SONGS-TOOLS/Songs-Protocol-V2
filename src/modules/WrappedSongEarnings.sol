// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Module, Keycode, toKeycode} from "../Kernel.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWrappedSongToken {
    function getTotalShares(address song_) external view returns (uint256);
    function getShareBalance(address song_, address account_) external view returns (uint256);
}

/// @notice WrappedSong Earnings management module
contract WEARN is Module {
    using SafeERC20 for IERC20;

    // Dependencies
    IWrappedSongToken public immutable WSTK;

    // Earnings state
    struct EarningsConfig {
        uint256 accumulatedEarningsPerShare;
        uint256 totalDistributedEarnings;
        uint256 ethBalance;
    }

    // Storage
    mapping(address => EarningsConfig) public songEarnings;
    mapping(address => mapping(address => uint256)) public unclaimedEarnings;
    mapping(address => mapping(address => uint256)) public lastClaimedEarningsPerShare;
    mapping(address => mapping(address => uint256)) public totalEarnings;
    mapping(address => mapping(address => uint256)) public redeemedEarnings;

    // Token tracking
    mapping(address => address[]) public receivedTokens;
    mapping(address => mapping(address => bool)) public isTokenReceived;

    // Events (maintaining original naming)
    event EarningsReceived(address indexed token, uint256 amount, uint256 earningsPerShare);
    event EarningsClaimed(address indexed account, address indexed token, uint256 amount, uint256 totalAmount);
    event EarningsUpdated(address indexed account, uint256 newEarnings, uint256 totalEarnings);
    event FundsReceived(address indexed from, uint256 amount, string currency);

    constructor(
        Kernel kernel_,
        IWrappedSongToken wstk_
    ) Module(kernel_) {
        WSTK = wstk_;
    }

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("EARN");
    }

    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    // Original function names from WrappedSongSmartAccount
    function receiveEarnings(
        address song_,
        address token_,
        uint256 amount_
    ) external payable permissioned {
        if (token_ == address(0)) {
            require(msg.value == amount_, "EARN: incorrect ETH amount");
            songEarnings[song_].ethBalance += msg.value;
        } else {
            IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);
            if (!isTokenReceived[song_][token_]) {
                receivedTokens[song_].push(token_);
                isTokenReceived[song_][token_] = true;
            }
        }

        _processEarnings(song_, token_, amount_);
        emit FundsReceived(msg.sender, amount_, token_ == address(0) ? "ETH" : "ERC20");
    }

    function claimEarnings(
        address song_,
        address account_,
        address token_
    ) external permissioned {
        _updateEarnings(song_, account_);

        uint256 totalAmount = unclaimedEarnings[song_][account_];
        require(totalAmount > 0, "EARN: no earnings to claim");

        if (token_ == address(0)) {
            uint256 ethShare = (songEarnings[song_].ethBalance * totalAmount) / songEarnings[song_].totalDistributedEarnings;
            require(ethShare > 0, "EARN: no ETH earnings");
            songEarnings[song_].ethBalance -= ethShare;
            (bool success, ) = account_.call{value: ethShare}("");
            require(success, "EARN: ETH transfer failed");
            emit EarningsClaimed(account_, token_, ethShare, totalAmount);
        } else {
            uint256 tokenBalance = IERC20(token_).balanceOf(address(this));
            uint256 tokenShare = (tokenBalance * totalAmount) / songEarnings[song_].totalDistributedEarnings;
            require(tokenShare > 0, "EARN: no token earnings");
            IERC20(token_).safeTransfer(account_, tokenShare);
            emit EarningsClaimed(account_, token_, tokenShare, totalAmount);
        }

        unclaimedEarnings[song_][account_] = 0;
        redeemedEarnings[song_][account_] += totalAmount;
    }

    function updateEarnings(
        address song_,
        address account_
    ) external permissioned {
        _updateEarnings(song_, account_);
    }

    // Internal functions
    function _processEarnings(
        address song_,
        address token_,
        uint256 amount_
    ) internal {
        uint256 totalShares = WSTK.getTotalShares(song_);
        require(totalShares > 0, "EARN: no shares exist");

        uint256 earningsPerShare = (amount_ * 1e18) / totalShares;
        songEarnings[song_].accumulatedEarningsPerShare += earningsPerShare;
        songEarnings[song_].totalDistributedEarnings += amount_;

        emit EarningsReceived(token_, amount_, earningsPerShare);
    }

    function _updateEarnings(address song_, address account_) internal {
        uint256 shares = WSTK.getShareBalance(song_, account_);
        uint256 newEarnings = (shares * songEarnings[song_].accumulatedEarningsPerShare) / 1e18 -
            lastClaimedEarningsPerShare[song_][account_];

        if (newEarnings > 0) {
            unclaimedEarnings[song_][account_] += newEarnings;
            lastClaimedEarningsPerShare[song_][account_] = songEarnings[song_].accumulatedEarningsPerShare;
            totalEarnings[song_][account_] += newEarnings;
            emit EarningsUpdated(account_, newEarnings, totalEarnings[song_][account_]);
        }
    }

    // View functions
    function getReceivedTokens(address song_) external view returns (address[] memory) {
        return receivedTokens[song_];
    }

    function getEarningsConfig(address song_) external view returns (EarningsConfig memory) {
        return songEarnings[song_];
    }

    // To receive ETH payments
    receive() external payable {}
}
