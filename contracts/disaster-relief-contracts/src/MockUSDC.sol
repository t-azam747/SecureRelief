// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing disaster relief system on Avalanche Fuji
 * @notice This is for testnet only - production should use real USDC
 */
contract MockUSDC {
    string public constant name = "Mock USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "MockUSDC: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;

        // Mint initial supply for testing (1 million USDC)
        uint256 initialSupply = 1_000_000 * 10 ** decimals;
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    /**
     * @dev Transfer tokens to a specified address
     * @param to The address to transfer to
     * @param value The amount to be transferred
     */
    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0), "MockUSDC: transfer to zero address");
        require(balanceOf[msg.sender] >= value, "MockUSDC: insufficient balance");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(to != address(0), "MockUSDC: transfer to zero address");
        require(from != address(0), "MockUSDC: transfer from zero address");
        require(balanceOf[from] >= value, "MockUSDC: insufficient balance");
        require(allowance[from][msg.sender] >= value, "MockUSDC: insufficient allowance");

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens
     * @param spender The address which will spend the funds
     * @param value The amount of tokens to be spent
     */
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Mint new tokens (for testing purposes)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "MockUSDC: mint to zero address");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }

    /**
     * @dev Mint tokens to multiple addresses (for testing setup)
     */
    function mintBatch(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
    {
        require(recipients.length == amounts.length, "MockUSDC: arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "MockUSDC: mint to zero address");

            totalSupply += amounts[i];
            balanceOf[recipients[i]] += amounts[i];

            emit Transfer(address(0), recipients[i], amounts[i]);
            emit Mint(recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Faucet function - anyone can get 1000 USDC for testing
     */
    function faucet() external {
        uint256 faucetAmount = 1000 * 10 ** decimals; // 1000 USDC
        require(balanceOf[msg.sender] < faucetAmount, "MockUSDC: already has enough tokens");

        totalSupply += faucetAmount;
        balanceOf[msg.sender] += faucetAmount;

        emit Transfer(address(0), msg.sender, faucetAmount);
        emit Mint(msg.sender, faucetAmount);
    }

    /**
     * @dev Get USDC for specific testing scenarios
     */
    function getUSDCForTesting(uint256 amount) external {
        require(amount <= 100_000 * 10 ** decimals, "MockUSDC: amount too large for testing");

        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        emit Transfer(address(0), msg.sender, amount);
        emit Mint(msg.sender, amount);
    }

    /**
     * @dev Emergency function to reset balances for testing
     */
    function resetBalance(address account) external onlyOwner {
        balanceOf[account] = 0;
    }

    /**
     * @dev Set allowance for testing purposes
     */
    function setAllowanceForTesting(address tokenOwner, address spender, uint256 amount)
        external
        onlyOwner
    {
        allowance[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }
}
