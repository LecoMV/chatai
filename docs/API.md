# ChatAI API Documentation

## Base URL
```
https://chatai.coastalweb.us
```

## Endpoints

### 1. Chat with AI

```http
POST /api/chat
```

#### Request Body
```json
{
  "message": "Hello, how can you help me?",
  "conversationHistory": [],
  "settings": {
    "model": "gpt-3.5-turbo",
    "temperature": 0.7,
    "maxTokens": 500
  }
}
```

#### Response
```json
{
  "message": "AI response text",
  "usage": {
    "prompt_tokens": 15,
    "completion_tokens": 25,
    "total_tokens": 40
  },
  "model": "gpt-3.5-turbo",
  "responseTime": 1250,
  "service": "ChatAI CoastalWeb"
}
```

### 2. Health Check

```http
GET /health
```

#### Response
```json
{
  "status": "OK",
  "service": "ChatAI CoastalWeb",
  "version": "1.0.0",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "uptime": 86400
}
```

## JavaScript SDK

```javascript
const response = await fetch('https://chatai.coastalweb.us/api/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: "Hello!",
    conversationHistory: [],
    settings: { model: 'gpt-3.5-turbo' }
  })
});

const data = await response.json();
console.log(data.message);
```

## Rate Limiting
- 50 requests per minute per IP address

## Support
- Email: support@coastalweb.us
- GitHub: https://github.com/LecoMV/chatai/issues
