// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title UserWallet (Upgradeable)
 * @dev Upgradeable smart wallet contract for individual users
 * @notice Acts as a smart wallet for Quiktis users, supporting crypto (ETH), CNGN & USDC.
 */
contract UserWallet is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    // The user who owns this wallet
    address public user;
    
    // The factory contract that created this wallet
    address public factory;

    // Supported tokens (Base testnet)
    address public constant CNGN = 0x7E29CF1D8b1F4c847D0f821b79dDF6E67A5c11F8;
    address public constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    // Events
    event TransactionExecuted(address indexed target, uint256 value, bytes data, bool success);
    event TokenPayment(address indexed payer, address indexed token, address indexed recipient, uint256 amount);
    event EtherReceived(address indexed from, uint256 amount);

    /**
     * @dev Initializer function (replaces constructor)
     */
    function initialize(address _user, address _factory) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_user);

        require(_user != address(0), "UserWallet: User cannot be zero address");
        require(_factory != address(0), "UserWallet: Factory cannot be zero address");

        user = _user;
        factory = _factory;
    }

    modifier onlyUserOrFactory() {
        require(msg.sender == user || msg.sender == factory, "UserWallet: Not authorized");
        _;
    }

    /**
     * @dev Pay using an approved ERC20 token (CNGN or USDC)
     */
    function payWithToken(address token, address recipient, uint256 amount)
        external
        onlyUserOrFactory
        nonReentrant
    {
        require(token == CNGN || token == USDC, "UserWallet: Unsupported token");
        require(recipient != address(0), "UserWallet: Invalid recipient");
        require(amount > 0, "UserWallet: Amount must be > 0");

        bool success = IERC20(token).transferFrom(msg.sender, recipient, amount);
        require(success, "UserWallet: Token transfer failed");

        emit TokenPayment(msg.sender, token, recipient, amount);
    }

    /**
     * @dev Execute a transaction from this wallet (e.g. for internal logic)
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyUserOrFactory nonReentrant returns (bool success, bytes memory returnData) {
        require(target != address(0), "UserWallet: Cannot call zero address");
        
        (success, returnData) = target.call{value: value}(data);
        emit TransactionExecuted(target, value, data, success);
        
        return (success, returnData);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    function emergencyWithdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "UserWallet: Cannot withdraw to zero address");
        
        uint256 withdrawAmount = amount == 0 ? address(this).balance : amount;
        require(withdrawAmount <= address(this).balance, "UserWallet: Insufficient balance");
        
        (bool success, ) = to.call{value: withdrawAmount}("");
        require(success, "UserWallet: Withdrawal failed");
    }
}
