// Plant Shop Model - Firestore data structure
// This file serves as a reference for plant shop data structure

export const plantShopDataStructure = {
  name: { type: 'string', required: true },
  address: { type: 'string', required: true },
  latitude: { type: 'number', required: true },
  longitude: { type: 'number', required: true },
  description: { type: 'string', required: false },
  phone: { type: 'string', required: false },
  email: { type: 'string', required: false },
  website: { type: 'string', required: false },
  hours: { type: 'object', required: false }, // { monday: "9-5", tuesday: "9-5", etc. }
  specialties: { type: 'array', required: false }, // ["indoor plants", "succulents", "trees"]
  rating: { type: 'number', required: false, min: 0, max: 5 },
  reviewCount: { type: 'number', required: false, default: 0 },
  images: { type: 'array', required: false }, // Array of image URLs
  isActive: { type: 'boolean', required: false, default: true },
  createdAt: { type: 'timestamp', default: 'serverTimestamp' },
  updatedAt: { type: 'timestamp', default: 'serverTimestamp' }
};

// Helper function to validate plant shop data
export const validatePlantShopData = (shopData) => {
  const errors = [];
  
  if (!shopData.name || shopData.name.trim().length < 2) {
    errors.push('Shop name must be at least 2 characters long');
  }
  
  if (!shopData.address || shopData.address.trim().length < 5) {
    errors.push('Address must be at least 5 characters long');
  }
  
  if (typeof shopData.latitude !== 'number' || shopData.latitude < -90 || shopData.latitude > 90) {
    errors.push('Latitude must be a valid number between -90 and 90');
  }
  
  if (typeof shopData.longitude !== 'number' || shopData.longitude < -180 || shopData.longitude > 180) {
    errors.push('Longitude must be a valid number between -180 and 180');
  }
  
  if (shopData.phone && !/^[\+]?[1-9][\d]{0,15}$/.test(shopData.phone.replace(/[\s\-\(\)]/g, ''))) {
    errors.push('Phone number must be a valid format');
  }
  
  if (shopData.email && !shopData.email.includes('@')) {
    errors.push('Email must be a valid format');
  }
  
  if (shopData.rating && (shopData.rating < 0 || shopData.rating > 5)) {
    errors.push('Rating must be between 0 and 5');
  }
  
  return errors;
};

// Helper function to sanitize plant shop data for storage
export const sanitizePlantShopData = (shopData) => {
  return {
    name: shopData.name.trim(),
    address: shopData.address.trim(),
    latitude: parseFloat(shopData.latitude),
    longitude: parseFloat(shopData.longitude),
    description: shopData.description?.trim() || '',
    phone: shopData.phone?.trim() || '',
    email: shopData.email?.toLowerCase().trim() || '',
    website: shopData.website?.trim() || '',
    hours: shopData.hours || {},
    specialties: shopData.specialties || [],
    rating: shopData.rating ? parseFloat(shopData.rating) : null,
    reviewCount: shopData.reviewCount ? parseInt(shopData.reviewCount) : 0,
    images: shopData.images || [],
    isActive: shopData.isActive !== undefined ? shopData.isActive : true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
};

// Helper function to calculate distance between two points
export const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Radius of the Earth in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}; 