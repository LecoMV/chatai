const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const winston = require('winston');
const OpenAI = require('openai');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3001;

// Logging setup
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'chatai-coastalweb' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({ format: winston.format.simple() })
  ],
});

// Create logs directory if it doesn't exist
const fs = require('fs');
if (!fs.existsSync('logs')) {
  fs.mkdirSync('logs');
}

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Security middleware
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : [
    'https://chatai.coastalweb.us',
    'https://www.chatai.coastalweb.us',
    'http://localhost:3000',
    'http://localhost:8080'
  ],
  credentials: true,
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW) || 60000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 50,
  message: { error: 'Too many requests from this IP, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.path === '/health'
});

app.use('/api/', limiter);

// Request logging
app.use((req, res, next) => {
  logger.info({
    method: req.method,
    url: req.url,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    service: 'ChatAI CoastalWeb',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    domain: 'chatai.coastalweb.us'
  });
});

// Chat endpoint
app.post('/api/chat', async (req, res) => {
  const startTime = Date.now();
  
  try {
    const { message, conversationHistory, settings } = req.body;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'Message is required' });
    }

    if (!Array.isArray(conversationHistory)) {
      return res.status(400).json({ error: 'Conversation history must be an array' });
    }

    const safeSettings = {
      model: settings?.model || 'gpt-3.5-turbo',
      temperature: Math.min(Math.max(settings?.temperature || 0.7, 0), 2),
      maxTokens: Math.min(settings?.maxTokens || 500, 1000)
    };

    const systemMessage = {
      role: 'system',
      content: `You are a helpful AI assistant for CoastalWeb's ChatAI service. Be friendly, professional, and concise.`
    };

    const completion = await openai.chat.completions.create({
      model: safeSettings.model,
      messages: [systemMessage, ...conversationHistory],
      temperature: safeSettings.temperature,
      max_tokens: safeSettings.maxTokens
    });

    const responseTime = Date.now() - startTime;

    res.json({ 
      message: completion.choices[0].message.content,
      usage: completion.usage,
      model: safeSettings.model,
      responseTime: responseTime,
      service: 'ChatAI CoastalWeb'
    });

  } catch (error) {
    logger.error({ error: error.message, code: error.code });
    
    if (error.code === 'rate_limit_exceeded') {
      res.status(429).json({ error: 'Rate limit exceeded. Please try again.' });
    } else if (error.code === 'insufficient_quota') {
      res.status(403).json({ error: 'API quota exceeded.' });
    } else {
      res.status(500).json({ error: 'Internal server error.' });
    }
  }
});

// Start server
app.listen(port, '127.0.0.1', () => {
  logger.info(`ChatAI server running on port ${port}`);
});
