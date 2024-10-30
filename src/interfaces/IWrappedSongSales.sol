// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IWrappedSongSales {
    function startSharesSale(address song_, uint256 amount_, uint256 price_, uint256 maxShares_, address stableCoin_) external;
    function endSharesSale(address song_) external;
    function processSale(address song_, address buyer_, uint256 amount_) external payable;
    function withdrawSaleFunds(address song_, address to_) external;
    function getSaleConfig(address song_) external view returns (uint256, uint256, bool, uint256, address);
    function getSaleFunds(address song_) external view returns (uint256);
} 