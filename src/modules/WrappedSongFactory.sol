// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Kernel, Module, Keycode, toKeycode } from "../Kernel.sol";
import { WrappedSongSmartAccount } from "../external/WrappedSongSmartAccount.sol";
import { WSTokensManagement } from "../external/WSTokensManagement.sol";
import { DIST } from "./DIST.sol";
import { IMetadataModule } from "./IMetadataModule.sol";

/// @notice Factory for creating wrapped song instances
contract WrappedSongFactory is Module {
    // Module dependencies
    address public immutable EARN;
    address public immutable WSAL;
    address public immutable META;
    address public immutable W20T;

    // Factory storage
    mapping(address => address[]) public ownerWrappedSongs;
    uint256 public wrappedSongCreationFee;

    // Events
    event WrappedSongCreated(
        address indexed owner,
        address wrappedSongSmartAccount,
        address stablecoin,
        address wsTokenManagement
    );

    event WrappedSongCreatedWithMetadata(
        address indexed owner,
        address wrappedSongSmartAccount,
        bytes songMetadata,
        uint256 sharesAmount
    );

    constructor(
        Kernel kernel_,
        address earn_,
        address wsal_,
        address meta_,
        address w20t_
    ) Module(kernel_) {
        EARN = earn_;
        WSAL = wsal_;
        META = meta_;
        W20T = w20t_;
    }

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("WSFC");
    }

    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    function createWrappedSongWithMetadata(
        address owner_,
        address stablecoin_,
        bytes calldata metadata_,
        uint256 sharesAmount_
    ) external payable permissioned returns (address) {
        require(msg.value >= wrappedSongCreationFee, "WSFC: insufficient fee");

        // Create song instance first
        WrappedSongSmartAccount songInstance = new WrappedSongSmartAccount(
            stablecoin_,
            owner_,
            EARN,
            WSAL,
            META,
            sharesAmount_
        );

        address songAddress = address(songInstance);
        ownerWrappedSongs[owner_].push(songAddress);

        emit WrappedSongCreated(owner_, songAddress, stablecoin_, songInstance.tokenManagement());
        emit WrappedSongCreatedWithMetadata(owner_, songAddress, metadata_, sharesAmount_);

        return songAddress;
    }

    function migrateWrappedSong(address oldWrappedSong_) external payable permissioned returns (address) {
        require(
            WrappedSongSmartAccount(oldWrappedSong_).owner() == msg.sender,
            "WSFC: invalid owner"
        );

        // If the song is released, verify distributor migration
        if (oldProtocolModule.isReleased(oldWrappedSong_)) {
            address oldDistributor = oldProtocolModule.getWrappedSongDistributor(oldWrappedSong_);
            require(oldDistributor != address(0), "WSFC: no distributor set for this wrapped song");

            // Get migrated distributor from DIST module
            DIST dist = DIST(kernel.getModuleAddress(toKeycode("DIST")));
            address newDistributor = dist.getMigratedDistributor(oldDistributor);
            require(newDistributor != address(0), "WSFC: distributor not migrated to new protocol");

            // TODO: Set in NEW release module 
            // the old RELEASED status 
            // with new MIGRATED distributor m
        }

        // Get information from old wrapped song
        WrappedSongSmartAccount oldSong = WrappedSongSmartAccount(oldWrappedSong_);
        address stablecoin = oldSong.stablecoin();
        WSTokensManagement tokenManagement = WSTokensManagement(oldSong.tokenManagement());

        // Create new song instance with existing token management
        WrappedSongSmartAccount songInstance = new MigratedWrappedSongSmartAccount(
            stablecoin,
            msg.sender,
            EARN,
            WSAL,
            META
        );

        address songAddress = address(songInstance);
        ownerWrappedSongs[msg.sender].push(songAddress);

        // Get and migrate metadata
        IMetadataModule.Metadata memory currentMetadata = oldMetadataModule.getTokenMetadata(oldWrappedSong_);
        metadataModule.createMetadata(songAddress, currentMetadata);

        // Migrate old WSTokenManagement to new metadata & new WrappedSongSmartAccount
        oldSong.migrateWrappedSong(META, songAddress);

        emit WrappedSongCreated(msg.sender, songAddress, stablecoin, address(tokenManagement));

        return songAddress;
    }

    function setWrappedSongCreationFee(uint256 fee_) external permissioned {
        wrappedSongCreationFee = fee_;
    }

    // View functions
    function getOwnerWrappedSongs(address owner_) external view returns (address[] memory) {
        return ownerWrappedSongs[owner_];
    }

    function getWrappedSongCreationFee() external view returns (uint256) {
        return wrappedSongCreationFee;
    }
}
