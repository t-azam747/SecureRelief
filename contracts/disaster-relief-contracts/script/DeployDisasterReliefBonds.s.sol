// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import "../src/DisasterReliefBondsV2.sol";
import "../src/MockUSDC.sol";

/**
 * @title DeployDisasterReliefBonds
 * @dev Deployment script for the revolutionary Disaster Relief Bonds system
 */
contract DeployDisasterReliefBonds is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDC first (or use existing)
        address existingUSDC = vm.envOr("EXISTING_USDC_ADDRESS", address(0));
        MockUSDC usdc;

        if (existingUSDC == address(0)) {
            console.log("Deploying new MockUSDC...");
            usdc = new MockUSDC();
            console.log("MockUSDC deployed at:", address(usdc));
        } else {
            console.log("Using existing MockUSDC at:", existingUSDC);
            usdc = MockUSDC(existingUSDC);
        }

        // Deploy DisasterReliefBondsV2
        console.log("Deploying DisasterReliefBondsV2...");
        DisasterReliefBondsV2 reliefBonds = new DisasterReliefBondsV2(address(usdc));
        console.log("DisasterReliefBondsV2 deployed at:", address(reliefBonds));

        // Setup initial configuration
        console.log("Setting up initial configuration...");

        // Add deployer as oracle and government for testing
        reliefBonds.addOracle(msg.sender);
        reliefBonds.addGovernment(msg.sender);
        reliefBonds.addTreasuryManager(msg.sender);

        console.log("Setup complete!");
        console.log("Admin:", msg.sender);
        console.log("Oracle added:", msg.sender);
        console.log("Government added:", msg.sender);
        console.log("Treasury manager added:", msg.sender);

        vm.stopBroadcast();

        // Display deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("=====================");
        console.log("Network: Avalanche Fuji Testnet");
        console.log("MockUSDC:", address(usdc));
        console.log("DisasterReliefBondsV2:", address(reliefBonds));
        console.log("\nReady for revolutionary disaster relief!");
    }
}
