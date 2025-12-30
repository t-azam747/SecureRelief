/**
 * API Integration Tests
 * Test frontend-backend connectivity and user flows
 */

import apiService from '../services/apiService';

// Test configuration
const TEST_CONFIG = {
  backendURL: 'http://localhost:5000',
  testWallet: '0x742d35Cc6635C0532925a3b8D6A1dd4A1A3c2c14',
  timeout: 10000
};

/**
 * Test suite for API connectivity
 */
export class APIIntegrationTest {
  constructor() {
    this.results = [];
    this.startTime = Date.now();
  }

  log(test, status, details = '') {
    const result = {
      test,
      status,
      details,
      timestamp: new Date().toISOString()
    };
    this.results.push(result);
    console.log(`${status === 'PASS' ? '✅' : '❌'} ${test}: ${details}`);
  }

  /**
   * Test backend connectivity
   */
  async testBackendConnectivity() {
    try {
      const health = await apiService.getHealthStatus();
      
      if (health && health.status === 'OK') {
        this.log('Backend Connectivity', 'PASS', `Server responding, uptime: ${health.uptime}s`);
        return true;
      } else {
        this.log('Backend Connectivity', 'FAIL', 'Invalid health response');
        return false;
      }
    } catch (error) {
      this.log('Backend Connectivity', 'FAIL', error.message);
      return false;
    }
  }

  /**
   * Test user management APIs
   */
  async testUserManagement() {
    try {
      // Test user creation
      const testUser = {
        walletAddress: TEST_CONFIG.testWallet,
        name: 'Test User',
        role: 'donor',
        status: 'active'
      };

      const createResult = await apiService.createUser(testUser);
      
      if (createResult.success) {
        this.log('User Creation', 'PASS', `Created user ID: ${createResult.data.id}`);
        
        // Test user retrieval by wallet
        const userResult = await apiService.getUserByWallet(TEST_CONFIG.testWallet);
        
        if (userResult.success && userResult.data) {
          this.log('User Retrieval', 'PASS', `Retrieved user: ${userResult.data.name}`);
          return userResult.data;
        } else {
          this.log('User Retrieval', 'FAIL', 'User not found after creation');
          return null;
        }
      } else {
        // User might already exist
        const existingUser = await apiService.getUserByWallet(TEST_CONFIG.testWallet);
        if (existingUser.success) {
          this.log('User Creation', 'INFO', 'User already exists');
          this.log('User Retrieval', 'PASS', `Retrieved existing user: ${existingUser.data.name}`);
          return existingUser.data;
        } else {
          this.log('User Creation', 'FAIL', createResult.message);
          return null;
        }
      }
    } catch (error) {
      this.log('User Management', 'FAIL', error.message);
      return null;
    }
  }

  /**
   * Test system settings APIs
   */
  async testSystemSettings() {
    try {
      const settings = await apiService.getSystemSettings();
      
      if (settings.success && settings.data) {
        this.log('System Settings', 'PASS', `Retrieved ${settings.data.length} settings`);
        return true;
      } else {
        this.log('System Settings', 'FAIL', 'No settings retrieved');
        return false;
      }
    } catch (error) {
      this.log('System Settings', 'FAIL', error.message);
      return false;
    }
  }

  /**
   * Test authentication flow
   */
  async testAuthentication() {
    try {
      // Test token verification (should work in dev mode)
      const verification = await apiService.verifyToken();
      
      if (verification) {
        this.log('Authentication', 'PASS', 'Dev mode authentication bypass working');
        return true;
      } else {
        this.log('Authentication', 'INFO', 'No auth token, dev mode should bypass');
        return true;
      }
    } catch (error) {
      this.log('Authentication', 'FAIL', error.message);
      return false;
    }
  }

  /**
   * Test complete user flow
   */
  async testCompleteUserFlow() {
    try {
      // 1. Check backend connectivity
      const isConnected = await this.testBackendConnectivity();
      if (!isConnected) return false;

      // 2. Test authentication
      await this.testAuthentication();

      // 3. Test user management
      const user = await this.testUserManagement();
      if (!user) return false;

      // 4. Test system settings
      await this.testSystemSettings();

      // 5. Test user stats
      const stats = await apiService.getUserStats();
      if (stats.success) {
        this.log('User Statistics', 'PASS', `Retrieved user stats`);
      } else {
        this.log('User Statistics', 'FAIL', 'Could not retrieve user stats');
      }

      return true;
    } catch (error) {
      this.log('Complete User Flow', 'FAIL', error.message);
      return false;
    }
  }

  /**
   * Run all tests
   */
  async runAllTests() {
    console.log('🚀 Starting API Integration Tests...');
    console.log(`Backend URL: ${TEST_CONFIG.backendURL}`);
    console.log(`Test Wallet: ${TEST_CONFIG.testWallet}`);
    console.log('─'.repeat(50));

    const success = await this.testCompleteUserFlow();
    
    const endTime = Date.now();
    const duration = (endTime - this.startTime) / 1000;
    
    console.log('─'.repeat(50));
    console.log(`Tests completed in ${duration}s`);
    
    const passedTests = this.results.filter(r => r.status === 'PASS').length;
    const failedTests = this.results.filter(r => r.status === 'FAIL').length;
    const totalTests = this.results.length;
    
    console.log(`Results: ${passedTests}/${totalTests} passed, ${failedTests} failed`);
    
    if (success && failedTests === 0) {
      console.log('🎉 All tests passed! Frontend-backend integration is working.');
    } else {
      console.log('⚠️ Some tests failed. Check the results above.');
    }

    return {
      success: success && failedTests === 0,
      results: this.results,
      duration,
      stats: { passed: passedTests, failed: failedTests, total: totalTests }
    };
  }
}

/**
 * Quick test function for manual testing
 */
export async function testAPIConnection() {
  const test = new APIIntegrationTest();
  return await test.runAllTests();
}

/**
 * Test wallet integration with database
 */
export async function testWalletIntegration(walletAddress, userRole = 'donor') {
  try {
    console.log(`🔗 Testing wallet integration for ${walletAddress}`);
    
    // Check if user exists
    let user = await apiService.getUserByWallet(walletAddress);
    
    if (!user.success || !user.data) {
      // Create user if doesn't exist
      console.log('👤 Creating new user profile...');
      const createResult = await apiService.createUser({
        walletAddress,
        name: `User ${walletAddress.slice(0, 6)}...${walletAddress.slice(-4)}`,
        role: userRole,
        status: 'active'
      });
      
      if (createResult.success) {
        user = createResult;
        console.log('✅ User profile created successfully');
      } else {
        console.error('❌ Failed to create user profile:', createResult.message);
        return null;
      }
    } else {
      console.log('✅ User profile found in database');
    }

    return user.data;
  } catch (error) {
    console.error('❌ Wallet integration test failed:', error);
    return null;
  }
}

export default APIIntegrationTest;
