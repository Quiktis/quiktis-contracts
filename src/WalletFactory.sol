// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {UserWallet} from "./UserWallet.sol";

/**
 * @title WalletFactory (Upgradeable)
 * @dev Factory contract for creating user smart wallets. Any user can create their
 * own wallet, but the factory itself remains owned and upgradeable only by its owner.
 */
contract WalletFactory is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable 
{
    // Mapping from user address to their wallet address
    mapping(address => address) public userWallets;

    // Mapping to track if an address is a wallet created by this factory
    mapping(address => bool) public isWallet;

    // Array of all created wallets for enumeration (Note: Gas inefficient for large scale)
    address[] public allWallets;

    // Events
    event WalletCreated(address indexed user, address indexed wallet);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the factory (instead of constructor)
     * @param initialOwner The owner of the contract
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Required by UUPS — restricts who can upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Create a smart wallet for the caller (msg.sender).
     * The wallet is securely initialized during deployment.
     */
    function createWallet() public returns (address wallet) {
        address user = msg.sender;
        require(userWallets[user] == address(0), "WalletFactory: Wallet already exists for user");

        // Prepare the payload for Create2 deployment, including constructor and initializer arguments
        bytes memory creationCode = abi.encodePacked(
            type(UserWallet).creationCode,
            abi.encode(user, address(this)) // UserWallet constructor args
        );
        bytes memory initData = abi.encodeWithSelector(
            UserWallet.initialize.selector,
            user,
            address(this) // UserWallet initialize args
        );
        bytes memory walletCreationAndInit = abi.encodePacked(creationCode, initData);
        
        // Calculate the salt based on the user's address for deterministic addresses
        bytes32 salt = keccak256(abi.encodePacked(user));

        wallet = Create2.deploy(0, salt, walletCreationAndInit);

        userWallets[user] = wallet;
        isWallet[wallet] = true;
        allWallets.push(wallet);

        emit WalletCreated(user, wallet);
    }

    /**
     * @dev Get or create wallet for the caller (msg.sender)
     */
    function getOrCreateWallet() external nonReentrant returns (address wallet) {
        address user = msg.sender;
        if (userWallets[user] != address(0)) {
            return userWallets[user];
        }
        // FIX: call internal function directly to avoid reentrancy
        return createWallet();
    }

    // ... (rest of the WalletFactory functions remain unchanged)
    function getWallet(address user) external view returns (address wallet) {
        return userWallets[user];
    }

    function predictWalletAddress(address user) external view returns (address wallet) {
        bytes32 salt = keccak256(abi.encodePacked(user));
        bytes memory creationAndInitCode = abi.encodePacked(
            type(UserWallet).creationCode,
            abi.encode(user, address(this)),
            abi.encodeWithSelector(UserWallet.initialize.selector, user, address(this))
        );
        return Create2.computeAddress(salt, keccak256(creationAndInitCode));
    }

    function getTotalWallets() external view returns (uint256) {
        return allWallets.length;
    }

    function getWalletByIndex(uint256 index) external view returns (address wallet) {
        require(index < allWallets.length, "WalletFactory: Index out of bounds");
        return allWallets[index];
    }
    function getAllWalletsLength() external view returns (uint256) {
    return allWallets.length;
}
}
