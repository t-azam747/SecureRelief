import React from 'react';
import { motion } from 'framer-motion';

const Card = ({ 
  children, 
  className = '', 
  hover = false,
  onClick,
  ...props 
}) => {
  const baseClasses = "bg-white rounded-lg shadow-sm border border-gray-200";
  const hoverClasses = hover ? "hover:shadow-md transition-shadow duration-200" : "";
  const clickableClasses = onClick ? "cursor-pointer" : "";
  
  const combinedClasses = `${baseClasses} ${hoverClasses} ${clickableClasses} ${className}`;

  if (onClick) {
    return (
      <motion.div
        whileHover={hover ? { y: -2 } : {}}
        whileTap={{ scale: 0.98 }}
        className={combinedClasses}
        onClick={onClick}
        {...props}
      >
        {children}
      </motion.div>
    );
  }

  return (
    <div className={combinedClasses} {...props}>
      {children}
    </div>
  );
};

export { Card };
export default Card;
