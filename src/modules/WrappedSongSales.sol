// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Module, Keycode, toKeycode} from "../Kernel.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WSTokensManagement} from "../external/WSTokensManagement.sol";

/// @notice WrappedSong Sales management module
contract WrappedSongSales is Module {
    using SafeERC20 for IERC20;

    // Token sale state
    struct SaleConfig {
        uint256 tokenId;           // SONG_SHARES_ID or SONG_SELL_ID
        uint256 tokensForSale;
        uint256 pricePerToken;
        bool saleActive;
        uint256 maxTokensPerWallet;
        IERC20 stableCoin;
    }

    // Storage
    mapping(address => mapping(uint256 => SaleConfig)) public songSales; // song => tokenId => SaleConfig
    mapping(address => mapping(uint256 => uint256)) public saleFunds; // song => tokenId => funds

    // Events (maintaining original naming)
    event SharesSaleStarted(
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        address indexed owner,
        uint256 maxTokensPerWallet,
        address stableCoinAddress
    );
    event SharesSold(address buyer, uint256 tokenId, uint256 amount);
    event SharesSaleEnded(address song, uint256 tokenId);
    event SaleFundsReceived(uint256 tokenId, uint256 amount);
    event SaleFundsWithdrawn(address indexed to, uint256 tokenId, uint256 amount);

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("WSAL");
    }

    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    function startTokenSale(
        address song_,
        uint256 tokenId_,
        uint256 amount_,
        uint256 price_,
        uint256 maxTokens_,
        address stableCoin_
    ) external permissioned {
        require(tokenId_ == WSTokensManagement(song_).SONG_SHARES_ID() || 
                tokenId_ == WSTokensManagement(song_).SONG_SELL_ID(), 
                "WSAL: invalid token type");
        require(amount_ > 0 && price_ > 0, "WSAL: invalid sale params");
        
        songSales[song_][tokenId_] = SaleConfig({
            tokenId: tokenId_,
            tokensForSale: amount_,
            pricePerToken: price_,
            saleActive: true,
            maxTokensPerWallet: maxTokens_,
            stableCoin: IERC20(stableCoin_)
        });

        emit SharesSaleStarted(tokenId_, amount_, price_, msg.sender, maxTokens_, stableCoin_);
    }

    function endTokenSale(address song_, uint256 tokenId_) external permissioned {
        require(songSales[song_][tokenId_].saleActive, "WSAL: no active sale");
        songSales[song_][tokenId_].saleActive = false;
        songSales[song_][tokenId_].tokensForSale = 0;
        emit SharesSaleEnded(song_, tokenId_);
    }

    function processSale(
        address song_,
        uint256 tokenId_,
        address buyer_,
        uint256 amount_
    ) external payable permissioned {
        SaleConfig storage sale = songSales[song_][tokenId_];
        require(sale.saleActive, "WSAL: no active sale");
        require(amount_ > 0, "WSAL: invalid amount");
        require(amount_ <= sale.tokensForSale, "WSAL: not enough tokens");

        uint256 totalCost = amount_ * sale.pricePerToken;

        if (address(sale.stableCoin) != address(0)) {
            sale.stableCoin.safeTransferFrom(buyer_, address(this), totalCost);
        } else {
            require(msg.value == totalCost, "WSAL: incorrect ETH amount");
        }

        sale.tokensForSale -= amount_;
        saleFunds[song_][tokenId_] += totalCost;

        if (sale.tokensForSale == 0) {
            sale.saleActive = false;
            emit SharesSaleEnded(song_, tokenId_);
        }

        emit SharesSold(buyer_, tokenId_, amount_);
        emit SaleFundsReceived(tokenId_, totalCost);
    }

    function withdrawSaleFunds(
        address song_,
        uint256 tokenId_,
        address to_
    ) external permissioned {
        uint256 funds = saleFunds[song_][tokenId_];
        require(funds > 0, "WSAL: no funds to withdraw");

        SaleConfig storage sale = songSales[song_][tokenId_];
        saleFunds[song_][tokenId_] = 0;

        if (address(sale.stableCoin) != address(0)) {
            sale.stableCoin.safeTransfer(to_, funds);
        } else {
            (bool success, ) = to_.call{value: funds}("");
            require(success, "WSAL: ETH transfer failed");
        }

        emit SaleFundsWithdrawn(to_, tokenId_, funds);
    }

    // View functions
    function getSaleConfig(address song_, uint256 tokenId_) external view returns (SaleConfig memory) {
        return songSales[song_][tokenId_];
    }

    function getSaleFunds(address song_, uint256 tokenId_) external view returns (uint256) {
        return saleFunds[song_][tokenId_];
    }

    // To receive ETH payments
    receive() external payable {}
}
