// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Mock USDC interface (using your existing MockUSDC)
interface IUSDC {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title DisasterReliefBondsV3
 * @dev Revolutionary pre-funded disaster relief system supporting both AVAX and USDC
 * @notice Implementation of the Disaster Relief Bonds vision for Avalanche with native token support
 */
contract DisasterReliefBondsV3 {
    // Admin and role management
    address public admin;
    mapping(address => bool) public oracles;
    mapping(address => bool) public governments;
    mapping(address => bool) public treasuryManagers;

    IUSDC public immutable USDC;

    // Token type enum
    enum TokenType {
        AVAX,
        USDC
    }

    struct ReliefBond {
        uint256 bondId;
        address donor;
        uint256 principalAmount; // Original donation
        uint256 currentValue; // Principal + earned yield
        uint256 yieldEarned; // Accumulated yield
        uint256 maturityTime; // When donor can withdraw
        bool activeForRelief; // Available for emergency use
        string donorType; // "Individual", "Corporate", "ESG"
        TokenType tokenType; // AVAX or USDC
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
        TokenType tokenType;
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

    // Separate tracking for AVAX and USDC
    uint256 public totalAVAXBondsValue;
    uint256 public totalUSDCBondsValue;
    uint256 public totalAVAXYieldEarned;
    uint256 public totalUSDCYieldEarned;
    uint256 public totalAVAXReliefDistributed;
    uint256 public totalUSDCReliefDistributed;

    uint256 public averageResponseTime;
    uint256 public disasterCount;

    // Yield strategy parameters
    uint256 public targetAPY = 300; // 3.00% APY
    uint256 public currentAPY = 320; // 3.20% current
    uint256 public avaxYieldReserve; // Accumulated AVAX yield
    uint256 public usdcYieldReserve; // Accumulated USDC yield

    // Emergency parameters
    uint256 public constant EMERGENCY_SEVERITY_THRESHOLD = 5;
    uint256 public constant MAX_BULK_PAYOUT = 10000; // Max beneficiaries per transaction

    // AVAX/USDC conversion rate (for display purposes - in production use oracle)
    uint256 public avaxToUsdcRate = 3000; // 1 AVAX = 30.00 USDC (100x for precision)

    // Events for transparency and monitoring
    event BondIssued(
        address indexed donor,
        uint256 bondId,
        uint256 amount,
        string donorType,
        uint256 maturityTime,
        TokenType tokenType
    );

    event AVAXBondIssued(
        address indexed donor,
        uint256 bondId,
        uint256 avaxAmount,
        string donorType,
        uint256 maturityTime
    );

    event DisasterReported(
        bytes32 indexed eventId, string location, uint256 severity, uint256 estimatedVictims
    );

    event EmergencyFundRelease(
        bytes32 indexed eventId,
        uint256 totalAmount,
        uint256 beneficiaryCount,
        uint256 responseTime,
        TokenType tokenType
    );

    event BulkPayoutExecuted(
        bytes32 indexed eventId,
        uint256 beneficiaryCount,
        uint256 totalAmount,
        address government,
        TokenType tokenType
    );

    event YieldGenerated(uint256 amount, uint256 newAPY, uint256 totalYield, TokenType tokenType);

    event VictimSelfRegistered(address indexed victim, bytes32 indexed eventId, string location);

    event BondMatured(
        uint256 bondId, address donor, uint256 finalValue, uint256 yieldEarned, TokenType tokenType
    );

    event AVAXYieldGenerated(uint256 avaxAmount, uint256 newAPY, uint256 totalAVAXYield);

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
    // AVAX BOND ISSUANCE - NEW FUNCTIONALITY
    // =========================================================================

    /**
     * @dev Issue bond with native AVAX from your wallet
     * @notice Allows users to donate AVAX directly from their wallet
     * @param maturityMonths When donor can withdraw (6-60 months)
     * @param donorType "Individual", "Corporate", "ESG Fund", etc.
     */
    function issueAVAXBond(uint256 maturityMonths, string memory donorType)
        external
        payable
        returns (uint256 bondId)
    {
        require(msg.value >= 0.1 ether, "Minimum 0.1 AVAX"); // About $3 minimum
        require(maturityMonths >= 6 && maturityMonths <= 60, "6-60 month maturity");
        require(bytes(donorType).length > 0, "Donor type required");

        bondId = nextBondId++;
        uint256 maturityTime = block.timestamp + (maturityMonths * 30 days);

        // Create AVAX bond
        bonds[bondId] = ReliefBond({
            bondId: bondId,
            donor: msg.sender,
            principalAmount: msg.value,
            currentValue: msg.value,
            yieldEarned: 0,
            maturityTime: maturityTime,
            activeForRelief: true,
            donorType: donorType,
            tokenType: TokenType.AVAX,
            createdAt: block.timestamp
        });

        // Track donor's bonds
        donorBonds[msg.sender].push(bondId);

        // Update AVAX pool totals
        totalAVAXBondsValue += msg.value;

        emit AVAXBondIssued(msg.sender, bondId, msg.value, donorType, maturityTime);
        emit BondIssued(msg.sender, bondId, msg.value, donorType, maturityTime, TokenType.AVAX);
        return bondId;
    }

    /**
     * @dev Direct AVAX donation (no bond, immediate availability)
     * @notice For immediate disaster relief contributions
     */
    function donateAVAX() external payable {
        require(msg.value > 0, "Must send AVAX");

        // Add to AVAX yield reserve for immediate use
        avaxYieldReserve += msg.value;

        emit AVAXYieldGenerated(msg.value, currentAPY, totalAVAXYieldEarned);
    }

    // =========================================================================
    // USDC BOND ISSUANCE - EXISTING FUNCTIONALITY
    // =========================================================================

    /**
     * @dev Corporate/ESG/Individual investment in disaster preparedness (USDC)
     * @notice Creates a USDC bond that earns yield while available for relief
     * @param principalAmount Amount to invest (minimum 100 USDC)
     * @param maturityMonths When donor can withdraw (6-60 months)
     * @param donorType "Individual", "Corporate", "ESG Fund", etc.
     */
    function issueUSDCBond(uint256 principalAmount, uint256 maturityMonths, string memory donorType)
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

        // Create USDC bond
        bonds[bondId] = ReliefBond({
            bondId: bondId,
            donor: msg.sender,
            principalAmount: principalAmount,
            currentValue: principalAmount,
            yieldEarned: 0,
            maturityTime: maturityTime,
            activeForRelief: true,
            donorType: donorType,
            tokenType: TokenType.USDC,
            createdAt: block.timestamp
        });

        // Track donor's bonds
        donorBonds[msg.sender].push(bondId);

        // Update USDC pool totals
        totalUSDCBondsValue += principalAmount;

        emit BondIssued(
            msg.sender, bondId, principalAmount, donorType, maturityTime, TokenType.USDC
        );
        return bondId;
    }

    // Forward declaration for backward compatibility
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

        // Create USDC bond
        bonds[bondId] = ReliefBond({
            bondId: bondId,
            donor: msg.sender,
            principalAmount: principalAmount,
            currentValue: principalAmount,
            yieldEarned: 0,
            maturityTime: maturityTime,
            activeForRelief: true,
            donorType: donorType,
            tokenType: TokenType.USDC,
            createdAt: block.timestamp
        });

        // Track donor's bonds
        donorBonds[msg.sender].push(bondId);

        // Update USDC pool totals
        totalUSDCBondsValue += principalAmount;

        emit BondIssued(
            msg.sender, bondId, principalAmount, donorType, maturityTime, TokenType.USDC
        );
        return bondId;
    }

    // =========================================================================
    // DISASTER DETECTION & RESPONSE (SAME AS V2)
    // =========================================================================

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
            governmentApproved: false,
            timestamp: block.timestamp,
            responseTime: 0
        });

        disasterCount++;

        emit DisasterReported(eventId, location, severity, estimatedVictims);
    }

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
    // BULK PAYOUT SYSTEM - ENHANCED FOR BOTH TOKENS
    // =========================================================================

    /**
     * @dev Government bulk AVAX payout to beneficiaries
     * @notice Instant AVAX distribution to disaster victims
     */
    function executeBulkAVAXPayout(
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

        require(totalAmount <= address(this).balance, "Insufficient AVAX funds");

        // Record response time
        uint256 responseTime = block.timestamp - disasters[eventId].timestamp;
        disasters[eventId].responseTime = responseTime;
        averageResponseTime =
            (averageResponseTime * (disasterCount - 1) + responseTime) / disasterCount;

        // Execute instant AVAX payouts
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _executeAVAXPayout(eventId, beneficiaries[i], amounts[i], methods[i]);
        }

        // Update disaster and pool tracking
        disasters[eventId].fundingReleased += totalAmount;
        totalAVAXReliefDistributed += totalAmount;
        _updateAVAXBondValuesAfterPayout(totalAmount);

        emit BulkPayoutExecuted(
            eventId, beneficiaries.length, totalAmount, msg.sender, TokenType.AVAX
        );
        emit EmergencyFundRelease(
            eventId, totalAmount, beneficiaries.length, responseTime, TokenType.AVAX
        );
    }

    /**
     * @dev Government bulk USDC payout to beneficiaries (existing functionality)
     */
    function executeBulkUSDCPayout(
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

        require(totalAmount <= totalUSDCBondsValue, "Insufficient USDC pool funds");

        // Record response time
        uint256 responseTime = block.timestamp - disasters[eventId].timestamp;
        disasters[eventId].responseTime = responseTime;
        averageResponseTime =
            (averageResponseTime * (disasterCount - 1) + responseTime) / disasterCount;

        // Execute instant USDC payouts
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _executeUSDCPayout(eventId, beneficiaries[i], amounts[i], methods[i]);
        }

        // Update disaster and pool tracking
        disasters[eventId].fundingReleased += totalAmount;
        totalUSDCReliefDistributed += totalAmount;
        _updateUSDCBondValuesAfterPayout(totalAmount);

        emit BulkPayoutExecuted(
            eventId, beneficiaries.length, totalAmount, msg.sender, TokenType.USDC
        );
        emit EmergencyFundRelease(
            eventId, totalAmount, beneficiaries.length, responseTime, TokenType.USDC
        );
    }

    // Backward compatibility wrapper
    function executeBulkPayout(
        bytes32 eventId,
        address[] memory beneficiaries,
        uint256[] memory amounts,
        PaymentMethod[] memory methods
    ) external onlyGovernment emergencyOnly(eventId) {
        // Default to USDC for backward compatibility
        this.executeBulkUSDCPayout(eventId, beneficiaries, amounts, methods);
    }

    // =========================================================================
    // VICTIM SELF-REGISTRATION (SAME AS V2)
    // =========================================================================

    function selfRegisterForRelief(bytes32 eventId, string memory location) external {
        require(disasters[eventId].timestamp != 0, "Disaster not found");
        require(disasters[eventId].governmentApproved, "Disaster not approved");
        require(!registeredVictims[msg.sender], "Already registered");
        require(bytes(location).length > 0, "Location required");

        registeredVictims[msg.sender] = true;

        emit VictimSelfRegistered(msg.sender, eventId, location);
    }

    /**
     * @dev Government verifies victim for AVAX relief
     */
    function verifyVictimForAVAX(
        address victim,
        bytes32 eventId,
        uint256 reliefAmount,
        PaymentMethod method
    ) external onlyGovernment emergencyOnly(eventId) {
        require(registeredVictims[victim], "Victim not registered");
        require(reliefAmount > 0, "Invalid relief amount");
        require(reliefAmount <= address(this).balance, "Insufficient AVAX funds");

        _executeAVAXPayout(eventId, victim, reliefAmount, method);

        disasters[eventId].fundingReleased += reliefAmount;
        totalAVAXReliefDistributed += reliefAmount;
        _updateAVAXBondValuesAfterPayout(reliefAmount);
    }

    /**
     * @dev Government verifies victim for USDC relief
     */
    function verifyVictimForUSDC(
        address victim,
        bytes32 eventId,
        uint256 reliefAmount,
        PaymentMethod method
    ) external onlyGovernment emergencyOnly(eventId) {
        require(registeredVictims[victim], "Victim not registered");
        require(reliefAmount > 0, "Invalid relief amount");
        require(reliefAmount <= totalUSDCBondsValue, "Insufficient USDC funds");

        _executeUSDCPayout(eventId, victim, reliefAmount, method);

        disasters[eventId].fundingReleased += reliefAmount;
        totalUSDCReliefDistributed += reliefAmount;
        _updateUSDCBondValuesAfterPayout(reliefAmount);
    }

    // Backward compatibility
    function verifyVictim(
        address victim,
        bytes32 eventId,
        uint256 reliefAmount,
        PaymentMethod method
    ) external onlyGovernment emergencyOnly(eventId) {
        require(registeredVictims[victim], "Victim not registered");
        require(reliefAmount > 0, "Invalid relief amount");
        require(reliefAmount <= totalUSDCBondsValue, "Insufficient USDC funds");

        _executeUSDCPayout(eventId, victim, reliefAmount, method);

        disasters[eventId].fundingReleased += reliefAmount;
        totalUSDCReliefDistributed += reliefAmount;
        _updateUSDCBondValuesAfterPayout(reliefAmount);
    }

    // =========================================================================
    // YIELD GENERATION - ENHANCED FOR BOTH TOKENS
    // =========================================================================

    /**
     * @dev Generate yield on AVAX holdings
     * @notice Simulates AVAX staking or DeFi yield
     */
    function generateAVAXYield() external onlyTreasury {
        uint256 avaxBalance = address(this).balance;
        require(avaxBalance > 0, "No AVAX to generate yield");

        // Simulate AVAX staking yield (4-8% APY)
        uint256 timeElapsed = block.timestamp - _getLastYieldUpdate();
        uint256 annualizedYield = (avaxBalance * (currentAPY + 100)) / 10000; // +1% bonus for AVAX
        uint256 periodYield = (annualizedYield * timeElapsed) / 365 days;

        if (periodYield > 0) {
            avaxYieldReserve += periodYield;
            totalAVAXYieldEarned += periodYield;

            // Distribute yield proportionally to AVAX bonds
            _distributeAVAXYieldToBonds(periodYield);

            emit AVAXYieldGenerated(periodYield, currentAPY + 100, totalAVAXYieldEarned);
            emit YieldGenerated(periodYield, currentAPY + 100, totalAVAXYieldEarned, TokenType.AVAX);
        }
    }

    /**
     * @dev Generate yield on USDC holdings
     * @notice Simulates investment in safe, liquid DeFi protocols
     */
    function generateUSDCYield() external onlyTreasury {
        uint256 usdcBalance = USDC.balanceOf(address(this));
        require(usdcBalance > 0, "No USDC to invest");

        // Simulate USDC yield generation (3-5% APY)
        uint256 timeElapsed = block.timestamp - _getLastYieldUpdate();
        uint256 annualizedYield = (usdcBalance * currentAPY) / 10000;
        uint256 periodYield = (annualizedYield * timeElapsed) / 365 days;

        if (periodYield > 0) {
            usdcYieldReserve += periodYield;
            totalUSDCYieldEarned += periodYield;

            // Distribute yield proportionally to USDC bonds
            _distributeUSDCYieldToBonds(periodYield);

            emit YieldGenerated(periodYield, currentAPY, totalUSDCYieldEarned, TokenType.USDC);
        }
    }

    // Backward compatibility
    function generateYield() external onlyTreasury {
        uint256 usdcBalance = USDC.balanceOf(address(this));
        require(usdcBalance > 0, "No USDC to invest");

        // Simulate USDC yield generation (3-5% APY)
        uint256 timeElapsed = block.timestamp - _getLastYieldUpdate();
        uint256 annualizedYield = (usdcBalance * currentAPY) / 10000;
        uint256 periodYield = (annualizedYield * timeElapsed) / 365 days;

        if (periodYield > 0) {
            usdcYieldReserve += periodYield;
            totalUSDCYieldEarned += periodYield;

            // Distribute yield proportionally to USDC bonds
            _distributeUSDCYieldToBonds(periodYield);

            emit YieldGenerated(periodYield, currentAPY, totalUSDCYieldEarned, TokenType.USDC);
        }
    }

    // =========================================================================
    // BOND MATURITY & WITHDRAWAL - ENHANCED FOR BOTH TOKENS
    // =========================================================================

    /**
     * @dev Redeem matured bond (works for both AVAX and USDC)
     * @notice Automatically detects token type and transfers accordingly
     */
    function redeemBond(uint256 bondId) external validBond(bondId) {
        ReliefBond storage bond = bonds[bondId];
        require(bond.donor == msg.sender, "Not bond owner");
        require(block.timestamp >= bond.maturityTime, "Bond not matured");

        uint256 redeemAmount = bond.currentValue;
        uint256 yieldEarned = bond.yieldEarned;
        TokenType tokenType = bond.tokenType;

        // Mark bond as inactive
        bond.activeForRelief = false;

        if (tokenType == TokenType.AVAX) {
            totalAVAXBondsValue -= bond.principalAmount;
            require(address(this).balance >= redeemAmount, "Insufficient AVAX balance");
            payable(msg.sender).transfer(redeemAmount);
        } else {
            totalUSDCBondsValue -= bond.principalAmount;
            require(USDC.transfer(msg.sender, redeemAmount), "USDC transfer failed");
        }

        emit BondMatured(bondId, msg.sender, redeemAmount, yieldEarned, tokenType);
    }

    /**
     * @dev Emergency early withdrawal with penalty (works for both tokens)
     */
    function emergencyWithdraw(uint256 bondId) external validBond(bondId) {
        ReliefBond storage bond = bonds[bondId];
        require(bond.donor == msg.sender, "Not bond owner");

        // Calculate penalty (lose 50% of yield for early withdrawal)
        uint256 penaltyAmount = bond.yieldEarned / 2;
        uint256 withdrawAmount = bond.currentValue - penaltyAmount;
        TokenType tokenType = bond.tokenType;

        bond.activeForRelief = false;

        if (tokenType == TokenType.AVAX) {
            totalAVAXBondsValue -= bond.principalAmount;
            avaxYieldReserve += penaltyAmount; // Penalty goes back to yield reserve
            require(address(this).balance >= withdrawAmount, "Insufficient AVAX balance");
            payable(msg.sender).transfer(withdrawAmount);
        } else {
            totalUSDCBondsValue -= bond.principalAmount;
            usdcYieldReserve += penaltyAmount; // Penalty goes back to yield reserve
            require(USDC.transfer(msg.sender, withdrawAmount), "USDC transfer failed");
        }
    }

    // =========================================================================
    // IMPACT METRICS & ESG REPORTING - ENHANCED
    // =========================================================================

    /**
     * @dev Get comprehensive impact metrics for both AVAX and USDC
     */
    function getImpactMetrics()
        external
        view
        returns (
            uint256 totalBonds,
            uint256 totalAVAXValue,
            uint256 totalUSDCValue,
            uint256 totalAVAXYield,
            uint256 totalUSDCYield,
            uint256 totalAVAXRelief,
            uint256 totalUSDCRelief,
            uint256 disastersHelped,
            uint256 avgResponseTimeSec,
            uint256 currentAPYBasisPoints,
            uint256 activeBondCount
        )
    {
        return (
            nextBondId - 1,
            totalAVAXBondsValue,
            totalUSDCBondsValue,
            totalAVAXYieldEarned,
            totalUSDCYieldEarned,
            totalAVAXReliefDistributed,
            totalUSDCReliefDistributed,
            disasterCount,
            averageResponseTime,
            currentAPY,
            _getActiveBondCount()
        );
    }

    /**
     * @dev Get current pool balances
     */
    function getPoolBalances()
        external
        view
        returns (uint256 avaxBalance, uint256 usdcBalance, uint256 avaxYield, uint256 usdcYield)
    {
        return (
            address(this).balance, USDC.balanceOf(address(this)), avaxYieldReserve, usdcYieldReserve
        );
    }

    /**
     * @dev Get detailed bond information for donor (enhanced with token type)
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
            bool[] memory activeStatus,
            TokenType[] memory tokenTypes
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
        tokenTypes = new TokenType[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 bondId = bonds_list[i];
            ReliefBond memory bond = bonds[bondId];

            bondIds[i] = bondId;
            principalAmounts[i] = bond.principalAmount;
            currentValues[i] = bond.currentValue;
            yieldEarned[i] = bond.yieldEarned;
            maturityTimes[i] = bond.maturityTime;
            activeStatus[i] = bond.activeForRelief;
            tokenTypes[i] = bond.tokenType;
        }
    }

    // =========================================================================
    // ADMIN FUNCTIONS (SAME AS V2 + TOKEN CONVERSION)
    // =========================================================================

    /**
     * @dev Update AVAX to USDC conversion rate (for display purposes)
     */
    function updateAVAXToUSDCRate(uint256 newRate) external onlyAdmin {
        avaxToUsdcRate = newRate;
    }

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
    // INTERNAL FUNCTIONS - ENHANCED FOR BOTH TOKENS
    // =========================================================================

    function _executeAVAXPayout(
        bytes32, /* eventId */
        address beneficiary,
        uint256 amount,
        PaymentMethod method
    ) internal {
        require(address(this).balance >= amount, "Insufficient AVAX balance");

        if (method == PaymentMethod.CRYPTO) {
            // Direct AVAX transfer
            payable(beneficiary).transfer(amount);
        } else {
            // For other methods, transfer to custodial contract
            payable(beneficiary).transfer(amount);
        }
    }

    function _executeUSDCPayout(
        bytes32, /* eventId */
        address beneficiary,
        uint256 amount,
        PaymentMethod method
    ) internal {
        if (method == PaymentMethod.CRYPTO) {
            // Direct USDC transfer
            require(USDC.transfer(beneficiary, amount), "USDC transfer failed");
        } else {
            // For other methods, transfer to custodial contract
            require(USDC.transfer(beneficiary, amount), "USDC payout transfer failed");
        }
    }

    function _updateAVAXBondValuesAfterPayout(uint256 totalPayout) internal {
        if (totalAVAXBondsValue > 0) {
            uint256 reductionRatio = (totalPayout * 1e18) / totalAVAXBondsValue;

            for (uint256 i = 1; i < nextBondId; i++) {
                if (bonds[i].activeForRelief && bonds[i].tokenType == TokenType.AVAX) {
                    uint256 reduction = (bonds[i].currentValue * reductionRatio) / 1e18;
                    bonds[i].currentValue -= reduction;
                }
            }

            totalAVAXBondsValue -= totalPayout;
        }
    }

    function _updateUSDCBondValuesAfterPayout(uint256 totalPayout) internal {
        if (totalUSDCBondsValue > 0) {
            uint256 reductionRatio = (totalPayout * 1e18) / totalUSDCBondsValue;

            for (uint256 i = 1; i < nextBondId; i++) {
                if (bonds[i].activeForRelief && bonds[i].tokenType == TokenType.USDC) {
                    uint256 reduction = (bonds[i].currentValue * reductionRatio) / 1e18;
                    bonds[i].currentValue -= reduction;
                }
            }

            totalUSDCBondsValue -= totalPayout;
        }
    }

    function _distributeAVAXYieldToBonds(uint256 totalYield) internal {
        if (totalAVAXBondsValue > 0) {
            for (uint256 i = 1; i < nextBondId; i++) {
                if (bonds[i].activeForRelief && bonds[i].tokenType == TokenType.AVAX) {
                    uint256 bondShare =
                        (bonds[i].principalAmount * totalYield) / totalAVAXBondsValue;
                    bonds[i].currentValue += bondShare;
                    bonds[i].yieldEarned += bondShare;
                }
            }
        }
    }

    function _distributeUSDCYieldToBonds(uint256 totalYield) internal {
        if (totalUSDCBondsValue > 0) {
            for (uint256 i = 1; i < nextBondId; i++) {
                if (bonds[i].activeForRelief && bonds[i].tokenType == TokenType.USDC) {
                    uint256 bondShare =
                        (bonds[i].principalAmount * totalYield) / totalUSDCBondsValue;
                    bonds[i].currentValue += bondShare;
                    bonds[i].yieldEarned += bondShare;
                }
            }
        }
    }

    function _prepareEmergencyFunds(uint256 requiredAmount) internal view {
        // Check both AVAX and USDC balances for emergency preparedness
        uint256 avaxBalance = address(this).balance;
        uint256 usdcBalance = USDC.balanceOf(address(this));

        // Convert AVAX to USDC equivalent for comparison
        uint256 avaxInUSDC = (avaxBalance * avaxToUsdcRate) / 100;
        uint256 totalLiquidity = avaxInUSDC + usdcBalance;

        require(totalLiquidity >= requiredAmount, "Insufficient emergency funds");
    }

    function _updateAPY() internal {
        // Update APY based on market conditions and pool performance
        uint256 totalValueInUSDC =
            totalUSDCBondsValue + ((totalAVAXBondsValue * avaxToUsdcRate) / 100);

        if (totalValueInUSDC > 1000000 * 1e6) {
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

    // =========================================================================
    // EMERGENCY FUNCTIONS
    // =========================================================================

    /**
     * @dev Emergency withdraw function for admin (use carefully)
     */
    function emergencyWithdrawAll() external onlyAdmin {
        // Only for emergencies - withdraw all funds to admin
        uint256 avaxBalance = address(this).balance;
        uint256 usdcBalance = USDC.balanceOf(address(this));

        if (avaxBalance > 0) {
            payable(admin).transfer(avaxBalance);
        }

        if (usdcBalance > 0) {
            USDC.transfer(admin, usdcBalance);
        }
    }

    // Receive function to accept AVAX
    receive() external payable {
        // Allow contract to receive AVAX directly
        // This enables direct AVAX donations
        if (msg.value > 0) {
            avaxYieldReserve += msg.value;
            emit AVAXYieldGenerated(msg.value, currentAPY, totalAVAXYieldEarned);
        }
    }

    // Fallback function
    fallback() external payable {
        // Fallback to receive function
        if (msg.value > 0) {
            avaxYieldReserve += msg.value;
        }
    }
}
