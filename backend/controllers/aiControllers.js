import { z } from 'zod';
import { GoogleGenerativeAI } from '@google/generative-ai';
import dotenv from "dotenv";
dotenv.config();

console.log("🔑 Loaded API Key:", process.env.GOOGLE_AI_API_KEY ? "Yes (length: " + process.env.GOOGLE_AI_API_KEY.length + ")" : "No");

// Fix: Pass API key directly as string, not as object
const genAI = new GoogleGenerativeAI(process.env.GOOGLE_AI_API_KEY);

const PlantKeywordSchema = z.object({
  keyword: z.string(),
});

const PlantPhotoSchema = z.object({
  base64Image: z.string(),
});

const respondWithError = (res, fallback) => {
  res.status(500).json(fallback);
};

// Text-based care tips
export const getCareTipsFromKeyword = async (req, res) => {
  const parsed = PlantKeywordSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error });

  const { keyword } = parsed.data;
  const prompt = `You are a professional botanist. You MUST respond ONLY with valid JSON format. Do not include any explanatory text, just the JSON.

Plant keyword: ${keyword}

Required JSON format:
{
  "plantName": "common name of the plant",
  "scientificName": "scientific name (genus species) in italics format",
  "careTips": [
    {"topic": "Watering", "description": "detailed watering instructions"},
    {"topic": "Sunlight", "description": "detailed sunlight requirements"},
    {"topic": "Soil", "description": "soil type and requirements"},
    {"topic": "Temperature", "description": "temperature preferences"},
    {"topic": "Fertilizing", "description": "fertilization schedule and type"}
  ]
}`;

  try {
    // Fix: Use consistent model name format
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
    const result = await model.generateContent(prompt);
    const text = result.response.text();
    
    console.log("Raw AI response:", text); // Debug logging
    
    // Clean the response text to remove markdown formatting if present
    let cleanText = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    
    // Remove any text before the first { and after the last }
    const firstBrace = cleanText.indexOf('{');
    const lastBrace = cleanText.lastIndexOf('}');
    
    if (firstBrace !== -1 && lastBrace !== -1) {
      cleanText = cleanText.substring(firstBrace, lastBrace + 1);
    }
    
    console.log("Cleaned text for parsing:", cleanText); // Debug logging
    
    const output = JSON.parse(cleanText);
    
    res.json(output);
  } catch (err) {
    console.error("Error in getCareTipsFromKeyword:", err);
    respondWithError(res, {
      careTips: [{ topic: '⚠️ Error', description: 'Unable to generate care tips' }],
      plantName: keyword,
    });
  }
};

// Image-based care tips
export const getCareTipsFromPhoto = async (req, res) => {
  const parsed = PlantPhotoSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error });

  let { base64Image } = parsed.data;

  try {
    // 🔍 Detect and extract MIME type if present
    let mimeType = 'image/jpeg'; // Default
    const matches = base64Image.match(/^data:(image\/\w+);base64,(.+)$/);

    if (matches) {
      mimeType = matches[1];        // e.g. image/png
      base64Image = matches[2];     // Strip prefix
    }

    console.log("📷 Detected MIME type:", mimeType);

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });

    const result = await model.generateContent([
      {
        text: `You are a professional botanist. First, identify the plant in the photo if possible. Then, provide a concise care guide for the plant. Format the response as a JSON object with "plantName", "scientificName", and a "careTips" array. Each care tip should include a "topic" and a "description".

Required JSON format:
{
  "plantName": "common name of the plant",
  "scientificName": "scientific name (genus species) in italics format",
  "careTips": [
    {"topic": "☀️ Sunlight", "description": "detailed sunlight requirements"},
    {"topic": "💧 Watering", "description": "detailed watering instructions"},
    {"topic": "🪴 Soil", "description": "soil type and requirements"},
    {"topic": "🌱 Fertilizing", "description": "fertilization schedule and type"},
    {"topic": "✂️ Pruning", "description": "pruning instructions"},
    {"topic": "🐛 Pest and Disease Control", "description": "pest and disease management"},
    {"topic": "❄️ Winter Protection", "description": "winter care tips"}
  ]
}

Keep each description short and beginner-friendly. Respond with only JSON.`
      },
      {
        inlineData: {
          mimeType,
          data: base64Image,
        },
      },
    ]);

    const rawText = result.response.text();
    let cleanText = rawText.replace(/```json\n?/g, '').replace(/```/g, '').trim();

    const firstBrace = cleanText.indexOf('{');
    const lastBrace = cleanText.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace !== -1) {
      cleanText = cleanText.substring(firstBrace, lastBrace + 1);
    }

    const output = JSON.parse(cleanText);

    res.json({
      plantName: output.plantName || 'Unknown Plant',
      scientificName: output.scientificName || 'Unknown',
      careTips: output.careTips || [],
    });
  } catch (err) {
    console.error("Error in getCareTipsFromPhoto:", err);
    respondWithError(res, {
      careTips: [
        {
          topic: '⚠️ Error',
          description: 'Unable to analyze the photo. Try again with a clearer image.',
        },
        {
          topic: '💡 Tip',
          description: 'Make sure the plant is centered, well-lit, and in focus.',
        },
      ],
      plantName: 'Unknown Plant',
    });
  }
};


// Image-based plant diagnosis
export const diagnosePlant = async (req, res) => {
  const { base64Image, description } = req.body;

  if (!base64Image && !description) {
    return res.status(400).json({ error: 'Provide either base64Image, description, or both.' });
  }

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });

    let mimeType = 'image/jpeg';
    let imageData = null;

    if (base64Image) {
      const matches = base64Image.match(/^data:(image\/\w+);base64,(.+)$/);
      if (matches) {
        mimeType = matches[1];
        imageData = matches[2];
      } else {
        imageData = base64Image;
      }
    }

    const promptText = `
You are a plant health expert. Based on the provided plant photo and/or description of symptoms, diagnose the issue. Output only valid JSON with the following format:

{
  "diagnosis": "brief summary of the issue",
  "recommendations": [
    "short actionable tip 1",
    "tip 2",
    ...
  ]
}

${description ? `Observed symptoms: "${description}"` : ""}
`;

    const parts = [{ text: promptText }];

    if (imageData) {
      parts.push({
        inlineData: {
          mimeType,
          data: imageData,
        },
      });
    }

    const result = await model.generateContent(parts);
    const text = result.response.text();
    const cleanText = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const output = JSON.parse(cleanText);

    res.json(output);
  } catch (err) {
    console.error("❌ Error in diagnosePlant:", err);
    respondWithError(res, {
      diagnosis: 'Unable to diagnose plant issue',
      recommendations: ['Ensure clear input (photo or description)'],
    });
  }
};

// General chat for Ask anything mode
export const generalChat = async (req, res) => {
  const GeneralChatSchema = z.object({
    message: z.string(),
    base64Image: z.string().optional(),
    mode: z.string().default('general_chat'),
    hasImage: z.boolean().default(false),
    hasText: z.boolean().default(true),
  });

  const parsed = GeneralChatSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error });

  const { message, base64Image, hasImage, hasText } = parsed.data;

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
    
    let prompt;
    let result;
    
    if (hasImage && base64Image) {
      // Handle image + text question
      let mimeType = 'image/jpeg'; // Default
      let cleanBase64 = base64Image;
      
      const matches = base64Image.match(/^data:(image\/\w+);base64,(.+)$/);
      if (matches) {
        mimeType = matches[1];
        cleanBase64 = matches[2];
      }

      prompt = `You are a helpful AI plant assistant. The user has asked: "${message}"

Please analyze the provided image and answer their question in a helpful, conversational way. Focus on plant-related information and gardening advice.

Respond in a natural, friendly tone with practical tips and information.`;

      result = await model.generateContent([
        {
          text: prompt,
        },
        {
          inlineData: {
            mimeType: mimeType,
            data: cleanBase64,
          },
        },
      ]);
    } else {
      // Handle text-only question
      prompt = `You are a helpful AI plant assistant. The user has asked: "${message}"

Please provide a helpful, conversational response about plants, gardening, or any related topic. Focus on practical advice and useful information.

Respond in a natural, friendly tone. If the question is not plant-related, you can still help with general knowledge, but try to relate it to plants or gardening when possible.`;

      result = await model.generateContent(prompt);
    }

    const text = result.response.text();
    
    // Return the AI response directly
    res.json({
      text: text,
      mode: 'general_chat',
      timestamp: new Date().toISOString(),
    });
    
  } catch (err) {
    console.error("Error in generalChat:", err);
    res.status(500).json({
      error: "Failed to generate response",
      message: err.message,
    });
  }
};
