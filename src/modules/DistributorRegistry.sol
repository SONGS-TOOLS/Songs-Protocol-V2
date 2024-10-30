// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Kernel, Module, Keycode, toKeycode} from "../Kernel.sol";

/// @notice Distributor management module
contract DistributorRegistry {
    // Distributor storage
    mapping(address => address[]) public distributorWallets;
    mapping(address => bool) public isDistributorWallet;
    mapping(address => address) public wrappedSongToDistributor;
    
    // Migration storage
    mapping(address => address) public oldToNewDistributor;

    // Events (maintaining original naming)
    event DistributorWalletCreated(address indexed distributor, address wallet);
    event WrappedSongReleased(address indexed wrappedSong, address indexed distributor);
    event FundsReceived(address indexed from, uint256 amount, string currency);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event DistributorMigrated(address indexed oldDistributor, address indexed newDistributor);

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("DIST");
    }

    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    // Original function names from DistributorWalletFactory
    function createDistributorWallet(
        address owner_,
        address wallet_
    ) external permissioned {
        distributorWallets[owner_].push(wallet_);
        isDistributorWallet[wallet_] = true;
        emit DistributorWalletCreated(owner_, wallet_);
    }

    // Migration functions
    function migrateDistributor(
        address oldDistributor_,
        address newDistributor_
    ) external permissioned {
        require(oldDistributor_ != address(0), "DIST: invalid old distributor");
        require(newDistributor_ != address(0), "DIST: invalid new distributor");
        require(oldToNewDistributor[oldDistributor_] == address(0), "DIST: already migrated");
        require(isDistributorWallet[newDistributor_], "DIST: not a valid distributor wallet");

        oldToNewDistributor[oldDistributor_] = newDistributor_;
        emit DistributorMigrated(oldDistributor_, newDistributor_);
    }

    function getMigratedDistributor(
        address oldDistributor_
    ) external view returns (address) {
        return oldToNewDistributor[oldDistributor_];
    }

    // View functions (original names)
    function getDistributorWallets(
        address ownerOfWallets_
    ) external view returns (address[] memory) {
        return distributorWallets[ownerOfWallets_];
    }

    function checkIsDistributorWallet(address wallet_) external view returns (bool) {
        return isDistributorWallet[wallet_];
    }

    function getWrappedSongDistributor(
        address wrappedSong_
    ) external view returns (address) {
        return wrappedSongToDistributor[wrappedSong_];
    }
}
