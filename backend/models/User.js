// Firebase User Model - No schema needed for Firestore
// This file serves as a reference for user data structure

export const userDataStructure = {
  username: { type: 'string', required: true },
  email: { type: 'string', required: true, unique: true },
  password: { type: 'string', required: true, minlength: 8 },
  createdAt: { type: 'timestamp', default: 'serverTimestamp' },
  updatedAt: { type: 'timestamp', default: 'serverTimestamp' },
  // Add any additional fields you need
  profilePicture: { type: 'string', required: false },
  bio: { type: 'string', required: false },
  plants: { type: 'array', default: [] } // Array of plant IDs
};

// Helper function to validate user data
export const validateUserData = (userData) => {
  const errors = [];
  
  if (!userData.username || userData.username.trim().length < 2) {
    errors.push('Username must be at least 2 characters long');
  }
  
  if (!userData.email || !userData.email.includes('@')) {
    errors.push('Valid email is required');
  }
  
  if (!userData.password || userData.password.length < 8) {
    errors.push('Password must be at least 8 characters long');
  }
  
  return errors;
};

// Helper function to sanitize user data for storage
export const sanitizeUserData = (userData) => {
  return {
    username: userData.username.trim(),
    email: userData.email.toLowerCase().trim(),
    password: userData.password, // Note: Should be hashed before storage
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
};