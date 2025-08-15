#!/bin/bash
echo "Generating test analytics data..."

# Generate test conversation
curl -X POST http://localhost:3000/api/analytics/conversation/start \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "demo-client",
    "userId": "test-user-1",
    "conversationId": "test-conv-1",
    "userAgent": "Mozilla/5.0",
    "ip": "127.0.0.1",
    "pageUrl": "https://example.com",
    "referrer": "https://google.com"
  }'

# Generate test messages
for i in {1..5}; do
  curl -X POST http://localhost:3000/api/analytics/message \
    -H "Content-Type: application/json" \
    -d "{
      \"messageId\": \"msg-$i\",
      \"conversationId\": \"test-conv-1\",
      \"clientId\": \"demo-client\",
      \"userId\": \"test-user-1\",
      \"role\": \"user\",
      \"content\": \"Test message $i\",
      \"responseTimeMs\": 1000,
      \"tokensUsed\": 50
    }"
  sleep 1
done

echo "Test data generated!"
