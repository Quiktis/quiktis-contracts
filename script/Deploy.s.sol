// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {TicketNFT} from "../src/TicketNFT.sol";
import {WalletFactory} from "../src/WalletFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


/**
 * @title Deploy
 * @dev Deployment script for Quiktis contracts using Foundry (UUPS upgradeable for WalletFactory)
 */
contract Deploy is Script {
    address public ticketNFT;
    address public walletFactory;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TicketNFT
        console.log("Deploying TicketNFT...");
        TicketNFT ticketContract = new TicketNFT(deployer);
        ticketNFT = address(ticketContract);
        console.log("TicketNFT deployed at:", ticketNFT);

        // 2. Deploy WalletFactory implementation (logic contract)
        console.log("Deploying WalletFactory Implementation...");
        WalletFactory factoryImpl = new WalletFactory();

        // 3. Encode initializer call
        bytes memory initData = abi.encodeWithSelector(
            WalletFactory.initialize.selector,
            deployer // pass owner or any init args
        );

        // 4. Deploy Proxy pointing to WalletFactory implementation
        console.log("Deploying WalletFactory Proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImpl), initData);
        walletFactory = address(proxy);
        console.log("WalletFactory Proxy deployed at:", walletFactory);

        // 5. Authorize the WalletFactory proxy to mint tickets
        console.log("Authorizing WalletFactory as minter...");
        ticketContract.setAuthorizedMinter(walletFactory, true);
        console.log("WalletFactory authorized to mint tickets");

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("TicketNFT:", ticketNFT);
        console.log("WalletFactory (Proxy):", walletFactory);
        console.log("Owner:", deployer);
        console.log("========================\n");

        saveDeploymentAddresses();
    }

    function saveDeploymentAddresses() internal {
        string memory json = string.concat(
            '{\n',
            '  "ticketNFT": "', vm.toString(ticketNFT), '",\n',
            '  "walletFactory": "', vm.toString(walletFactory), '",\n',
            '  "deployer": "', vm.toString(vm.addr(vm.envUint("PRIVATE_KEY"))), '",\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "deployedAt": ', vm.toString(block.timestamp), '\n',
            '}'
        );

        vm.writeFile("deployment-addresses.json", json);
        console.log("Deployment addresses saved to deployment-addresses.json");
    }
}
