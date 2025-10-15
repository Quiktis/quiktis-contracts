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
 * @dev Factory contract for creating Quiktis user smart wallets.
 */
contract WalletFactory is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable 
{
    mapping(address => address) public userWallets;
    mapping(address => bool) public isWallet;
    address[] public allWallets;

    event WalletCreated(address indexed user, address indexed wallet);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Creates a deterministic wallet for the caller.
     */
    function createWallet() public nonReentrant returns (address wallet) {
        address user = msg.sender;
        require(userWallets[user] == address(0), "WalletFactory: Wallet already exists");

        bytes memory creationCode = type(UserWallet).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(user));

        // Deploy using CREATE2
        wallet = Create2.deploy(0, salt, creationCode);

        // Initialize the wallet after deployment
        UserWallet(wallet).initialize(user, address(this));

        userWallets[user] = wallet;
        isWallet[wallet] = true;
        allWallets.push(wallet);

        emit WalletCreated(user, wallet);
    }

    function getOrCreateWallet() external nonReentrant returns (address wallet) {
        if (userWallets[msg.sender] != address(0)) return userWallets[msg.sender];
        return createWallet();
    }

    function getWallet(address user) external view returns (address wallet) {
        return userWallets[user];
    }

    function predictWalletAddress(address user) external view returns (address wallet) {
        bytes memory creationCode = type(UserWallet).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(user));
        wallet = Create2.computeAddress(salt, keccak256(creationCode));
    }

    function getTotalWallets() external view returns (uint256) {
        return allWallets.length;
    }

    function getWalletByIndex(uint256 index) external view returns (address wallet) {
        require(index < allWallets.length, "WalletFactory: Index out of bounds");
        return allWallets[index];
    }
}
