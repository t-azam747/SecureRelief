import { create } from 'zustand'
import { ethers } from 'ethers'
import toast from 'react-hot-toast'
import { DisasterReliefContractService } from '../services/contractService.js'

// Avalanche network configuration
const AVALANCHE_CONFIG = {
  chainId: 43113, // Fuji testnet
  chainName: 'Avalanche Fuji Testnet',
  nativeCurrency: {
    name: 'AVAX',
    symbol: 'AVAX',
    decimals: 18,
  },
  rpcUrls: ['https://api.avax-test.network/ext/bc/C/rpc'],
  blockExplorerUrls: ['https://testnet.snowtrace.io/'],
}

export const useWeb3Store = create((set, get) => ({
  // Connection state
  isConnected: false,
  isConnecting: false,
  isInitialized: false,
  account: null,
  provider: null,
  signer: null,
  chainId: null,
  balance: '0',
  usdcBalance: '0',

  // Contract service
  contractService: null,

  // User role and permissions - enhanced for RBAC
  userRole: null, // 'admin', 'vendor', 'donor', 'victim', 'government', 'oracle', 'treasury'
  permissions: [],
  roleHierarchy: {
    admin: 10,
    government: 8,
    treasury: 7,
    oracle: 6,
    vendor: 5,
    victim: 4,
    donor: 3,
    guest: 1
  },

  // Contract data
  disasterZones: [],
  vendors: [],
  vouchers: [],

  // Initialize Web3 connection
  initialize: async () => {
    try {
      console.log('Initializing Web3 store...')
      
      if (typeof window.ethereum !== 'undefined') {
        console.log('Ethereum provider detected')
        const provider = new ethers.BrowserProvider(window.ethereum)
        
        // Check if already connected
        try {
          const accounts = await provider.send('eth_accounts', [])
          if (accounts.length > 0) {
            console.log('Found existing connection, attempting to reconnect...')
            await get().connectWallet()
          } else {
            console.log('No existing connection found')
          }
        } catch (error) {
          console.log('Error checking existing accounts:', error)
        }
        
        // Listen for account changes
        window.ethereum.on('accountsChanged', (accounts) => {
          console.log('Accounts changed:', accounts)
          if (accounts.length === 0) {
            console.log('All accounts disconnected')
            get().disconnect()
          } else {
            console.log('Account changed, reconnecting...')
            get().connectWallet()
          }
        })

        // Listen for chain changes
        window.ethereum.on('chainChanged', (chainId) => {
          console.log('Chain changed to:', chainId)
          window.location.reload()
        })
      } else {
        console.log('No Ethereum provider found')
      }
      
      set({ isInitialized: true })
      console.log('Web3 store initialized successfully')
    } catch (error) {
      console.error('Web3 initialization error:', error)
      toast.error('Failed to initialize Web3')
      set({ isInitialized: true })
    }
  },

  // Connect wallet
  connectWallet: async () => {
    const state = get()
    if (state.isConnecting) return

    set({ isConnecting: true })

    try {
      // Check for Web3 provider
      if (typeof window.ethereum === 'undefined') {
        toast.error('Please install MetaMask or another Web3 wallet')
        set({ isConnecting: false })
        return
      }

      console.log('Creating provider...')
      const provider = new ethers.BrowserProvider(window.ethereum)
      
      // Request account access
      console.log('Requesting accounts...')
      await provider.send('eth_requestAccounts', [])
      
      const signer = await provider.getSigner()
      const account = await signer.getAddress()
      console.log('Connected to account:', account)
      
      const network = await provider.getNetwork()
      console.log('Current network:', network.chainId.toString(), network.name)
      
      // Check if on correct network and switch if needed
      if (network.chainId !== BigInt(AVALANCHE_CONFIG.chainId)) {
        console.log('Wrong network detected, switching to Avalanche...')
        try {
          await get().switchToAvalanche()
          // Re-get network info after switch
          const newNetwork = await provider.getNetwork()
          console.log('Switched to network:', newNetwork.chainId.toString())
        } catch (switchError) {
          console.error('Failed to switch network:', switchError)
          toast.error('Please manually switch to Avalanche Fuji testnet in your wallet')
          set({ isConnecting: false })
          return
        }
      }

      // Get balance
      const balance = await provider.getBalance(account)
      const formattedBalance = ethers.formatEther(balance)

      // Initialize contract service with error handling
      let contractService = null
      let usdcBalance = '0'
      let userRole = 'donor' // Default role

      try {
        console.log('Initializing contract service...')
        contractService = new DisasterReliefContractService(provider, signer)
        // Setup tx lifecycle callbacks for global monitoring
        contractService.setTxCallbacks({
          onSubmitted: ({ hash, label }) => {
            console.log(`${label} submitted:`, hash)
          },
          onMined: async ({ hash, label }) => {
            console.log(`${label} confirmed:`, hash)
            // Auto-refresh balances and vouchers post tx
            try {
              await get().updateBalance()
              await get().refreshVouchers()
            } catch (e) {
              console.warn('Post-tx refresh failed:', e)
            }
          },
          onError: ({ error, label }) => {
            console.warn(`${label} error:`, error)
          }
        })
        await contractService.initialize()
        console.log('Contract service initialized successfully')

        // Get USDC balance
        usdcBalance = await contractService.getUSDCBalance(account)

        // Determine user role
        userRole = await get().determineUserRole(account, contractService)

        // Setup event listeners
        contractService.setupEventListeners({
          onDisasterZoneCreated: (data) => {
            console.log('Disaster zone created:', data)
            get().refreshDisasterZones()
          },
          onVoucherIssued: (data) => {
            console.log('Voucher issued:', data)
            get().refreshVouchers()
          },
          onVoucherRedeemed: (data) => {
            console.log('Voucher redeemed:', data)
            get().refreshVouchers()
            get().updateBalance()
          },
          onProofOfAidSubmitted: (data) => {
            console.log('Proof of aid submitted:', data)
          }
        })
      } catch (contractError) {
        console.warn('Contract initialization failed, continuing with limited functionality:', contractError)
        toast.warning('Contract connection failed. Some features may be limited.')
      }

      set({
        isConnected: true,
        isConnecting: false,
        account,
        provider,
        signer,
        chainId: Number(network.chainId),
        balance: formattedBalance,
        usdcBalance,
        userRole,
        contractService,
      })

      toast.success(`Connected as ${userRole}`)
      console.log('Wallet connection completed successfully')
    } catch (error) {
      console.error('Wallet connection error:', error)
      let errorMessage = 'Failed to connect wallet'
      
      if (error.code === 4001) {
        errorMessage = 'Connection rejected by user'
      } else if (error.code === -32002) {
        errorMessage = 'Connection request already pending'
      } else if (error.message.includes('User rejected')) {
        errorMessage = 'Connection rejected by user'
      }
      
      toast.error(errorMessage)
      set({ isConnecting: false })
    }
  },

  // Switch to Avalanche network
  switchToAvalanche: async () => {
    try {
      console.log('Attempting to switch to Avalanche Fuji testnet...')
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${AVALANCHE_CONFIG.chainId.toString(16)}` }],
      })
      console.log('Successfully switched to Avalanche Fuji')
    } catch (switchError) {
      console.error('Switch network error:', switchError)
      
      // If network doesn't exist, add it
      if (switchError.code === 4902) {
        console.log('Network not found, attempting to add Avalanche Fuji...')
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: `0x${AVALANCHE_CONFIG.chainId.toString(16)}`,
              chainName: AVALANCHE_CONFIG.chainName,
              nativeCurrency: AVALANCHE_CONFIG.nativeCurrency,
              rpcUrls: AVALANCHE_CONFIG.rpcUrls,
              blockExplorerUrls: AVALANCHE_CONFIG.blockExplorerUrls,
            }],
          })
          console.log('Successfully added Avalanche Fuji network')
        } catch (addError) {
          console.error('Failed to add Avalanche network:', addError)
          throw new Error('Failed to add Avalanche network. Please add it manually.')
        }
      } else if (switchError.code === 4001) {
        throw new Error('Network switch rejected by user')
      } else {
        throw new Error(`Failed to switch network: ${switchError.message}`)
      }
    }
  },

  // Determine user role based on contract state and permissions
  determineUserRole: async (account, contractService) => {
    try {
      if (!contractService || !contractService.disasterReliefContract) {
        return 'donor' // Default role if contract not available
      }

      const contract = contractService.disasterReliefContract
      const state = get()

      // Define role mappings and permissions
      const rolePermissions = {
        admin: [
          'manage:all',
          'view:all',
          'disaster:create',
          'disaster:update',
          'disaster:delete',
          'vendor:approve',
          'vendor:reject',
          'user:manage',
          'analytics:full',
          'system:configure'
        ],
        government: [
          'disaster:create',
          'disaster:update',
          'disaster:verify',
          'vendor:approve',
          'analytics:view',
          'reports:generate'
        ],
        treasury: [
          'funds:manage',
          'treasury:view',
          'treasury:allocate',
          'analytics:financial'
        ],
        oracle: [
          'data:verify',
          'price:update',
          'validation:perform'
        ],
        vendor: [
          'voucher:redeem',
          'inventory:manage',
          'transaction:process',
          'profile:update',
          'analytics:vendor'
        ],
        victim: [
          'voucher:claim',
          'aid:request',
          'profile:update',
          'donation:track'
        ],
        donor: [
          'donation:make',
          'impact:track',
          'profile:update',
          'analytics:donation'
        ]
      }

      // Check roles in order of hierarchy (highest to lowest)
      try {
        // Check for admin role
        const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes('ADMIN_ROLE'))
        const hasAdminRole = await contract.hasRole(ADMIN_ROLE, account)
        if (hasAdminRole) {
          set({ permissions: rolePermissions.admin })
          return 'admin'
        }
      } catch (error) {
        console.log('Admin role check failed:', error)
      }

      try {
        // Check for government role (if implemented)
        const GOVERNMENT_ROLE = ethers.keccak256(ethers.toUtf8Bytes('GOVERNMENT_ROLE'))
        const hasGovRole = await contract.hasRole(GOVERNMENT_ROLE, account)
        if (hasGovRole) {
          set({ permissions: rolePermissions.government })
          return 'government'
        }
      } catch (error) {
        console.log('Government role check failed:', error)
      }

      try {
        // Check for treasury role
        const TREASURY_ROLE = ethers.keccak256(ethers.toUtf8Bytes('TREASURY_MANAGER_ROLE'))
        const hasTreasuryRole = await contract.hasRole(TREASURY_ROLE, account)
        if (hasTreasuryRole) {
          set({ permissions: rolePermissions.treasury })
          return 'treasury'
        }
      } catch (error) {
        console.log('Treasury role check failed:', error)
      }

      try {
        // Check for oracle role
        const ORACLE_ROLE = ethers.keccak256(ethers.toUtf8Bytes('ORACLE_ROLE'))
        const hasOracleRole = await contract.hasRole(ORACLE_ROLE, account)
        if (hasOracleRole) {
          set({ permissions: rolePermissions.oracle })
          return 'oracle'
        }
      } catch (error) {
        console.log('Oracle role check failed:', error)
      }

      try {
        // Check if user is a registered vendor
        const vendor = await contractService.getVendor(account)
        if (vendor && vendor.address !== ethers.ZeroAddress) {
          set({ permissions: rolePermissions.vendor })
          return 'vendor'
        }
      } catch (error) {
        console.log('Vendor check failed:', error)
      }

      try {
        // Check if user has active vouchers (victim/beneficiary)
        const vouchers = await contractService.getUserVouchers(account)
        if (vouchers && vouchers.length > 0) {
          const activeVouchers = vouchers.filter(v => !v.used && v.expiryTime > new Date())
          if (activeVouchers.length > 0) {
            set({ permissions: rolePermissions.victim })
            return 'victim'
          }
        }
      } catch (error) {
        console.log('Voucher check failed:', error)
      }

      // Default to donor role with appropriate permissions
      set({ permissions: rolePermissions.donor })
      return 'donor'
    } catch (error) {
      console.error('Role determination error:', error)
      set({ permissions: rolePermissions.donor || [] })
      return 'donor'
    }
  },

  // Disconnect wallet
  disconnect: () => {
    const { contractService } = get()
    if (contractService) {
      contractService.removeEventListeners()
    }
    
    set({
      isConnected: false,
      account: null,
      provider: null,
      signer: null,
      chainId: null,
      balance: '0',
      usdcBalance: '0',
      userRole: null,
      permissions: [],
      contractService: null,
      disasterZones: [],
      vendors: [],
      vouchers: [],
    })
    toast.success('Wallet disconnected')
  },

  // Update balance
  updateBalance: async () => {
    const { provider, account, contractService } = get()
    if (!provider || !account) return

    try {
      const balance = await provider.getBalance(account)
      const formattedBalance = ethers.formatEther(balance)
      
      let usdcBalance = '0'
      if (contractService) {
        usdcBalance = await contractService.getUSDCBalance(account)
      }
      
      set({ balance: formattedBalance, usdcBalance })
    } catch (error) {
      console.error('Balance update error:', error)
    }
  },

  // Data refresh functions
  refreshDisasterZones: async () => {
    const { contractService } = get()
    if (!contractService) return

    try {
      const contract = contractService.disasterReliefContract
      const zones = []
      if (contract?.disasterZoneCounter) {
        try {
          const count = await contract.disasterZoneCounter()
          const total = Number(count)
          for (let i = 1; i <= total; i++) {
            try {
              const z = await contractService.getDisasterZone(i)
              zones.push(z)
            } catch (e) {
              // Skip missing/deleted zones
            }
          }
        } catch (e) {
          console.warn('Failed to enumerate disaster zones:', e)
        }
      }
      set({ disasterZones: zones })
    } catch (error) {
      console.error('Error refreshing disaster zones:', error)
    }
  },

  refreshVouchers: async () => {
    const { contractService, account } = get()
    if (!contractService || !account) return

    try {
      const vouchers = await contractService.getUserVouchers(account)
      set({ vouchers })
    } catch (error) {
      console.error('Error refreshing vouchers:', error)
    }
  },

  refreshVendors: async (zoneId) => {
    const { contractService } = get()
    if (!contractService) return

    try {
      if (zoneId) {
        const vendors = await contractService.getZoneVendors(zoneId)
        set({ vendors })
      }
    } catch (error) {
      console.error('Error refreshing vendors:', error)
    }
  },

  // Contract interaction helpers
  createDisasterZone: async (name, latitude, longitude, radiusKm, initialFundingUSDC) => {
    const { contractService } = get()
    if (!contractService) throw new Error('Contract service not available')

    return await contractService.createDisasterZone(name, latitude, longitude, radiusKm, initialFundingUSDC)
  },

  registerVendor: async (vendorAddress, name, location, zoneId, ipfsKycHash) => {
    const { contractService } = get()
    if (!contractService) throw new Error('Contract service not available')

    return await contractService.registerVendor(vendorAddress, name, location, zoneId, ipfsKycHash)
  },

  verifyVendor: async (vendorAddress, zoneId) => {
    const { contractService } = get()
    if (!contractService) throw new Error('Contract service not available')

    return await contractService.verifyVendor(vendorAddress, zoneId)
  },

  issueVoucher: async (beneficiaryAddress, amountUSDC, zoneId, categories, expiryDays = 30) => {
    const { contractService } = get()
    if (!contractService) throw new Error('Contract service not available')

    return await contractService.issueVoucher(beneficiaryAddress, amountUSDC, zoneId, categories, expiryDays)
  },

  redeemVoucher: async (voucherId, amountUSDC, category, ipfsHash) => {
    const { contractService } = get()
    if (!contractService) throw new Error('Contract service not available')

    return await contractService.redeemVoucher(voucherId, amountUSDC, category, ipfsHash)
  },

  useFaucet: async () => {
    const { contractService } = get()
    if (!contractService) throw new Error('Contract service not available')

    const result = await contractService.useFaucet()
    if (result.success) {
      await get().updateBalance()
    }
    return result
  },

  transferUSDC: async (to, amountUSDC) => {
    const { contractService } = get()
    if (!contractService) throw new Error('Contract service not available')

    const result = await contractService.transferUSDC(to, amountUSDC)
    if (result.success) {
      await get().updateBalance()
    }
    return result
  },
}))

// Initialize the store when the module loads
useWeb3Store.getState().initialize()
