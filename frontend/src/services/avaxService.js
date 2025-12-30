/**
 * AVAX Integration Utility for Disaster Relief Platform
 * Handles native AVAX token operations with the smart contract
 */

import { ethers } from 'ethers';

// Contract ABI for AVAX-specific functions
const AVAX_FUNCTIONS_ABI = [
    // AVAX Bond Creation
    "function issueAVAXBond(uint256 maturityMonths, string memory donorType) external payable returns (uint256 bondId)",
    
    // Direct AVAX Donation
    "function donateAVAX() external payable",
    
    // AVAX Yield Generation
    "function generateAVAXYield() external",
    
    // AVAX Emergency Payouts
    "function executeBulkAVAXPayout(bytes32 eventId, address[] memory beneficiaries, uint256[] memory amounts, uint8[] memory methods) external",
    
    // AVAX Pool Information
    "function getPoolBalances() external view returns (uint256 avaxBalance, uint256 usdcBalance, uint256 avaxYield, uint256 usdcYield)",
    
    // Enhanced Impact Metrics
    "function getImpactMetrics() external view returns (uint256 totalBonds, uint256 totalAVAXValue, uint256 totalUSDCValue, uint256 totalAVAXYield, uint256 totalUSDCYield, uint256 totalAVAXRelief, uint256 totalUSDCRelief, uint256 disastersHelped, uint256 avgResponseTimeSec, uint256 currentAPYBasisPoints, uint256 activeBondCount)",
    
    // Bond Information with Token Types
    "function getDonorBonds(address donor) external view returns (uint256[] memory bondIds, uint256[] memory principalAmounts, uint256[] memory currentValues, uint256[] memory yieldEarned, uint256[] memory maturityTimes, bool[] memory activeStatus, uint8[] memory tokenTypes)",
    
    // Redeem Bonds (works for both AVAX and USDC)
    "function redeemBond(uint256 bondId) external",
    
    // Emergency Withdraw (works for both AVAX and USDC)
    "function emergencyWithdraw(uint256 bondId) external"
];

// Token Types
export const TOKEN_TYPES = {
    AVAX: 0,
    USDC: 1
};

// Payment Methods
export const PAYMENT_METHODS = {
    CRYPTO: 0,
    BANK_TRANSFER: 1,
    MOBILE_MONEY: 2,
    CUSTODIAL: 3
};

class AVAXDisasterReliefService {
    constructor(contractAddress, provider) {
        this.contractAddress = contractAddress;
        this.provider = provider;
        this.contract = null;
    }

    // Initialize contract with signer
    async init(signer) {
        this.contract = new ethers.Contract(
            this.contractAddress,
            AVAX_FUNCTIONS_ABI,
            signer
        );
    }

    // =========================================================================
    // AVAX BOND OPERATIONS
    // =========================================================================

    /**
     * Create an AVAX bond using native tokens from wallet
     * @param {number} avaxAmount - Amount of AVAX to bond
     * @param {number} maturityMonths - Bond maturity (6-60 months)
     * @param {string} donorType - Type of donor (Individual, Corporate, ESG)
     * @returns {Promise<Object>} Transaction result with bond ID
     */
    async createAVAXBond(avaxAmount, maturityMonths, donorType = "Individual") {
        try {
            if (!this.contract) throw new Error("Contract not initialized");
            
            const avaxValue = ethers.utils.parseEther(avaxAmount.toString());
            
            // Validate inputs
            if (avaxAmount < 0.1) {
                throw new Error("Minimum AVAX bond amount is 0.1 AVAX");
            }
            
            if (maturityMonths < 6 || maturityMonths > 60) {
                throw new Error("Maturity must be between 6-60 months");
            }

            const tx = await this.contract.issueAVAXBond(maturityMonths, donorType, {
                value: avaxValue
            });

            const receipt = await tx.wait();
            
            // Extract bond ID from events
            const bondCreatedEvent = receipt.events?.find(
                event => event.event === 'AVAXBondIssued'
            );
            
            const bondId = bondCreatedEvent?.args?.bondId;

            return {
                success: true,
                bondId: bondId?.toString(),
                transactionHash: receipt.transactionHash,
                avaxAmount,
                maturityMonths,
                donorType
            };

        } catch (error) {
            console.error("AVAX bond creation failed:", error);
            throw new Error(`Failed to create AVAX bond: ${error.message}`);
        }
    }

    /**
     * Make a direct AVAX donation (no bond, immediate availability)
     * @param {number} avaxAmount - Amount of AVAX to donate
     * @returns {Promise<Object>} Transaction result
     */
    async donateAVAX(avaxAmount) {
        try {
            if (!this.contract) throw new Error("Contract not initialized");
            
            const avaxValue = ethers.utils.parseEther(avaxAmount.toString());
            
            if (avaxAmount <= 0) {
                throw new Error("Donation amount must be greater than 0");
            }

            const tx = await this.contract.donateAVAX({
                value: avaxValue
            });

            const receipt = await tx.wait();

            return {
                success: true,
                transactionHash: receipt.transactionHash,
                avaxAmount,
                type: 'donation'
            };

        } catch (error) {
            console.error("AVAX donation failed:", error);
            throw new Error(`Failed to donate AVAX: ${error.message}`);
        }
    }

    // =========================================================================
    // BOND MANAGEMENT
    // =========================================================================

    /**
     * Get all bonds for a specific donor with token type information
     * @param {string} donorAddress - Address of the bond holder
     * @returns {Promise<Array>} Array of bond objects with token types
     */
    async getDonorBonds(donorAddress) {
        try {
            if (!this.contract) throw new Error("Contract not initialized");

            const result = await this.contract.getDonorBonds(donorAddress);
            
            const bonds = [];
            for (let i = 0; i < result.bondIds.length; i++) {
                const tokenType = result.tokenTypes[i];
                const isAVAX = tokenType === TOKEN_TYPES.AVAX;
                
                bonds.push({
                    bondId: result.bondIds[i].toString(),
                    principalAmount: isAVAX 
                        ? ethers.utils.formatEther(result.principalAmounts[i])
                        : ethers.utils.formatUnits(result.principalAmounts[i], 6),
                    currentValue: isAVAX
                        ? ethers.utils.formatEther(result.currentValues[i])
                        : ethers.utils.formatUnits(result.currentValues[i], 6),
                    yieldEarned: isAVAX
                        ? ethers.utils.formatEther(result.yieldEarned[i])
                        : ethers.utils.formatUnits(result.yieldEarned[i], 6),
                    maturityTime: new Date(result.maturityTimes[i].toNumber() * 1000),
                    isActive: result.activeStatus[i],
                    tokenType: isAVAX ? 'AVAX' : 'USDC',
                    tokenSymbol: isAVAX ? 'AVAX' : 'USDC'
                });
            }

            return bonds;

        } catch (error) {
            console.error("Failed to get donor bonds:", error);
            throw new Error(`Failed to retrieve bonds: ${error.message}`);
        }
    }

    /**
     * Redeem a matured bond (works for both AVAX and USDC)
     * @param {number} bondId - ID of the bond to redeem
     * @returns {Promise<Object>} Transaction result
     */
    async redeemBond(bondId) {
        try {
            if (!this.contract) throw new Error("Contract not initialized");

            const tx = await this.contract.redeemBond(bondId);
            const receipt = await tx.wait();

            return {
                success: true,
                transactionHash: receipt.transactionHash,
                bondId: bondId.toString()
            };

        } catch (error) {
            console.error("Bond redemption failed:", error);
            throw new Error(`Failed to redeem bond: ${error.message}`);
        }
    }

    /**
     * Emergency withdraw from a bond (with penalty)
     * @param {number} bondId - ID of the bond to withdraw from
     * @returns {Promise<Object>} Transaction result
     */
    async emergencyWithdraw(bondId) {
        try {
            if (!this.contract) throw new Error("Contract not initialized");

            const tx = await this.contract.emergencyWithdraw(bondId);
            const receipt = await tx.wait();

            return {
                success: true,
                transactionHash: receipt.transactionHash,
                bondId: bondId.toString(),
                note: "Emergency withdrawal completed with 50% yield penalty"
            };

        } catch (error) {
            console.error("Emergency withdrawal failed:", error);
            throw new Error(`Failed to emergency withdraw: ${error.message}`);
        }
    }

    // =========================================================================
    // POOL AND METRICS
    // =========================================================================

    /**
     * Get current pool balances for both AVAX and USDC
     * @returns {Promise<Object>} Pool balance information
     */
    async getPoolBalances() {
        try {
            if (!this.contract) throw new Error("Contract not initialized");

            const result = await this.contract.getPoolBalances();

            return {
                avax: {
                    balance: ethers.utils.formatEther(result.avaxBalance),
                    yieldReserve: ethers.utils.formatEther(result.avaxYield)
                },
                usdc: {
                    balance: ethers.utils.formatUnits(result.usdcBalance, 6),
                    yieldReserve: ethers.utils.formatUnits(result.usdcYield, 6)
                },
                totalValue: {
                    avax: ethers.utils.formatEther(result.avaxBalance.add(result.avaxYield)),
                    usdc: ethers.utils.formatUnits(result.usdcBalance.add(result.usdcYield), 6)
                }
            };

        } catch (error) {
            console.error("Failed to get pool balances:", error);
            throw new Error(`Failed to get pool balances: ${error.message}`);
        }
    }

    /**
     * Get comprehensive impact metrics for both tokens
     * @returns {Promise<Object>} Impact metrics
     */
    async getImpactMetrics() {
        try {
            if (!this.contract) throw new Error("Contract not initialized");

            const result = await this.contract.getImpactMetrics();

            return {
                totalBonds: result.totalBonds.toString(),
                avax: {
                    totalValue: ethers.utils.formatEther(result.totalAVAXValue),
                    totalYield: ethers.utils.formatEther(result.totalAVAXYield),
                    totalRelief: ethers.utils.formatEther(result.totalAVAXRelief)
                },
                usdc: {
                    totalValue: ethers.utils.formatUnits(result.totalUSDCValue, 6),
                    totalYield: ethers.utils.formatUnits(result.totalUSDCYield, 6),
                    totalRelief: ethers.utils.formatUnits(result.totalUSDCRelief, 6)
                },
                disastersHelped: result.disastersHelped.toString(),
                averageResponseTime: result.avgResponseTimeSec.toString() + " seconds",
                currentAPY: (result.currentAPYBasisPoints.toNumber() / 100).toFixed(2) + "%",
                activeBonds: result.activeBondCount.toString()
            };

        } catch (error) {
            console.error("Failed to get impact metrics:", error);
            throw new Error(`Failed to get impact metrics: ${error.message}`);
        }
    }

    // =========================================================================
    // YIELD OPERATIONS
    // =========================================================================

    /**
     * Generate yield on AVAX holdings (Treasury function)
     * @returns {Promise<Object>} Transaction result
     */
    async generateAVAXYield() {
        try {
            if (!this.contract) throw new Error("Contract not initialized");

            const tx = await this.contract.generateAVAXYield();
            const receipt = await tx.wait();

            return {
                success: true,
                transactionHash: receipt.transactionHash,
                type: 'yield_generation'
            };

        } catch (error) {
            console.error("AVAX yield generation failed:", error);
            throw new Error(`Failed to generate AVAX yield: ${error.message}`);
        }
    }

    // =========================================================================
    // UTILITY FUNCTIONS
    // =========================================================================

    /**
     * Check if user has sufficient AVAX balance for operation
     * @param {number} requiredAVAX - Required AVAX amount
     * @param {string} userAddress - User's wallet address
     * @returns {Promise<boolean>} Whether user has sufficient balance
     */
    async checkAVAXBalance(requiredAVAX, userAddress) {
        try {
            const balance = await this.provider.getBalance(userAddress);
            const balanceInAVAX = parseFloat(ethers.utils.formatEther(balance));
            const required = parseFloat(requiredAVAX);
            
            // Keep 0.01 AVAX for gas fees
            return balanceInAVAX >= (required + 0.01);

        } catch (error) {
            console.error("Failed to check AVAX balance:", error);
            return false;
        }
    }

    /**
     * Estimate gas cost for AVAX operations
     * @param {string} operation - Operation type (bond, donation, etc.)
     * @param {number} avaxAmount - AVAX amount for the operation
     * @returns {Promise<Object>} Gas estimation
     */
    async estimateGas(operation, avaxAmount = 0) {
        try {
            if (!this.contract) throw new Error("Contract not initialized");

            let gasEstimate;
            const avaxValue = avaxAmount > 0 ? ethers.utils.parseEther(avaxAmount.toString()) : 0;

            switch (operation) {
                case 'bond':
                    gasEstimate = await this.contract.estimateGas.issueAVAXBond(12, "Individual", {
                        value: avaxValue
                    });
                    break;
                case 'donation':
                    gasEstimate = await this.contract.estimateGas.donateAVAX({
                        value: avaxValue
                    });
                    break;
                default:
                    throw new Error("Unknown operation type");
            }

            const gasPrice = await this.provider.getGasPrice();
            const gasCost = gasEstimate.mul(gasPrice);

            return {
                gasLimit: gasEstimate.toString(),
                gasPrice: ethers.utils.formatUnits(gasPrice, 'gwei') + " gwei",
                gasCostAVAX: ethers.utils.formatEther(gasCost),
                totalCostAVAX: ethers.utils.formatEther(gasCost.add(avaxValue || 0))
            };

        } catch (error) {
            console.error("Gas estimation failed:", error);
            return {
                gasLimit: "200000", // Conservative estimate
                gasPrice: "25 gwei",
                gasCostAVAX: "0.005",
                totalCostAVAX: (0.005 + avaxAmount).toString()
            };
        }
    }
}

// Export utility functions and classes
export default AVAXDisasterReliefService;

// Helper function to format AVAX amounts
export const formatAVAX = (amount, decimals = 4) => {
    return parseFloat(amount).toFixed(decimals);
};

// Helper function to validate AVAX amount
export const validateAVAXAmount = (amount, operation = 'bond') => {
    const numAmount = parseFloat(amount);
    
    if (isNaN(numAmount) || numAmount <= 0) {
        return { valid: false, error: "Amount must be a positive number" };
    }
    
    if (operation === 'bond' && numAmount < 0.1) {
        return { valid: false, error: "Minimum bond amount is 0.1 AVAX" };
    }
    
    if (numAmount > 1000) {
        return { valid: false, error: "Maximum amount is 1000 AVAX per transaction" };
    }
    
    return { valid: true };
};

// Helper function to calculate bond maturity date
export const calculateMaturityDate = (months) => {
    const maturityDate = new Date();
    maturityDate.setMonth(maturityDate.getMonth() + months);
    return maturityDate;
};

// Helper function to calculate estimated yield
export const calculateEstimatedYield = (avaxAmount, months, apyPercent = 4.2) => {
    const yearlyYield = (parseFloat(avaxAmount) * apyPercent) / 100;
    const periodYield = (yearlyYield * months) / 12;
    return periodYield.toFixed(4);
};
