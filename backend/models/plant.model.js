import mongoose from 'mongoose';

const plantSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    unique: true
  },
  scientificName: {
    type: String,
    required: false
  },
  careTips: [{
    topic: String,
    description: String
  }],
  diagnosis: {
    type: String,
    required: false
  },
  recommendations: [{
    type: String
  }],
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Update the updatedAt field before saving
plantSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

export default mongoose.model('Plant', plantSchema); 