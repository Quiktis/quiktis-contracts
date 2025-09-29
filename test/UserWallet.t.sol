// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {UserWallet} from "../src/UserWallet.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract UserWalletTest is Test {
    UserWallet public userWallet;
    address public user;
    address public factory;
    address public other;
    address public target;
    uint256 public initialBalance;

    function setUp() public {
        user = makeAddr("user");
        factory = makeAddr("factory");
        other = makeAddr("other");
        target = makeAddr("target");
        
        vm.prank(factory);
        userWallet = new UserWallet();
        userWallet.initialize(user, factory);
        
        initialBalance = 1 ether;
        vm.deal(address(userWallet), initialBalance);
    }

    function testInitialize() public {
        assertEq(userWallet.user(), user);
        assertEq(userWallet.factory(), factory);

        vm.prank(factory);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        userWallet.initialize(other, other);
    }

    function testInitializeRevertsWhenZeroAddress() public {
        vm.prank(factory);
        UserWallet newWallet = new UserWallet();

        vm.prank(factory);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        newWallet.initialize(address(0), factory);
        
        vm.prank(factory);
        vm.expectRevert("UserWallet: Factory cannot be zero address");
        newWallet.initialize(user, address(0));
    }
    
    function testExecute() public {
        bytes memory data = abi.encodeWithSignature("getBalance()");
        
        vm.prank(user);
        userWallet.execute(target, 0, data);

        vm.prank(factory);
        userWallet.execute(target, 0, data);

        vm.prank(other);
        vm.expectRevert("UserWallet: Not authorized");
        userWallet.execute(target, 0, data);
    }

    function testExecuteBatch() public {
        bytes memory data = abi.encodeWithSignature("getBalance()");
        address[] memory targets = new address[](2);
        targets[0] = target;
        targets[1] = target;
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        bytes[] memory datas = new bytes[](2);
        datas[0] = data;
        datas[1] = data;

        vm.prank(user);
        userWallet.executeBatch(targets, values, datas);

        vm.prank(other);
        vm.expectRevert("UserWallet: Not authorized");
        userWallet.executeBatch(targets, values, datas);
    }
    
    function testRevertExecuteBatchWithLengthMismatch() public {
        vm.prank(user);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](1);

        vm.expectRevert("UserWallet: Arrays length mismatch");
        userWallet.executeBatch(targets, values, datas);
    }
    
    function testReceiveAndFallback() public {
        uint256 value = 0.5 ether;
        
        vm.deal(other, value);
        vm.prank(other);
        (bool success,) = address(userWallet).call{value: value}("");
        assertTrue(success);
        assertEq(address(userWallet).balance, initialBalance + value);
        
        vm.deal(other, value);
        vm.prank(other);
        (success,) = address(userWallet).call{value: value}(abi.encodeWithSignature("nonExistentFunction()"));
        assertTrue(success);
        assertEq(address(userWallet).balance, initialBalance + value + value);
    }

    function testEmergencyWithdraw() public {
        address payable to = payable(other);
        uint256 amountToWithdraw = 0.5 ether;
        
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, other));
        userWallet.emergencyWithdraw(to, amountToWithdraw);
        
        vm.prank(user);
        userWallet.emergencyWithdraw(to, amountToWithdraw);
        assertEq(address(userWallet).balance, initialBalance - amountToWithdraw);
        assertEq(to.balance, amountToWithdraw);
        
        uint256 remainingBalance = address(userWallet).balance;
        vm.prank(user);
        userWallet.emergencyWithdraw(to, 0);
        assertEq(address(userWallet).balance, 0);
        assertEq(to.balance, amountToWithdraw + remainingBalance);
    }

    function testFuzzEmergencyWithdraw(uint256 fuzzedAmount) public {
        address payable to = payable(other);
        vm.assume(fuzzedAmount <= address(userWallet).balance && fuzzedAmount != 0);

        uint256 initialBalanceTo = to.balance;
        uint256 initialBalanceWallet = address(userWallet).balance;

        vm.prank(user);
        userWallet.emergencyWithdraw(to, fuzzedAmount);

        assertEq(address(userWallet).balance, initialBalanceWallet - fuzzedAmount);
        assertEq(to.balance, initialBalanceTo + fuzzedAmount);
    }
}