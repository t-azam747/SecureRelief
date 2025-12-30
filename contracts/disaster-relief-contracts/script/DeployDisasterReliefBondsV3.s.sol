// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import "../src/DisasterReliefBondsV3.sol";
import "../src/MockUSDC.sol";

/**
 * @title DeployDisasterReliefBondsV3
 * @dev Deployment script for the enhanced Disaster Relief Bonds system with AVAX support
 */
contract DeployDisasterReliefBondsV3 is Script {
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

        // Deploy DisasterReliefBondsV3 with AVAX support
        console.log("Deploying DisasterReliefBondsV3 with AVAX support...");
        DisasterReliefBondsV3 reliefBonds = new DisasterReliefBondsV3(address(usdc));
        console.log("DisasterReliefBondsV3 deployed at:", address(reliefBonds));

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

        // Test AVAX bond issuance (optional)
        console.log("\n=== TESTING AVAX FUNCTIONALITY ===");
        console.log("Deployer AVAX balance:", msg.sender.balance);

        if (msg.sender.balance >= 0.5 ether) {
            console.log("Creating test AVAX bond with 0.1 AVAX...");
            uint256 bondId = reliefBonds.issueAVAXBond{ value: 0.1 ether }(
                12, // 12 months maturity
                "Test Individual Donor"
            );
            console.log("Test AVAX bond created with ID:", bondId);

            // Check pool balances
            (uint256 avaxBalance, uint256 usdcBalance, uint256 avaxYield, uint256 usdcYield) =
                reliefBonds.getPoolBalances();
            console.log("Contract AVAX balance:", avaxBalance);
            console.log("Contract USDC balance:", usdcBalance);
            console.log("AVAX yield reserve:", avaxYield);
            console.log("USDC yield reserve:", usdcYield);
        } else {
            console.log("Insufficient AVAX for test bond creation");
            console.log("Get AVAX from faucet: https://faucet.avax.network/");
        }

        vm.stopBroadcast();

        // Display deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("=============================");
        console.log("Network: Avalanche Fuji Testnet");
        console.log("MockUSDC:", address(usdc));
        console.log("DisasterReliefBondsV3:", address(reliefBonds));
        console.log("\n=== NEW AVAX FEATURES ===");
        console.log("- Native AVAX bond issuance");
        console.log("- AVAX yield generation");
        console.log("- AVAX emergency payouts");
        console.log("- Direct AVAX donations");
        console.log("- Mixed AVAX/USDC portfolios");
        console.log("\n=== HOW TO USE YOUR AVAX ===");
        console.log("1. Call issueAVAXBond() with AVAX value");
        console.log("2. Send AVAX directly to contract for donations");
        console.log("3. Government can distribute AVAX in emergencies");
        console.log("4. Earn yield on your AVAX holdings");
        console.log("\nReady for revolutionary disaster relief with AVAX!");
    }
}
