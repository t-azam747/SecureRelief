/**
 * Contract Test Script
 * Tests the deployed DisasterReliefSystem contract on Avalanche Fuji
 */

import { ethers } from 'ethers'
import { DISASTER_RELIEF_ABI, MOCK_USDC_ABI, CONTRACT_ADDRESSES, CONTRACT_HELPERS } from '../contracts/index.js'

const RPC_URL = 'https://api.avax-test.network/ext/bc/C/rpc'
const PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' // Default Foundry test key

async function testContracts() {
  console.log('🔧 Testing Avalanche Disaster Relief Contracts...\n')

  try {
    // Setup provider and wallet
    const provider = new ethers.JsonRpcProvider(RPC_URL)
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider)
    console.log(`📝 Using wallet: ${wallet.address}`)

    // Connect to contracts
    const disasterReliefContract = new ethers.Contract(
      CONTRACT_ADDRESSES.DISASTER_RELIEF_SYSTEM,
      DISASTER_RELIEF_ABI,
      wallet
    )

    const usdcContract = new ethers.Contract(
      CONTRACT_ADDRESSES.MOCK_USDC,
      MOCK_USDC_ABI,
      wallet
    )

    console.log(`📜 DisasterReliefSystem: ${CONTRACT_ADDRESSES.DISASTER_RELIEF_SYSTEM}`)
    console.log(`💰 MockUSDC: ${CONTRACT_ADDRESSES.MOCK_USDC}\n`)

    // Check contract owner
    const owner = await disasterReliefContract.owner()
    console.log(`👤 Contract Owner: ${owner}`)
    console.log(`🔑 Connected Wallet: ${wallet.address}`)
    console.log(`✅ Is Owner: ${owner.toLowerCase() === wallet.address.toLowerCase()}\n`)

    // Check admin status
    const isAdmin = await disasterReliefContract.admins(wallet.address)
    console.log(`👑 Is Admin: ${isAdmin}\n`)

    // Check USDC balance
    const usdcBalance = await usdcContract.balanceOf(wallet.address)
    console.log(`💵 USDC Balance: ${ethers.formatUnits(usdcBalance, 6)} USDC\n`)

    // Check disaster zone counter
    const zoneCounter = await disasterReliefContract.disasterZoneCounter()
    console.log(`📊 Disaster Zones Created: ${zoneCounter}\n`)

    // If no zones exist, create a test zone
    if (zoneCounter === 0n) {
      console.log('🏗️  Creating test disaster zone...')
      
      // First, use faucet to get USDC if balance is low
      if (usdcBalance < ethers.parseUnits('1000', 6)) {
        console.log('💧 Getting USDC from faucet...')
        const faucetTx = await usdcContract.faucet()
        await faucetTx.wait()
        console.log('✅ USDC faucet successful!')
      }

      // Approve USDC spending
      const fundingAmount = ethers.parseUnits('5000', 6) // 5000 USDC
      console.log('📝 Approving USDC spending...')
      const approveTx = await usdcContract.approve(CONTRACT_ADDRESSES.DISASTER_RELIEF_SYSTEM, fundingAmount)
      await approveTx.wait()
      console.log('✅ USDC approval successful!')

      // Create disaster zone
      const coords = CONTRACT_HELPERS.formatCoordinates(40.7128, -74.0060) // New York
      const radiusMeters = 50000 // 50km
      
      console.log('🌍 Creating disaster zone in New York...')
      const createTx = await disasterReliefContract.createDisasterZone(
        'Test Hurricane Relief Zone',
        coords.latitude,
        coords.longitude,
        radiusMeters,
        fundingAmount
      )
      
      const receipt = await createTx.wait()
      console.log(`✅ Disaster zone created! TX: ${receipt.hash}`)

      // Extract zone ID from events
      const event = receipt.logs.find(log => {
        try {
          const parsed = disasterReliefContract.interface.parseLog(log)
          return parsed.name === 'DisasterZoneCreated'
        } catch {
          return false
        }
      })

      if (event) {
        const parsedEvent = disasterReliefContract.interface.parseLog(event)
        console.log(`🆔 Zone ID: ${parsedEvent.args.zoneId}`)
        console.log(`📍 Location: ${parsedEvent.args.latitude / 1e6}, ${parsedEvent.args.longitude / 1e6}`)
        console.log(`💰 Funding: ${ethers.formatUnits(parsedEvent.args.funding, 6)} USDC`)
      }
    }

    // Get latest disaster zone info
    const latestZoneCounter = await disasterReliefContract.disasterZoneCounter()
    if (latestZoneCounter > 0n) {
      console.log('\n📋 Latest disaster zone details:')
      const latestZoneId = latestZoneCounter - 1n
      const zoneInfo = await disasterReliefContract.getDisasterZone(latestZoneId)
      
      console.log(`🆔 Zone ID: ${zoneInfo.id}`)
      console.log(`📛 Name: ${zoneInfo.name}`)
      console.log(`📍 Location: ${Number(zoneInfo.latitude) / 1000000}, ${Number(zoneInfo.longitude) / 1000000}`)
      console.log(`📏 Radius: ${Number(zoneInfo.radius) / 1000} km`)
      console.log(`💰 Initial Funding: ${ethers.formatUnits(zoneInfo.initialFunding, 6)} USDC`)
      console.log(`💰 Current Funding: ${ethers.formatUnits(zoneInfo.currentFunding, 6)} USDC`)
      console.log(`💸 Total Spent: ${ethers.formatUnits(zoneInfo.totalSpent, 6)} USDC`)
      console.log(`🔴 Active: ${zoneInfo.active}`)
      console.log(`📅 Created: ${new Date(Number(zoneInfo.createdAt) * 1000).toLocaleString()}`)
      console.log(`👤 Created By: ${zoneInfo.createdBy}`)
    }

    console.log('\n✅ Contract test completed successfully!')

  } catch (error) {
    console.error('❌ Contract test failed:', error)
    process.exit(1)
  }
}

// Run the test
testContracts()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
