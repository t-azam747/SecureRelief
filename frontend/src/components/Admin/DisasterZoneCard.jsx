import React, { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { 
  MapPin, 
  DollarSign, 
  Users, 
  Activity,
  TrendingUp,
  Calendar,
  Settings,
  Eye,
  Pause,
  Play,
  AlertTriangle,
  CheckCircle
} from 'lucide-react'
import Card from '../UI/Card'
import Button from '../UI/Button'
import { useContract } from '../../hooks/useContract'

const DisasterZoneCard = ({ zone, onEdit, onViewDetails }) => {
  const [stats, setStats] = useState({
    totalFunding: zone.funding || 0,
    currentFunding: zone.funding || 0,
    totalSpent: 0,
    vendorCount: 0,
    voucherCount: 0,
    beneficiariesHelped: 0
  })
  
  const [loading, setLoading] = useState(false)
  const { handleGetDisasterZoneStats } = useContract()

  useEffect(() => {
    const loadStats = async () => {
      if (zone.id) {
        setLoading(true)
        try {
          const zoneStats = await handleGetDisasterZoneStats(zone.id)
          if (zoneStats) {
            setStats({
              totalFunding: zoneStats.initialFunding || 0,
              currentFunding: zoneStats.currentFunding || 0,
              totalSpent: zoneStats.totalSpent || 0,
              vendorCount: zoneStats.vendorCount || 0,
              voucherCount: 0, // This would come from voucher queries
              beneficiariesHelped: 0 // This would be calculated
            })
          }
        } catch (error) {
          console.error('Error loading zone stats:', error)
        } finally {
          setLoading(false)
        }
      }
    }

    loadStats()
  }, [zone.id, handleGetDisasterZoneStats])

  const getStatusColor = (status) => {
    switch (status) {
      case 'active': return 'bg-green-100 text-green-800'
      case 'paused': return 'bg-yellow-100 text-yellow-800'
      case 'completed': return 'bg-blue-100 text-blue-800'
      case 'emergency': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(amount)
  }

  const fundingPercentage = stats.totalFunding > 0 
    ? ((stats.totalFunding - stats.currentFunding) / stats.totalFunding) * 100 
    : 0

  return (
    <Card hover className="overflow-hidden">
      <div className="p-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-4">
          <div className="flex-1">
            <div className="flex items-center space-x-3 mb-2">
              <h3 className="text-lg font-semibold text-gray-900 truncate">
                {zone.name}
              </h3>
              <span className={`px-2 py-1 text-xs font-medium rounded-full ${getStatusColor(zone.status)}`}>
                {zone.status}
              </span>
            </div>
            
            <div className="flex items-center text-sm text-gray-500 mb-1">
              <MapPin className="w-4 h-4 mr-1" />
              <span>{zone.location || `${zone.latitude?.toFixed(4)}, ${zone.longitude?.toFixed(4)}`}</span>
            </div>
            
            <div className="flex items-center text-sm text-gray-500">
              <Calendar className="w-4 h-4 mr-1" />
              <span>Created {zone.createdAt?.toLocaleDateString()}</span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {zone.urgencyLevel === 'emergency' && (
              <AlertTriangle className="w-5 h-5 text-red-500" />
            )}
            {zone.status === 'active' && (
              <CheckCircle className="w-5 h-5 text-green-500" />
            )}
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div className="bg-gray-50 rounded-lg p-3">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Total Funding</p>
                <p className="text-lg font-semibold text-gray-900">
                  {formatCurrency(stats.totalFunding)}
                </p>
              </div>
              <DollarSign className="w-5 h-5 text-gray-400" />
            </div>
          </div>

          <div className="bg-gray-50 rounded-lg p-3">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Available</p>
                <p className="text-lg font-semibold text-gray-900">
                  {formatCurrency(stats.currentFunding)}
                </p>
              </div>
              <TrendingUp className="w-5 h-5 text-gray-400" />
            </div>
          </div>

          <div className="bg-gray-50 rounded-lg p-3">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Vendors</p>
                <p className="text-lg font-semibold text-gray-900">{stats.vendorCount}</p>
              </div>
              <Users className="w-5 h-5 text-gray-400" />
            </div>
          </div>

          <div className="bg-gray-50 rounded-lg p-3">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Activity</p>
                <p className="text-lg font-semibold text-gray-900">{stats.voucherCount}</p>
              </div>
              <Activity className="w-5 h-5 text-gray-400" />
            </div>
          </div>
        </div>

        {/* Funding Progress Bar */}
        <div className="mb-4">
          <div className="flex items-center justify-between text-sm mb-2">
            <span className="text-gray-600">Funding Utilization</span>
            <span className="font-medium">{fundingPercentage.toFixed(1)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${fundingPercentage}%` }}
              transition={{ duration: 1, ease: "easeOut" }}
              className="bg-avalanche-500 h-2 rounded-full"
            />
          </div>
        </div>

        {/* Description */}
        {zone.description && (
          <p className="text-sm text-gray-600 mb-4 line-clamp-2">
            {zone.description}
          </p>
        )}

        {/* Action Buttons */}
        <div className="flex space-x-2">
          <Button 
            variant="outline" 
            size="sm" 
            icon={Eye}
            onClick={() => onViewDetails?.(zone)}
            className="flex-1"
          >
            View Details
          </Button>
          
          <Button 
            variant="outline" 
            size="sm" 
            icon={Settings}
            onClick={() => onEdit?.(zone)}
          >
            Manage
          </Button>
          
          {zone.status === 'active' ? (
            <Button variant="outline" size="sm" icon={Pause}>
              Pause
            </Button>
          ) : (
            <Button variant="outline" size="sm" icon={Play}>
              Activate
            </Button>
          )}
        </div>

        {/* Loading Overlay */}
        {loading && (
          <div className="absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center">
            <div className="w-6 h-6 border-2 border-avalanche-500 border-t-transparent rounded-full animate-spin" />
          </div>
        )}
      </div>
    </Card>
  )
}

export default DisasterZoneCard
