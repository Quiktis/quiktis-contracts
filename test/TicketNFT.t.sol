// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {TicketNFT} from "../src/TicketNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TicketNFTTest is Test {
    TicketNFT public ticketNFT;
    address public owner;
    address public walletFactory;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        walletFactory = makeAddr("walletFactory");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        ticketNFT = new TicketNFT(owner);
        
        vm.prank(owner);
        ticketNFT.setAuthorizedMinter(walletFactory, true);
    }

    function testMinterAuthorization() public {
        // Only owner can set authorized minter
        vm.prank(owner);
        ticketNFT.setAuthorizedMinter(user1, true);
        assertTrue(ticketNFT.authorizedMinters(user1));

        // Non-owner cannot set minter
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        ticketNFT.setAuthorizedMinter(user2, true);
    }

    function testMintTicket() public {
        // Only authorized minter can mint
        vm.prank(walletFactory);
        uint256 tokenId = ticketNFT.mint(user1, "ipfs://testuri", "Event A", "", "", "Regular", "qr_code_1");

        assertEq(ticketNFT.ownerOf(tokenId), user1);
        assertEq(ticketNFT.tokenURI(tokenId), "ipfs://testuri");

        (string memory eventName, , , , string memory qrCode, ) = ticketNFT.ticketMetadata(tokenId);
        assertEq(eventName, "Event A");
        assertEq(qrCode, "qr_code_1");

        // Unauthorized address cannot mint
        vm.prank(user2);
        vm.expectRevert("TicketNFT: Not authorized to mint");
        ticketNFT.mint(user2, "ipfs://fail", "", "", "", "", "");
    }

    function testUseTicket() public {
        vm.prank(walletFactory);
        uint256 tokenId = ticketNFT.mint(user1, "ipfs://testuri", "", "", "", "", "");

        vm.prank(user1);
        ticketNFT.useTicket(tokenId);
        assertTrue(ticketNFT.isTicketUsed(tokenId));

        vm.prank(user1);
        vm.expectRevert("TicketNFT: Already used");
        ticketNFT.useTicket(tokenId);

        vm.prank(user2);
        vm.expectRevert("TicketNFT: Not ticket owner");
        ticketNFT.useTicket(tokenId);
    }

    function testFuzzMintWithDifferentInputs(address to, string calldata uri, string calldata eventName) public {
        if (to == address(0) || bytes(uri).length == 0) {
            return;
        }
        vm.assume(bytes(eventName).length > 0);

        vm.prank(walletFactory);
        ticketNFT.mint(to, uri, eventName, "", "", "", "");
        uint256 tokenId = ticketNFT.totalSupply();
        
        assertEq(ticketNFT.ownerOf(tokenId), to);
        assertEq(ticketNFT.tokenURI(tokenId), uri);
    }
}
