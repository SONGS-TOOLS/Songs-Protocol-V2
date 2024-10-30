// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Module, Keycode, toKeycode} from "../Kernel.sol";

/// @notice Song management module
contract SONG is Module {
    struct Song {
        address creator;
        address distributor;
        uint256 totalShares;
        bool isReleased;
        // Identifiers
        string isrc;
        string upc;
        string iswc;
        string iscc;
    }

    // Song storage
    mapping(address => Song) public songs;
    mapping(address => address) public pendingDistributorRequests;
    mapping(address => bool) public wrappedSongAuthenticity;
    
    // Review period tracking
    struct ReviewPeriod {
        uint256 startTime;
        uint256 endTime;
        address distributor;
    }
    mapping(address => ReviewPeriod) public reviewPeriods;
    uint256 public reviewPeriodDays = 7;

    // Events (maintaining original naming)
    event WrappedSongCreated(address indexed owner, address wrappedSongSmartAccount, uint256 totalShares);
    event WrappedSongReleaseRequested(address indexed wrappedSong, address indexed distributor, address indexed creator);
    event WrappedSongReleased(address indexed wrappedSong, address indexed distributor);
    event DistributorAcceptedReview(address indexed wrappedSong, address indexed distributor);
    event ReviewPeriodExpired(address indexed wrappedSong, address indexed distributor);
    event WrappedSongAuthenticitySet(address indexed wrappedSong, bool isAuthentic);
    event WrappedSongReleaseRejected(address indexed wrappedSong, address indexed distributor);

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("SONG");
    }

    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    // Original function names from ProtocolModule
    function requestWrappedSongRelease(
        address wrappedSong_,
        address distributor_
    ) external permissioned {
        require(!songs[wrappedSong_].isReleased, "SONG: already released");
        pendingDistributorRequests[wrappedSong_] = distributor_;
        emit WrappedSongReleaseRequested(wrappedSong_, distributor_, songs[wrappedSong_].creator);
    }

    function acceptWrappedSongForReview(address wrappedSong_) external permissioned {
        address distributor = pendingDistributorRequests[wrappedSong_];
        require(distributor != address(0), "SONG: no pending distributor");
        
        reviewPeriods[wrappedSong_] = ReviewPeriod({
            startTime: block.timestamp,
            endTime: block.timestamp + (reviewPeriodDays * 1 days),
            distributor: distributor
        });

        emit DistributorAcceptedReview(wrappedSong_, distributor);
    }

    function confirmWrappedSongRelease(address wrappedSong_) external permissioned {
        address distributor = pendingDistributorRequests[wrappedSong_];
        require(distributor != address(0), "SONG: no pending distributor");
        
        songs[wrappedSong_].distributor = distributor;
        songs[wrappedSong_].isReleased = true;
        delete pendingDistributorRequests[wrappedSong_];
        delete reviewPeriods[wrappedSong_];

        emit WrappedSongReleased(wrappedSong_, distributor);
    }

    function rejectWrappedSongRelease(address wrappedSong_) external permissioned {
        address distributor = pendingDistributorRequests[wrappedSong_];
        require(distributor != address(0), "SONG: no pending distributor");
        
        delete pendingDistributorRequests[wrappedSong_];
        delete reviewPeriods[wrappedSong_];

        emit WrappedSongReleaseRejected(wrappedSong_, distributor);
    }

    function handleExpiredReviewPeriod(address wrappedSong_) external permissioned {
        ReviewPeriod memory review = reviewPeriods[wrappedSong_];
        require(block.timestamp > review.endTime, "SONG: review period active");
        
        delete reviewPeriods[wrappedSong_];
        emit ReviewPeriodExpired(wrappedSong_, review.distributor);
    }

    // Identifier management (original function names)
    function addISRC(address wrappedSong_, string calldata isrc_) external permissioned {
        songs[wrappedSong_].isrc = isrc_;
    }

    function addUPC(address wrappedSong_, string calldata upc_) external permissioned {
        songs[wrappedSong_].upc = upc_;
    }

    function addISWC(address wrappedSong_, string calldata iswc_) external permissioned {
        songs[wrappedSong_].iswc = iswc_;
    }

    function addISCC(address wrappedSong_, string calldata iscc_) external permissioned {
        songs[wrappedSong_].iscc = iscc_;
    }

    function setWrappedSongAuthenticity(address wrappedSong_, bool isAuthentic_) external permissioned {
        wrappedSongAuthenticity[wrappedSong_] = isAuthentic_;
        emit WrappedSongAuthenticitySet(wrappedSong_, isAuthentic_);
    }

    // View functions (original names)
    function isReleased(address wrappedSong_) external view returns (bool) {
        return songs[wrappedSong_].isReleased;
    }

    function getWrappedSongDistributor(address wrappedSong_) external view returns (address) {
        return songs[wrappedSong_].distributor;
    }

    function getPendingDistributorRequests(address wrappedSong_) external view returns (address) {
        return pendingDistributorRequests[wrappedSong_];
    }

    function isAuthentic(address wrappedSong_) external view returns (bool) {
        return wrappedSongAuthenticity[wrappedSong_];
    }
}
