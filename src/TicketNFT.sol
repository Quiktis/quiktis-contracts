// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TicketNFT
 * @dev ERC-721 NFT contract for event tickets with metadata
 * @notice Represents event tickets as NFTs with rich metadata including
 * event details, seat information, and QR codes for verification.
 */
contract TicketNFT is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard, Pausable {
    // Counter for token IDs to ensure uniqueness
    uint256 private _nextTokenId = 1;
    
    // Mapping to track authorized minters
    mapping(address => bool) public authorizedMinters;
    
    // Ticket metadata structure
    struct TicketMetadata {
        string eventName;
        string eventDate;
        string seatInfo;
        string ticketType;
        string qrCode;
        bool isUsed;
    }
    
    mapping(uint256 => TicketMetadata) public ticketMetadata;
    
    // Events
    event TicketMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event TicketUsed(uint256 indexed tokenId, address indexed user);
    event MinterAuthorized(address indexed minter, bool authorized);
    
    constructor(address initialOwner) 
        ERC721("Quiktis Event Tickets", "QTIX") 
        Ownable(initialOwner) 
    {
        authorizedMinters[initialOwner] = true;
    }
    
    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender], "TicketNFT: Not authorized to mint");
        _;
    }

    /**
     * @dev Mint a new ticket NFT
     * @param to Address receiving the NFT
     * @param _tokenURI Metadata URI
     * @param eventName (Optional) Event name
     * @param eventDate (Optional) Event date
     * @param seatInfo (Optional) Seat or section info
     * @param ticketType (Optional) Ticket type (VIP, Regular, etc.)
     * @param qrCode (Optional) Unique QR code for verification
     */
    function mint(
        address to,
        string memory _tokenURI,
        string memory eventName,
        string memory eventDate,
        string memory seatInfo,
        string memory ticketType,
        string memory qrCode
    ) external onlyAuthorizedMinter nonReentrant whenNotPaused returns (uint256) {
        require(to != address(0), "TicketNFT: Cannot mint to zero address");
        require(bytes(_tokenURI).length > 0, "TicketNFT: Token URI cannot be empty");

        uint256 tokenId = _nextTokenId++;
        
        // Mint the NFT
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        // Store metadata only if event details provided
        if (bytes(eventName).length > 0 || bytes(qrCode).length > 0) {
            ticketMetadata[tokenId] = TicketMetadata({
                eventName: eventName,
                eventDate: eventDate,
                seatInfo: seatInfo,
                ticketType: ticketType,
                qrCode: qrCode,
                isUsed: false
            });
        }

        emit TicketMinted(to, tokenId, _tokenURI);
        return tokenId;
    }
    
    function useTicket(uint256 tokenId) external {
        require(_ownerOf(tokenId) == msg.sender, "TicketNFT: Not ticket owner");
        require(!ticketMetadata[tokenId].isUsed, "TicketNFT: Already used");
        
        ticketMetadata[tokenId].isUsed = true;
        emit TicketUsed(tokenId, msg.sender);
    }
    
    function isTicketUsed(uint256 tokenId) external view returns (bool) {
        return ticketMetadata[tokenId].isUsed;
    }
    
    function getTicketMetadata(uint256 tokenId) external view returns (TicketMetadata memory) {
        require(_ownerOf(tokenId) != address(0), "TicketNFT: Token does not exist");
        return ticketMetadata[tokenId];
    }
    
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "TicketNFT: Cannot authorize zero address");
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }
    
    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (string memory) 
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
    
    function _update(address to, uint256 tokenId, address auth) 
        internal 
        override 
        whenNotPaused 
        returns (address) 
    {
        return super._update(to, tokenId, auth);
    }
}
