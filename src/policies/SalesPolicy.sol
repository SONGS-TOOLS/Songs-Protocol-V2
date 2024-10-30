// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Policy} from "../Kernel.sol";
import {toKeycode} from "../Kernel.sol";

import {WrappedSongToken} from "../modules/WrappedSongToken.sol";
import {WrappedSongSales} from "../modules/WrappedSongSales.sol";
import {WhitelistedERC20Registry} from "../modules/WhitelistedERC20Registry.sol";
import {SongRegistry} from "../modules/SongRegistry.sol";

/// @notice Policy for managing song share sales
contract SalesPolicy is Policy {
    // Module keycodes
    WrappedSongToken public immutable WSTK;
    WrappedSongSales public immutable WSAL;
    WhitelistedERC20Registry public immutable W20T;
    SongRegistry public immutable SONG;

    constructor(
        Kernel kernel_,
        WrappedSongToken wstk_,
        WrappedSongSales wsal_,
        WhitelistedERC20Registry w20t_,
        SongRegistry song_
    ) Policy(kernel_) {
        WSTK = wstk_;
        WSAL = wsal_;
        W20T = w20t_;
        SONG = song_;
    }

    // Permissioned module functions
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](4);
        dependencies[0] = toKeycode("WSTK");
        dependencies[1] = toKeycode("WSAL");
        dependencies[2] = toKeycode("W20T");
        dependencies[3] = toKeycode("SONG");
    }

    function requestPermissions() external view override returns (Permissions[] memory requests) {
        requests = new Permissions[](4);
        requests[0] = Permissions(toKeycode("WSTK"), WSTK.transferShares.selector);
        requests[1] = Permissions(toKeycode("WSAL"), WSAL.startSharesSale.selector);
        requests[2] = Permissions(toKeycode("WSAL"), WSAL.endSharesSale.selector);
        requests[3] = Permissions(toKeycode("WSAL"), WSAL.processSale.selector);
    }

    // User-facing functions
    function startSale(
        address song_,
        uint256 amount_,
        uint256 price_,
        uint256 maxShares_,
        address stableCoin_
    ) external {
        require(msg.sender == WSTK.ownerOf(song_, 0), "Not song owner");
        require(WSTK.balanceOf(msg.sender, WSTK.SONG_SHARES_ID()) >= amount_, "Insufficient shares");
        
        if(stableCoin_ != address(0)) {
            require(W20T.isTokenWhitelisted(stableCoin_), "Token not whitelisted");
        }

        WSAL.startSharesSale(song_, amount_, price_, maxShares_, stableCoin_);
    }

    function endSale(address song_) external {
        require(msg.sender == WSTK.ownerOf(song_, 0), "Not song owner");
        WSAL.endSharesSale(song_);
    }

    function buyShares(
        address song_,
        uint256 amount_
    ) external payable {
        // Get sale config
        (uint256 sharesForSale, uint256 pricePerShare, bool saleActive, uint256 maxSharesPerWallet, address stableCoin) = 
            WSAL.getSaleConfig(song_);

        require(saleActive, "Sale not active");
        require(amount_ <= sharesForSale, "Exceeds available shares");
        
        if(maxSharesPerWallet > 0) {
            require(
                WSTK.balanceOf(msg.sender, WSTK.SONG_SHARES_ID()) + amount_ <= maxSharesPerWallet,
                "Exceeds max shares per wallet"
            );
        }

        // Process payment and transfer shares
        WSAL.processSale{value: msg.value}(song_, msg.sender, amount_);
        WSTK.transferShares(song_, WSTK.ownerOf(song_, 0), msg.sender, amount_);
    }

    function withdrawSaleFunds(address song_) external {
        require(msg.sender == WSTK.ownerOf(song_, 0), "Not song owner");
        WSAL.withdrawSaleFunds(song_, msg.sender);
    }

    // View functions
    function getSaleInfo(address song_) external view returns (
        uint256 sharesForSale,
        uint256 pricePerShare,
        bool saleActive,
        uint256 maxSharesPerWallet,
        address stableCoin,
        uint256 availableFunds
    ) {
        (sharesForSale, pricePerShare, saleActive, maxSharesPerWallet, stableCoin) = WSAL.getSaleConfig(song_);
        availableFunds = WSAL.getSaleFunds(song_);
    }
} 