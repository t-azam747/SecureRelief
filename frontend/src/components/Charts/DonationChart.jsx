import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { DollarSign, TrendingUp, Calendar, BarChart3 } from 'lucide-react';

const DonationChart = ({ timeRange = '7d' }) => {
  const [chartData, setChartData] = useState([]);
  const [totalDonations, setTotalDonations] = useState(0);
  const [percentageChange, setPercentageChange] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    generateChartData();
  }, [timeRange]);

  const generateChartData = () => {
    setLoading(true);
    
    // Generate mock data based on time range
    const days = timeRange === '7d' ? 7 : timeRange === '30d' ? 30 : 90;
    const data = [];
    let total = 0;
    
    for (let i = days - 1; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      
      const baseAmount = Math.random() * 50000 + 10000;
      const amount = Math.floor(baseAmount);
      total += amount;
      
      data.push({
        date: date.toISOString().split('T')[0],
        amount,
        label: date.toLocaleDateString('en-US', { 
          month: 'short', 
          day: 'numeric' 
        })
      });
    }
    
    setChartData(data);
    setTotalDonations(total);
    setPercentageChange((Math.random() * 30 - 10)); // Random percentage change
    setLoading(false);
  };

  const maxAmount = Math.max(...chartData.map(d => d.amount));
  const minAmount = Math.min(...chartData.map(d => d.amount));

  const getBarHeight = (amount) => {
    const height = ((amount - minAmount) / (maxAmount - minAmount)) * 200 + 20;
    return `${height}px`;
  };

  const formatCurrency = (amount) => {
    if (amount >= 1000000) return `$${(amount / 1000000).toFixed(1)}M`;
    if (amount >= 1000) return `$${(amount / 1000).toFixed(1)}K`;
    return `$${amount.toLocaleString()}`;
  };

  const TimeRangeButton = ({ range, label, active, onClick }) => (
    <button
      onClick={() => onClick(range)}
      className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
        active 
          ? 'bg-avalanche-500 text-white shadow-md' 
          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
      }`}
    >
      {label}
    </button>
  );

  if (loading) {
    return (
      <div className="bg-white rounded-xl shadow-lg border border-gray-200 p-6">
        <div className="animate-pulse">
          <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
          <div className="h-64 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6 }}
      className="bg-white rounded-xl shadow-lg border border-gray-200 p-6"
    >
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between mb-6">
        <div className="mb-4 lg:mb-0">
          <div className="flex items-center mb-2">
            <div className="p-2 bg-green-100 rounded-lg mr-3">
              <DollarSign className="h-5 w-5 text-green-600" />
            </div>
            <h3 className="text-lg font-semibold text-gray-900">Donation Analytics</h3>
          </div>
          <div className="flex items-center space-x-4">
            <div className="text-2xl font-bold text-gray-900">
              {formatCurrency(totalDonations)}
            </div>
            <div className={`flex items-center text-sm font-medium ${
              percentageChange >= 0 ? 'text-green-600' : 'text-red-600'
            }`}>
              <TrendingUp className={`h-4 w-4 mr-1 ${
                percentageChange < 0 ? 'transform rotate-180' : ''
              }`} />
              {Math.abs(percentageChange).toFixed(1)}%
            </div>
          </div>
          <p className="text-sm text-gray-600 mt-1">
            Total donations in the last {timeRange === '7d' ? '7 days' : timeRange === '30d' ? '30 days' : '90 days'}
          </p>
        </div>

        {/* Time Range Selector */}
        <div className="flex space-x-2">
          <TimeRangeButton
            range="7d"
            label="7D"
            active={timeRange === '7d'}
            onClick={generateChartData}
          />
          <TimeRangeButton
            range="30d"
            label="30D"
            active={timeRange === '30d'}
            onClick={generateChartData}
          />
          <TimeRangeButton
            range="90d"
            label="90D"
            active={timeRange === '90d'}
            onClick={generateChartData}
          />
        </div>
      </div>

      {/* Chart */}
      <div className="relative">
        {/* Y-axis labels */}
        <div className="absolute left-0 top-0 bottom-0 flex flex-col justify-between text-xs text-gray-500 w-16">
          <span>{formatCurrency(maxAmount)}</span>
          <span>{formatCurrency((maxAmount + minAmount) / 2)}</span>
          <span>{formatCurrency(minAmount)}</span>
        </div>

        {/* Chart area */}
        <div className="ml-20 mr-4">
          <div className="flex items-end justify-between h-64 border-b border-gray-200">
            {chartData.map((item, index) => (
              <div key={item.date} className="flex flex-col items-center group relative">
                {/* Bar */}
                <motion.div
                  initial={{ height: 0 }}
                  animate={{ height: getBarHeight(item.amount) }}
                  transition={{ duration: 0.8, delay: index * 0.1 }}
                  className="bg-gradient-to-t from-avalanche-500 to-avalanche-400 rounded-t-sm hover:from-avalanche-600 hover:to-avalanche-500 transition-colors duration-200 cursor-pointer"
                  style={{ 
                    width: '20px',
                    minHeight: '4px'
                  }}
                />
                
                {/* Tooltip */}
                <div className="absolute bottom-full mb-2 bg-gray-900 text-white text-xs rounded-lg px-3 py-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-10">
                  <div className="font-medium">{formatCurrency(item.amount)}</div>
                  <div className="text-gray-300">{item.label}</div>
                  <div className="absolute top-full left-1/2 transform -translate-x-1/2 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-900"></div>
                </div>
              </div>
            ))}
          </div>

          {/* X-axis labels */}
          <div className="flex justify-between mt-2 text-xs text-gray-500">
            {chartData.filter((_, index) => index % Math.ceil(chartData.length / 6) === 0).map((item) => (
              <span key={item.date}>{item.label}</span>
            ))}
          </div>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mt-6 pt-6 border-t border-gray-200">
        <div className="text-center">
          <div className="text-lg font-bold text-gray-900">
            {formatCurrency(Math.max(...chartData.map(d => d.amount)))}
          </div>
          <div className="text-xs text-gray-600">Peak Day</div>
        </div>
        <div className="text-center">
          <div className="text-lg font-bold text-gray-900">
            {formatCurrency(totalDonations / chartData.length)}
          </div>
          <div className="text-xs text-gray-600">Daily Average</div>
        </div>
        <div className="text-center">
          <div className="text-lg font-bold text-gray-900">
            {chartData.filter(d => d.amount > totalDonations / chartData.length).length}
          </div>
          <div className="text-xs text-gray-600">Above Average Days</div>
        </div>
        <div className="text-center">
          <div className="text-lg font-bold text-gray-900">
            +{Math.floor(Math.random() * 50 + 20)}%
          </div>
          <div className="text-xs text-gray-600">Growth Rate</div>
        </div>
      </div>
    </motion.div>
  );
};

export default DonationChart;
