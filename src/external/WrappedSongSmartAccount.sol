// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IWrappedSongToken} from "../interfaces/IWrappedSongToken.sol";
import {IWrappedSongEarnings} from "../interfaces/IWrappedSongEarnings.sol";
import {IWrappedSongSales} from "../interfaces/IWrappedSongSales.sol";
import {WSTokensManagement} from "./WSTokensManagement.sol";

/// @notice Individual wrapped song instance that interacts with protocol modules
contract WrappedSongSmartAccount is Ownable, IERC1155Receiver, ERC165, ReentrancyGuard {
    // Module interfaces
    IWrappedSongToken public immutable WSTK;
    IWrappedSongEarnings public immutable EARN;
    IWrappedSongSales public immutable WSAL;

    // Instance state
    address public immutable stablecoin;
    bool public initialized;

    // WSTokensManagement instance
    WSTokensManagement public tokenManagement;

    constructor(
        address stablecoin_,
        address owner_,
        address wstk_,
        address earn_,
        address wsal_,
        uint256 sharesAmount_
    ) Ownable(owner_) {
        stablecoin = stablecoin_;
        WSTK = IWrappedSongToken(wstk_);
        EARN = IWrappedSongEarnings(earn_);
        WSAL = IWrappedSongSales(wsal_);

        // Create token management instance with this contract as owner
        tokenManagement = new WSTokensManagement(
            address(this), // WrappedSongSmartAccount owns the SONG_CONCEPT_ID
            owner_,        // Creator owns the SONG_SHARES_ID
            stablecoin_,
            sharesAmount_
        );
    }

    // Earnings functions
    function receiveEarnings() external payable {
        EARN.receiveEarnings{value: msg.value}(address(this), address(0), msg.value);
    }

    function receiveERC20Earnings(address token_, uint256 amount_) external {
        EARN.receiveEarnings(address(this), token_, amount_);
    }

    function claimEarnings(address token_) external {
        EARN.claimEarnings(address(this), msg.sender, token_);
    }

    // Sales functions
    function startSale(
        uint256 amount_,
        uint256 price_,
        uint256 maxShares_,
        address stableCoin_
    ) external onlyOwner {
        WSAL.startSharesSale(address(this), amount_, price_, maxShares_, stableCoin_);
    }

    function endSale() external onlyOwner {
        WSAL.endSharesSale(address(this));
    }

    function withdrawSaleFunds() external onlyOwner {
        WSAL.withdrawSaleFunds(address(this), msg.sender);
    }

    // ERC1155 receiver functions
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // To receive ETH
    receive() external payable {
        if(msg.value > 0) {
            EARN.receiveEarnings{value: msg.value}(address(this), address(0), msg.value);
        }
    }
} 