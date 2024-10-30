// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IWrappedSongMetadata {
    struct Metadata {
        string name;
        string description;
        string image;
        string externalUrl;
        string animationUrl;
        string attributesIpfsHash;
    }

    function createMetadata(address song_, Metadata calldata metadata_) external;
    function requestUpdateMetadata(address song_, Metadata calldata metadata_) external;
    function updateMetadata(address song_, Metadata calldata metadata_) external;
    function confirmUpdateMetadata(address song_) external;
    function rejectUpdateMetadata(address song_) external;
    function getTokenURI(address song_, uint256 tokenId_) external view returns (string memory);
} 