// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Module, Keycode, toKeycode} from "../Kernel.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// @notice Metadata management module 
contract META is Module {
    struct Metadata {
        string name;
        string description;
        string image;
        string externalUrl;
        string animationUrl;
        string attributesIpfsHash;
    }

    mapping(address => Metadata) public wrappedSongMetadata;
    mapping(address => Metadata) public pendingMetadataUpdates;
    mapping(address => bool) public metadataUpdateConfirmed;

    // Events from original MetadataModule
    event MetadataCreated(address indexed wrappedSong, Metadata newMetadata);
    event MetadataUpdateRequested(address indexed wrappedSong, Metadata newMetadata);
    event MetadataUpdated(address indexed wrappedSong, Metadata newMetadata);
    event MetadataUpdateRejected(address indexed wrappedSong);

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("META"); 
    }

    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    // Original function names from MetadataModule
    function createMetadata(
        address wrappedSong_,
        Metadata calldata metadata_
    ) external permissioned {
        require(
            bytes(wrappedSongMetadata[wrappedSong_].name).length == 0,
            'Metadata already exists'
        );
        wrappedSongMetadata[wrappedSong_] = metadata_;
        emit MetadataCreated(wrappedSong_, metadata_);
    }

    function requestUpdateMetadata(
        address wrappedSong_,
        Metadata calldata metadata_
    ) external permissioned {
        pendingMetadataUpdates[wrappedSong_] = metadata_;
        metadataUpdateConfirmed[wrappedSong_] = false;
        emit MetadataUpdateRequested(wrappedSong_, metadata_);
    }

    function updateMetadata(
        address wrappedSong_,
        Metadata calldata metadata_
    ) external permissioned {
        wrappedSongMetadata[wrappedSong_] = metadata_;
        emit MetadataUpdated(wrappedSong_, metadata_);
    }

    function confirmUpdateMetadata(address wrappedSong_) external permissioned {
        wrappedSongMetadata[wrappedSong_] = pendingMetadataUpdates[wrappedSong_];
        delete pendingMetadataUpdates[wrappedSong_];
        metadataUpdateConfirmed[wrappedSong_] = true;
        emit MetadataUpdated(wrappedSong_, wrappedSongMetadata[wrappedSong_]);
    }

    function rejectUpdateMetadata(address wrappedSong_) external permissioned {
        delete pendingMetadataUpdates[wrappedSong_];
        delete metadataUpdateConfirmed[wrappedSong_];
        emit MetadataUpdateRejected(wrappedSong_);
    }

    // View functions
    function getTokenURI(
        address wrappedSong_,
        uint256 tokenId_
    ) external view returns (string memory) {
        return _composeTokenURI(wrappedSongMetadata[wrappedSong_], tokenId_, wrappedSong_);
    }

    function getPendingMetadataUpdate(
        address wrappedSong_
    ) external view returns (Metadata memory) {
        return pendingMetadataUpdates[wrappedSong_];
    }

    function isMetadataUpdateConfirmed(address wrappedSong_) external view returns (bool) {
        return metadataUpdateConfirmed[wrappedSong_];
    }

    function _composeTokenURI(
        Metadata memory metadata,
        uint256 tokenId,
        address wrappedSongAddress
    ) internal pure returns (string memory) {
        string memory tokenType;
        string memory imageData;
        string memory description;

        if (tokenId == 0) {
            tokenType = unicode'◒';
            imageData = metadata.image;
            description = metadata.description;
        } else if (tokenId == 1) {
            tokenType = unicode'§';
            imageData = _generateSVGImage(metadata.image);
            description = string(
                abi.encodePacked(
                    'These are the SongShares representing your share on the royalty earnings of the Wrapped Song',
                    addressToString(wrappedSongAddress),
                    '.'
                )
            );
        } else {
            tokenType = 'Creator-defined NFT';
            imageData = metadata.image;
            description = metadata.description;
        }

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        tokenType,
                        ' - ',
                        metadata.name,
                        '",',
                        '"description": "',
                        description,
                        '",',
                        '"image": "',
                        imageData,
                        '",',
                        '"external_url": "',
                        metadata.externalUrl,
                        '",',
                        '"animation_url": "',
                        metadata.animationUrl,
                        '",',
                        '"attributes": ',
                        metadata.attributesIpfsHash,
                        '}'
                    )
                )
            )
        );

        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function _generateSVGImage(string memory imageUrl) internal pure returns (string memory) {
        string memory svgContent = _generateSVGContent(imageUrl);
        return string(
            abi.encodePacked(
                'data:image/svg+xml;base64,',
                Base64.encode(bytes(svgContent))
            )
        );
    }

    function _generateSVGContent(string memory imageUrl) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<svg width="562" height="562" viewBox="0 0 562 562" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                '<rect width="562" height="562" fill="#D9D9D9"/>',
                '<circle cx="281" cy="281" r="276.5" stroke="url(#paint0_linear)" stroke-width="9"/>',
                '<circle cx="281" cy="281" r="240" fill="url(#pattern0)"/>',
                '<defs>',
                '<pattern id="pattern0" patternContentUnits="objectBoundingBox" width="1" height="1">',
                '<use xlink:href="#image0" transform="scale(0.00095057)"/>',
                '</pattern>',
                '<linearGradient id="paint0_linear" x1="611.5" y1="-23" x2="-168" y2="174" gradientUnits="userSpaceOnUse">',
                '<stop offset="0.0461987" stop-color="#76ACF5"/>',
                '<stop offset="0.201565" stop-color="#B8BAD4"/>',
                '<stop offset="0.361787" stop-color="#FBBAB7"/>',
                '<stop offset="0.488023" stop-color="#FECD8A"/>',
                '<stop offset="0.64339" stop-color="#F9DF7D"/>',
                '<stop offset="0.793901" stop-color="#A9E6C8"/>',
                '<stop offset="0.992965" stop-color="#31D0E9"/>',
                '</linearGradient>',
                '<image id="image0" width="1052" height="1052" xlink:href="',
                imageUrl,
                '"/>',
                '</defs>',
                '</svg>'
            )
        );
    }

    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = '0123456789abcdef';
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
