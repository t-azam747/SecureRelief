// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Mock USDC interface (using your existing MockUSDC)
interface IUSDC {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title DisasterReliefBondsV2
 * @dev Revolutionary pre-funded disaster relief system with yield generation
 * @notice Implementation of the Disaster Relief Bonds vision for Avalanche
 */
contract DisasterReliefBondsV2 {
    // Admin and role management
    address public admin;
    mapping(address => bool) public oracles;
    mapping(address => bool) public governments;
    mapping(address => bool) public treasuryManagers;

    IUSDC public immutable USDC;

    struct ReliefBond {
        uint256 bondId;
        address donor;
        uint256 principalAmount; // Original donation
        uint256 currentValue; // Principal + earned yield
        uint256 yieldEarned; // Accumulated yield
        uint256 maturityTime; // When donor can withdraw
        bool activeForRelief; // Available for emergency use
        string donorType; // "Individual", "Corporate", "ESG"
        uint256 createdAt;
    }

    struct DisasterEvent {
        bytes32 eventId;
        string location;
        uint256 severity; // 1-10 scale
        uint256 estimatedVictims;
        uint256 fundingRequired;
        uint256 fundingReleased;
        bool governmentApproved;
        uint256 timestamp;
        uint256 responseTime; // Time from detection to first payout
    }

    struct EmergencyPayout {
        address beneficiary;
        uint256 amount;
        uint256 timestamp;
        bytes32 disasterEventId;
        PaymentMethod method;
    }

    enum PaymentMethod {
        CRYPTO, // Direct blockchain transfer
        BANK_TRANSFER, // Traditional banking integration
        MOBILE_MONEY, // M-Pesa, bKash, etc.
        CUSTODIAL // Non-crypto users

    }

    // State variables
    mapping(uint256 => ReliefBond) public bonds;
    mapping(bytes32 => DisasterEvent) public disasters;
    mapping(address => uint256[]) public donorBonds;
    mapping(address => bool) public registeredVictims;
    mapping(bytes32 => address[]) public disasterBeneficiaries;

    uint256 public nextBondId = 1;
    uint256 public totalBondsValue;
    uint256 public totalYieldEarned;
    uint256 public totalReliefDistributed;
    uint256 public averageResponseTime;
    uint256 public disasterCount;

    // Yield strategy parameters
    uint256 public targetAPY = 300; // 3.00% APY
    uint256 public currentAPY = 320; // 3.20% current
    uint256 public yieldReserve; // Accumulated yield

    // Emergency parameters
    uint256 public constant EMERGENCY_SEVERITY_THRESHOLD = 5;
    uint256 public constant MAX_BULK_PAYOUT = 10000; // Max beneficiaries per transaction

    // Events for transparency and monitoring
    event BondIssued(
        address indexed donor,
        uint256 bondId,
        uint256 amount,
        string donorType,
        uint256 maturityTime
    );

    event DisasterReported(
        bytes32 indexed eventId, string location, uint256 severity, uint256 estimatedVictims
    );

    event EmergencyFundRelease(
        bytes32 indexed eventId, uint256 totalAmount, uint256 beneficiaryCount, uint256 responseTime
    );

    event BulkPayoutExecuted(
        bytes32 indexed eventId, uint256 beneficiaryCount, uint256 totalAmount, address government
    );

    event YieldGenerated(uint256 amount, uint256 newAPY, uint256 totalYield);

    event VictimSelfRegistered(address indexed victim, bytes32 indexed eventId, string location);

    event BondMatured(uint256 bondId, address donor, uint256 finalValue, uint256 yieldEarned);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyOracle() {
        require(oracles[msg.sender], "Only oracle");
        _;
    }

    modifier onlyGovernment() {
        require(governments[msg.sender], "Only government");
        _;
    }

    modifier onlyTreasury() {
        require(treasuryManagers[msg.sender], "Only treasury");
        _;
    }

    modifier validBond(uint256 bondId) {
        require(bondId > 0 && bondId < nextBondId, "Invalid bond ID");
        require(bonds[bondId].activeForRelief, "Bond not active");
        _;
    }

    modifier emergencyOnly(bytes32 eventId) {
        require(disasters[eventId].severity >= EMERGENCY_SEVERITY_THRESHOLD, "Not emergency level");
        require(disasters[eventId].governmentApproved, "Not government approved");
        _;
    }

    constructor(address _usdc) {
        USDC = IUSDC(_usdc);
        admin = msg.sender;
        treasuryManagers[msg.sender] = true;
    }

    // =========================================================================
    // BOND ISSUANCE - Corporate ESG and Individual Donors
    // =========================================================================

    /**
     * @dev Corporate/ESG/Individual investment in disaster preparedness
     * @notice Creates a bond that earns yield while available for relief
     * @param principalAmount Amount to invest (minimum 100 USDC)
     * @param maturityMonths When donor can withdraw (6-60 months)
     * @param donorType "Individual", "Corporate", "ESG Fund", etc.
     */
    function issueBond(uint256 principalAmount, uint256 maturityMonths, string memory donorType)
        external
        returns (uint256 bondId)
    {
        require(principalAmount >= 100 * 1e6, "Minimum 100 USDC");
        require(maturityMonths >= 6 && maturityMonths <= 60, "6-60 month maturity");
        require(bytes(donorType).length > 0, "Donor type required");

        // Transfer USDC from donor
        require(
            USDC.transferFrom(msg.sender, address(this), principalAmount), "USDC transfer failed"
        );

        bondId = nextBondId++;
        uint256 maturityTime = block.timestamp + (maturityMonths * 30 days);

        // Create bond with yield earning potential
        bonds[bondId] = ReliefBond({
            bondId: bondId,
            donor: msg.sender,
            principalAmount: principalAmount,
            currentValue: principalAmount,
            yieldEarned: 0,
            maturityTime: maturityTime,
            activeForRelief: true,
            donorType: donorType,
            createdAt: block.timestamp
        });

        // Track donor's bonds
        donorBonds[msg.sender].push(bondId);

        // Update pool totals
        totalBondsValue += principalAmount;

        emit BondIssued(msg.sender, bondId, principalAmount, donorType, maturityTime);
        return bondId;
    }

    // =========================================================================
    // DISASTER DETECTION & RESPONSE
    // =========================================================================

    /**
     * @dev Oracle reports disaster with government verification
     * @notice Triggers automated emergency response system
     */
    function reportDisaster(
        bytes32 eventId,
        string memory location,
        uint256 severity,
        uint256 estimatedVictims,
        uint256 fundingRequired
    ) external onlyOracle {
        require(disasters[eventId].timestamp == 0, "Disaster already reported");
        require(severity >= 1 && severity <= 10, "Invalid severity scale");
        require(estimatedVictims > 0, "Must have victims");
        require(fundingRequired > 0, "Funding required");

        disasters[eventId] = DisasterEvent({
            eventId: eventId,
            location: location,
            severity: severity,
            estimatedVictims: estimatedVictims,
            fundingRequired: fundingRequired,
            fundingReleased: 0,
            governmentApproved: false, // Requires government approval
            timestamp: block.timestamp,
            responseTime: 0
        });

        disasterCount++;

        emit DisasterReported(eventId, location, severity, estimatedVictims);
    }

    /**
     * @dev Government approves disaster and enables fund release
     * @notice Government verification step for security
     */
    function approveDisaster(bytes32 eventId) external onlyGovernment {
        require(disasters[eventId].timestamp != 0, "Disaster not found");
        require(!disasters[eventId].governmentApproved, "Already approved");

        disasters[eventId].governmentApproved = true;

        // Auto-prepare emergency funds for high severity disasters
        if (disasters[eventId].severity >= EMERGENCY_SEVERITY_THRESHOLD) {
            _prepareEmergencyFunds(disasters[eventId].fundingRequired);
        }
    }

    // =========================================================================
    // BULK GOVERNMENT PAYOUT SYSTEM
    // =========================================================================

    /**
     * @dev Government bulk beneficiary upload and instant payout
     * @notice One-click mass distribution to thousands of pre-verified citizens
     * @param eventId Disaster event identifier
     * @param beneficiaries Array of victim addresses (can be custodial)
     * @param amounts Array of payout amounts per beneficiary
     * @param methods Array of payment methods per beneficiary
     */
    function executeBulkPayout(
        bytes32 eventId,
        address[] memory beneficiaries,
        uint256[] memory amounts,
        PaymentMethod[] memory methods
    ) external onlyGovernment emergencyOnly(eventId) {
        require(beneficiaries.length == amounts.length, "Array length mismatch");
        require(beneficiaries.length == methods.length, "Method array mismatch");
        require(beneficiaries.length <= MAX_BULK_PAYOUT, "Too many beneficiaries");
        require(beneficiaries.length > 0, "No beneficiaries");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "Invalid amount");
            totalAmount += amounts[i];
        }

        require(totalAmount <= totalBondsValue, "Insufficient pool funds");

        // Record response time
        uint256 responseTime = block.timestamp - disasters[eventId].timestamp;
        disasters[eventId].responseTime = responseTime;
        averageResponseTime =
            (averageResponseTime * (disasterCount - 1) + responseTime) / disasterCount;

        // Execute instant payouts to all beneficiaries
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _executePayout(eventId, beneficiaries[i], amounts[i], methods[i]);
        }

        // Update disaster and pool tracking
        disasters[eventId].fundingReleased += totalAmount;
        totalReliefDistributed += totalAmount;
        _updateBondValuesAfterPayout(totalAmount);

        emit BulkPayoutExecuted(eventId, beneficiaries.length, totalAmount, msg.sender);
        emit EmergencyFundRelease(eventId, totalAmount, beneficiaries.length, responseTime);
    }

    // =========================================================================
    // VICTIM SELF-REGISTRATION SYSTEM
    // =========================================================================

    /**
     * @dev Self-registration for victims missed by government database
     * @notice Allows unlisted victims to register for relief verification
     */
    function selfRegisterForRelief(bytes32 eventId, string memory location) external {
        require(disasters[eventId].timestamp != 0, "Disaster not found");
        require(disasters[eventId].governmentApproved, "Disaster not approved");
        require(!registeredVictims[msg.sender], "Already registered");
        require(bytes(location).length > 0, "Location required");

        registeredVictims[msg.sender] = true;

        // Add to pending verification list (would integrate with verification system)
        emit VictimSelfRegistered(msg.sender, eventId, location);
    }

    /**
     * @dev Government verifies self-registered victim
     * @notice Approves victim for relief after manual verification
     */
    function verifyVictim(
        address victim,
        bytes32 eventId,
        uint256 reliefAmount,
        PaymentMethod method
    ) external onlyGovernment emergencyOnly(eventId) {
        require(registeredVictims[victim], "Victim not registered");
        require(reliefAmount > 0, "Invalid relief amount");
        require(reliefAmount <= totalBondsValue, "Insufficient funds");

        _executePayout(eventId, victim, reliefAmount, method);

        disasters[eventId].fundingReleased += reliefAmount;
        totalReliefDistributed += reliefAmount;
        _updateBondValuesAfterPayout(reliefAmount);
    }

    // =========================================================================
    // YIELD GENERATION SYSTEM
    // =========================================================================

    /**
     * @dev Generate yield on idle bond funds
     * @notice Simulates investment in safe, liquid DeFi protocols (Aave, Compound)
     */
    function generateYield() external onlyTreasury {
        uint256 poolBalance = USDC.balanceOf(address(this));
        require(poolBalance > 0, "No funds to invest");

        // Simulate yield generation (3-5% APY)
        // In production: integrate with Aave, Compound, or government bond protocols
        uint256 timeElapsed = block.timestamp - _getLastYieldUpdate();
        uint256 annualizedYield = (poolBalance * currentAPY) / 10000; // currentAPY in basis points
        uint256 periodYield = (annualizedYield * timeElapsed) / 365 days;

        if (periodYield > 0) {
            yieldReserve += periodYield;
            totalYieldEarned += periodYield;

            // Distribute yield proportionally to active bonds
            _distributeYieldToBonds(periodYield);

            // Update APY based on market conditions
            _updateAPY();

            emit YieldGenerated(periodYield, currentAPY, totalYieldEarned);
        }
    }

    // =========================================================================
    // BOND MATURITY & WITHDRAWAL
    // =========================================================================

    /**
     * @dev Donor redeems matured bond with principal + yield
     * @notice Allows donors to withdraw after maturity period
     */
    function redeemBond(uint256 bondId) external validBond(bondId) {
        ReliefBond storage bond = bonds[bondId];
        require(bond.donor == msg.sender, "Not bond owner");
        require(block.timestamp >= bond.maturityTime, "Bond not matured");

        uint256 redeemAmount = bond.currentValue;
        uint256 yieldEarned = bond.yieldEarned;

        // Mark bond as inactive
        bond.activeForRelief = false;
        totalBondsValue -= bond.principalAmount;

        // Transfer final value to donor
        require(USDC.transfer(msg.sender, redeemAmount), "Transfer failed");

        emit BondMatured(bondId, msg.sender, redeemAmount, yieldEarned);
    }

    /**
     * @dev Emergency early withdrawal (with penalty)
     * @notice Allows early withdrawal with reduced yield
     */
    function emergencyWithdraw(uint256 bondId) external validBond(bondId) {
        ReliefBond storage bond = bonds[bondId];
        require(bond.donor == msg.sender, "Not bond owner");

        // Calculate penalty (lose 50% of yield for early withdrawal)
        uint256 penaltyAmount = bond.yieldEarned / 2;
        uint256 withdrawAmount = bond.currentValue - penaltyAmount;

        bond.activeForRelief = false;
        totalBondsValue -= bond.principalAmount;
        yieldReserve += penaltyAmount; // Penalty goes back to yield reserve

        require(USDC.transfer(msg.sender, withdrawAmount), "Transfer failed");
    }

    // =========================================================================
    // IMPACT METRICS & ESG REPORTING
    // =========================================================================

    /**
     * @dev Get comprehensive impact metrics for ESG reporting
     * @notice Returns data for corporate impact dashboards
     */
    function getImpactMetrics()
        external
        view
        returns (
            uint256 totalBonds,
            uint256 totalValue,
            uint256 totalYield,
            uint256 totalRelief,
            uint256 disastersHelped,
            uint256 avgResponseTimeSec,
            uint256 currentAPYBasisPoints,
            uint256 activeBondCount
        )
    {
        return (
            nextBondId - 1,
            totalBondsValue,
            totalYieldEarned,
            totalReliefDistributed,
            disasterCount,
            averageResponseTime,
            currentAPY,
            _getActiveBondCount()
        );
    }

    /**
     * @dev Get detailed bond information for donor
     */
    function getDonorBonds(address donor)
        external
        view
        returns (
            uint256[] memory bondIds,
            uint256[] memory principalAmounts,
            uint256[] memory currentValues,
            uint256[] memory yieldEarned,
            uint256[] memory maturityTimes,
            bool[] memory activeStatus
        )
    {
        uint256[] memory bonds_list = donorBonds[donor];
        uint256 length = bonds_list.length;

        bondIds = new uint256[](length);
        principalAmounts = new uint256[](length);
        currentValues = new uint256[](length);
        yieldEarned = new uint256[](length);
        maturityTimes = new uint256[](length);
        activeStatus = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 bondId = bonds_list[i];
            ReliefBond memory bond = bonds[bondId];

            bondIds[i] = bondId;
            principalAmounts[i] = bond.principalAmount;
            currentValues[i] = bond.currentValue;
            yieldEarned[i] = bond.yieldEarned;
            maturityTimes[i] = bond.maturityTime;
            activeStatus[i] = bond.activeForRelief;
        }
    }

    /**
     * @dev Get disaster details and response metrics
     */
    function getDisasterDetails(bytes32 eventId)
        external
        view
        returns (
            string memory location,
            uint256 severity,
            uint256 estimatedVictims,
            uint256 fundingRequired,
            uint256 fundingReleased,
            bool governmentApproved,
            uint256 timestamp,
            uint256 responseTime
        )
    {
        DisasterEvent memory disaster = disasters[eventId];
        return (
            disaster.location,
            disaster.severity,
            disaster.estimatedVictims,
            disaster.fundingRequired,
            disaster.fundingReleased,
            disaster.governmentApproved,
            disaster.timestamp,
            disaster.responseTime
        );
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    function addOracle(address oracle) external onlyAdmin {
        oracles[oracle] = true;
    }

    function removeOracle(address oracle) external onlyAdmin {
        oracles[oracle] = false;
    }

    function addGovernment(address government) external onlyAdmin {
        governments[government] = true;
    }

    function removeGovernment(address government) external onlyAdmin {
        governments[government] = false;
    }

    function addTreasuryManager(address manager) external onlyAdmin {
        treasuryManagers[manager] = true;
    }

    function removeTreasuryManager(address manager) external onlyAdmin {
        treasuryManagers[manager] = false;
    }

    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================

    function _executePayout(
        bytes32 eventId,
        address beneficiary,
        uint256 amount,
        PaymentMethod method
    ) internal {
        if (method == PaymentMethod.CRYPTO) {
            // Direct blockchain transfer
            require(USDC.transfer(beneficiary, amount), "Crypto transfer failed");
        } else {
            // For other methods, transfer to custodial contract or bridge
            // Implementation would integrate with banking/mobile money systems
            require(USDC.transfer(beneficiary, amount), "Payout transfer failed");
        }
    }

    function _updateBondValuesAfterPayout(uint256 totalPayout) internal {
        // Proportionally reduce bond values after emergency payout
        if (totalBondsValue > 0) {
            uint256 reductionRatio = (totalPayout * 1e18) / totalBondsValue;

            for (uint256 i = 1; i < nextBondId; i++) {
                if (bonds[i].activeForRelief) {
                    uint256 reduction = (bonds[i].currentValue * reductionRatio) / 1e18;
                    bonds[i].currentValue -= reduction;
                }
            }

            totalBondsValue -= totalPayout;
        }
    }

    function _distributeYieldToBonds(uint256 totalYield) internal {
        if (totalBondsValue > 0) {
            for (uint256 i = 1; i < nextBondId; i++) {
                if (bonds[i].activeForRelief) {
                    uint256 bondShare = (bonds[i].principalAmount * totalYield) / totalBondsValue;
                    bonds[i].currentValue += bondShare;
                    bonds[i].yieldEarned += bondShare;
                }
            }
        }
    }

    function _prepareEmergencyFunds(uint256 requiredAmount) internal {
        // Ensure sufficient liquidity for emergency response
        uint256 currentBalance = USDC.balanceOf(address(this));
        require(currentBalance >= requiredAmount, "Insufficient emergency funds");
    }

    function _updateAPY() internal {
        // Update APY based on market conditions and pool performance
        // In production: integrate with real yield protocols
        if (totalBondsValue > 1000000 * 1e6) {
            // > $1M pool
            currentAPY = 350; // 3.5% for larger pools
        } else {
            currentAPY = 300; // 3.0% for smaller pools
        }
    }

    function _getLastYieldUpdate() internal view returns (uint256) {
        // Placeholder - would track last yield generation timestamp
        return block.timestamp - 1 days;
    }

    function _getActiveBondCount() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 1; i < nextBondId; i++) {
            if (bonds[i].activeForRelief) {
                count++;
            }
        }
        return count;
    }
}
