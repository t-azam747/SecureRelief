// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import "../src/DisasterReliefBondsV3.sol";
import "../src/MockUSDC.sol";

/**
 * @title DeployDisasterReliefBondsV3Simple
 * @dev Simple deployment script for production use
 */
contract DeployDisasterReliefBondsV3Simple is Script {
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

        vm.stopBroadcast();

        // Display deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("=============================");
        console.log("Network: Avalanche Fuji Testnet");
        console.log("MockUSDC:", address(usdc));
        console.log("DisasterReliefBondsV3:", address(reliefBonds));
        console.log("Admin/Oracle/Government:", msg.sender);

        console.log("\n=== AVAX FEATURES READY ===");
        console.log("- Native AVAX bond issuance: issueAVAXBond()");
        console.log("- AVAX donations: donateAVAX() or send directly");
        console.log("- AVAX emergency payouts: executeBulkAVAXPayout()");
        console.log("- AVAX yield generation: generateAVAXYield()");
        console.log("- Mixed AVAX/USDC support");

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Update frontend contract address");
        console.log("2. Test AVAX bond creation with real wallet");
        console.log("3. Verify contract on Snowtrace (optional)");
        console.log("4. Fund contract with initial AVAX for testing");

        console.log("\nDeployment complete! Ready to use AVAX tokens!");
    }
}
