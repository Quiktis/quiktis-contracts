// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {WalletFactory} from "../src/WalletFactory.sol";
import {UserWallet} from "../src/UserWallet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WalletFactoryTest is Test {
    WalletFactory public factory;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy logic contract
        WalletFactory logic = new WalletFactory();
        // Deploy proxy and initialize in constructor
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(logic),
            abi.encodeWithSelector(WalletFactory.initialize.selector, owner)
        );
        factory = WalletFactory(address(proxy));
    }

    function testInitialize() public {
        // Test that the factory is initialized with the correct owner
        assertEq(factory.owner(), owner);
        // Test that the factory cannot be re-initialized
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        factory.initialize(user1);
    }

    function testCreateWallet() public {
        // Test that a wallet is created for the caller
        vm.prank(user1);
        factory.createWallet();
        address walletAddress = factory.userWallets(user1);
        assertNotEq(walletAddress, address(0));
        assertTrue(factory.isWallet(walletAddress));
        assertEq(factory.allWallets(0), walletAddress);
        assertEq(factory.getTotalWallets(), 1);

        // Test that a second wallet cannot be created for the same user
        vm.prank(user1);
        vm.expectRevert("WalletFactory: Wallet already exists for user");
        factory.createWallet();
    }

    function testCreateWallet_DeterministicAddress() public {
        address predictedAddress = factory.predictWalletAddress(user1);

        vm.prank(user1);
        factory.createWallet();

        address createdAddress = factory.userWallets(user1);
        assertEq(createdAddress, predictedAddress);
    }

    function testGetOrCreateWallet() public {
        vm.prank(user1);
        address wallet1 = factory.getOrCreateWallet();
        assertNotEq(wallet1, address(0));
        assertEq(factory.userWallets(user1), wallet1);
        assertEq(factory.getTotalWallets(), 1);

        vm.prank(user1);
        address wallet2 = factory.getOrCreateWallet();
        assertEq(wallet2, wallet1);
        assertEq(factory.getTotalWallets(), 1);
    }

    function testGetWallet() public {
        vm.prank(user1);
        factory.createWallet();
        address walletAddress = factory.userWallets(user1);

        address retrievedWallet = factory.getWallet(user1);
        assertEq(retrievedWallet, walletAddress);
    }

    function testAuthorizeUpgrade() public {
        // Deploy a new WalletFactory logic contract for upgrade
        WalletFactory newLogic = new WalletFactory();

        vm.prank(owner);
        factory.upgradeToAndCall(address(newLogic), "");

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user1));
        factory.upgradeToAndCall(address(newLogic), "");
    }

    function testAllWallets() public {
        vm.prank(user1);
        factory.createWallet();
        vm.prank(user2);
        factory.createWallet();

        assertEq(factory.getAllWalletsLength(), 2);
        assertEq(factory.allWallets(0), factory.userWallets(user1));
        assertEq(factory.allWallets(1), factory.userWallets(user2));

        vm.expectRevert("WalletFactory: Index out of bounds");
        factory.getWalletByIndex(2);
    }
}