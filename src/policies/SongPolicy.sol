// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Policy} from "../Kernel.sol";
import {toKeycode} from "../Kernel.sol";

import {WrappedSongToken} from "../modules/WrappedSongToken.sol";
import {WrappedSongMetadata} from "../modules/WrappedSongMetadata.sol";
import {SongRegistry} from "../modules/SongRegistry.sol";
import {DistributorRegistry} from "../modules/DistributorRegistry.sol";

/// @notice Policy for managing song lifecycle
contract SongPolicy is Policy {
    // Module keycodes
    WrappedSongToken public immutable WSTK;
    WrappedSongMetadata public immutable META;
    SongRegistry public immutable SONG;
    DistributorRegistry public immutable DIST;

    constructor(
        Kernel kernel_,
        WrappedSongToken wstk_,
        WrappedSongMetadata meta_,
        SongRegistry song_,
        DistributorRegistry dist_
    ) Policy(kernel_) {
        WSTK = wstk_;
        META = meta_;
        SONG = song_;
        DIST = dist_;
    }

    // Permissioned module functions
    function configureDependencies() external override returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](4);
        dependencies[0] = toKeycode("WSTK");
        dependencies[1] = toKeycode("META");
        dependencies[2] = toKeycode("SONG");
        dependencies[3] = toKeycode("DIST");
    }

    function requestPermissions() external view override returns (Permissions[] memory requests) {
        requests = new Permissions[](8);
        requests[0] = Permissions(toKeycode("WSTK"), WSTK.createSongTokens.selector);
        requests[1] = Permissions(toKeycode("META"), META.createMetadata.selector);
        requests[2] = Permissions(toKeycode("META"), META.requestUpdateMetadata.selector);
        requests[3] = Permissions(toKeycode("META"), META.confirmUpdateMetadata.selector);
        requests[4] = Permissions(toKeycode("SONG"), SONG.requestWrappedSongRelease.selector);
        requests[5] = Permissions(toKeycode("SONG"), SONG.confirmWrappedSongRelease.selector);
        requests[6] = Permissions(toKeycode("SONG"), SONG.rejectWrappedSongRelease.selector);
        requests[7] = Permissions(toKeycode("DIST"), DIST.createDistributorWallet.selector);
    }

    // User-facing functions
    function requestRelease(
        address song_,
        address distributor_
    ) external {
        require(msg.sender == WSTK.ownerOf(song_, 0), "Not song owner");
        require(DIST.checkIsDistributorWallet(distributor_), "Invalid distributor");
        
        SONG.requestWrappedSongRelease(song_, distributor_);
    }

    function confirmRelease(address song_) external {
        require(msg.sender == DIST.getDistributorWallets(msg.sender)[0], "Not distributor");
        require(SONG.getPendingDistributorRequests(song_) == msg.sender, "Not pending distributor");

        SONG.confirmWrappedSongRelease(song_);
    }

    function rejectRelease(address song_) external {
        require(msg.sender == DIST.getDistributorWallets(msg.sender)[0], "Not distributor");
        require(SONG.getPendingDistributorRequests(song_) == msg.sender, "Not pending distributor");

        SONG.rejectWrappedSongRelease(song_);
    }

    function requestMetadataUpdate(
        address song_,
        WrappedSongMetadata.Metadata calldata metadata_
    ) external {
        require(msg.sender == WSTK.ownerOf(song_, 0), "Not song owner");
        require(SONG.isReleased(song_), "Song not released");

        META.requestUpdateMetadata(song_, metadata_);
    }

    function confirmMetadataUpdate(address song_) external {
        require(msg.sender == DIST.getDistributorWallets(msg.sender)[0], "Not distributor");
        require(SONG.getWrappedSongDistributor(song_) == msg.sender, "Not song distributor");

        META.confirmUpdateMetadata(song_);
    }
} 