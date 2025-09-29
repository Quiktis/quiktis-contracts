// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title UserWallet (Upgradeable)
 * @dev Upgradeable smart wallet contract for individual users
 * @notice This contract acts as a smart wallet for users, allowing them to interact
 * with the Quiktis ecosystem through a dedicated wallet address
 */
contract UserWallet is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    // The user who owns this wallet
    address public user;
    
    // The factory contract that created this wallet
    address public factory;
    
    // Events
    event TransactionExecuted(address indexed target, uint256 value, bytes data, bool success);
    event EtherReceived(address indexed from, uint256 amount);

    /**
     * @dev Initializer function (replaces constructor)
     * @param _user The address of the user who owns this wallet
     * @param _factory The address of the factory contract
     */
    function initialize(address _user, address _factory) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_user);

        require(_user != address(0), "UserWallet: User cannot be zero address");
        require(_factory != address(0), "UserWallet: Factory cannot be zero address");

        user = _user;
        factory = _factory;
    }

    /**
     * @dev Modifier to restrict functions to user or factory only
     */
    modifier onlyUserOrFactory() {
        require(
            msg.sender == user || msg.sender == factory,
            "UserWallet: Not authorized"
        );
        _;
    }

    /**
     * @dev Execute a transaction from this wallet
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

    /**
     * @dev Execute multiple transactions in a batch
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external onlyUserOrFactory nonReentrant returns (bool[] memory successes, bytes[] memory returnDatas) {
        require(
            targets.length == values.length && values.length == datas.length,
            "UserWallet: Arrays length mismatch"
        );
        require(targets.length > 0, "UserWallet: Empty transaction array");
        
        successes = new bool[](targets.length);
        returnDatas = new bytes[](targets.length);
        
        for (uint256 i = 0; i < targets.length; i++) {
            require(targets[i] != address(0), "UserWallet: Cannot call zero address");
            
            (successes[i], returnDatas[i]) = targets[i].call{value: values[i]}(datas[i]);
            emit TransactionExecuted(targets[i], values[i], datas[i], successes[i]);
        }
        
        return (successes, returnDatas);
    }

    /**
     * @dev Get the balance of this wallet
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Allow the wallet to receive Ether
     */
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /**
     * @dev Emergency withdraw function (only owner)
     */
    function emergencyWithdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "UserWallet: Cannot withdraw to zero address");
        
        uint256 withdrawAmount = amount == 0 ? address(this).balance : amount;
        require(withdrawAmount <= address(this).balance, "UserWallet: Insufficient balance");
        
        (bool success, ) = to.call{value: withdrawAmount}("");
        require(success, "UserWallet: Withdrawal failed");
    }
}
