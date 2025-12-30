import React from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { 
  X,
  Mountain,
  Settings,
  HelpCircle
} from 'lucide-react'
import { useAuth } from '../../contexts/AuthContext'
import RoleBasedNavigation from '../Navigation/RoleBasedNavigation'

const Sidebar = ({ onClose }) => {
  const { isAuthenticated, user } = useAuth()

  const bottomNavigation = [
    {
      name: 'Settings',
      href: '/settings',
      icon: Settings
    },
    {
      name: 'Help & Support',
      href: '/help',
      icon: HelpCircle
    }
  ]

  return (
    <div className="flex flex-col h-full bg-white border-r border-gray-200">
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-gray-200 lg:border-b-0">
        <Link to="/" className="flex items-center" onClick={onClose}>
          <span className="ml-2 text-lg font-bold text-gray-900">
                  Relief Network
          </span>
        </Link>
        
        {/* Close button for mobile */}
        {onClose && (
          <button
            onClick={onClose}
            className="p-2 text-gray-500 rounded-md lg:hidden hover:text-gray-900 hover:bg-gray-100"
          >
            <X className="w-6 h-6" />
          </button>
        )}
      </div>

      {/* Role-based Navigation */}
      <div className="flex-1 px-4 py-6 overflow-y-auto">
        <RoleBasedNavigation isMobile={false} />
      </div>

      {/* Bottom Navigation */}
      <div className="px-4 py-4 space-y-2 border-t border-gray-200">
        {bottomNavigation.map((item) => {
          const Icon = item.icon
          
          return (
            <motion.div
              key={item.name}
              whileHover={{ x: 4 }}
              whileTap={{ scale: 0.98 }}
            >
              <Link
                to={item.href}
                onClick={onClose}
                className="flex items-center p-2 text-gray-700 transition-all duration-200 rounded-lg group hover:bg-gray-50 hover:text-gray-900"
              >
                <Icon className="flex-shrink-0 w-5 h-5 mr-3 text-gray-400 group-hover:text-gray-500" />
                <span className="text-sm font-medium">
                  {item.name}
                </span>
              </Link>
            </motion.div>
          )
        })}
      </div>

      {/* Version Info */}
      <div className="px-4 py-2 border-t border-gray-200">
        <p className="text-xs text-center text-gray-500">
          v1.0.0 - Avalanche Testnet
        </p>
      </div>
    </div>
  )
}

export default Sidebar