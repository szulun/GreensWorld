import express from "express";
import connectDB from "./connection/config.js";
import apiRouter from "./routes/api/index.js";
import { fileURLToPath } from "url";
import path from "path";
import dotenv from 'dotenv';

// Load environment variables first
dotenv.config();

// Enhanced API key debugging
console.log("🔍 Environment Debug Info:");
console.log("- NODE_ENV:", process.env.NODE_ENV);
console.log("- API Key exists:", !!process.env.GOOGLE_AI_API_KEY);
console.log("- API Key length:", process.env.GOOGLE_AI_API_KEY?.length || 0);
console.log("- API Key first 10 chars:", process.env.GOOGLE_AI_API_KEY?.substring(0, 10) || 'N/A');
console.log("- API Key last 4 chars:", process.env.GOOGLE_AI_API_KEY?.slice(-4) || 'N/A');

// Validate API key format
if (process.env.GOOGLE_AI_API_KEY) {
  const apiKey = process.env.GOOGLE_AI_API_KEY;
  if (!apiKey.startsWith('AIza')) {
    console.warn("⚠️  API Key doesn't start with 'AIza' - this might be incorrect");
  }
  if (apiKey.length < 30) {
    console.warn("⚠️  API Key seems too short (expected 39+ characters)");
  }
  if (apiKey.includes(' ') || apiKey.includes('\n') || apiKey.includes('\t')) {
    console.warn("⚠️  API Key contains whitespace characters");
  }
} else {
  console.error("❌ GOOGLE_AI_API_KEY is not set!");
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(express.json({ limit: '10mb' })); // Increase limit for base64 images
app.use(express.urlencoded({ extended: false, limit: '10mb' }));

// Enhanced CORS middleware
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  
  // Log API requests for debugging
  if (req.path.includes('/api/ai')) {
    console.log(`🤖 AI API Request: ${req.method} ${req.path}`);
  }
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Add a test endpoint to verify API key
app.get('/api/test-ai', async (req, res) => {
  try {
    const { GoogleGenerativeAI } = await import('@google/generative-ai');
    
    if (!process.env.GOOGLE_AI_API_KEY) {
      return res.status(500).json({ 
        error: 'API key not configured',
        hasKey: false 
      });
    }

    const genAI = new GoogleGenerativeAI(process.env.GOOGLE_AI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
    
    const result = await model.generateContent("Say hello");
    const text = result.response.text();
    
    res.json({ 
      success: true, 
      message: 'AI API is working',
      response: text,
      hasKey: true,
      keyLength: process.env.GOOGLE_AI_API_KEY.length
    });
  } catch (error) {
    console.error('❌ AI Test Error:', error);
    res.status(500).json({ 
      error: error.message,
      hasKey: !!process.env.GOOGLE_AI_API_KEY,
      keyLength: process.env.GOOGLE_AI_API_KEY?.length || 0
    });
  }
});

// Routes
app.use('/api', apiRouter);

// Serve React app in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../frontend/flutter_frontend/web')));
 
  app.use((req, res) => {
    res.sendFile(path.join(__dirname, '../frontend/flutter_frontend/web/index.html'));
  });
}

// Start server
const startServer = async () => {
    try {
        await connectDB();
        
        app.listen(PORT, () => {
            console.log(`🚀 Server running on port ${PORT}`);
            console.log(`📱 API available at http://localhost:${PORT}/api`);
            console.log(`🧪 Test AI endpoint: http://localhost:${PORT}/api/test-ai`);
        });
    } catch (error) {
        console.error('❌ Failed to start server:', error);
        process.exit(1);
    }
};

startServer();