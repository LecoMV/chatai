#!/bin/bash

echo "Generating test analytics data..."

for i in {1..10}; do
    CONV_ID="test-conv-$RANDOM"
    USER_ID="test-user-$((RANDOM % 100))"
    
    # Start conversation
    curl -s -X POST http://localhost:3000/api/analytics/conversation/start \
        -H "Content-Type: application/json" \
        -d "{
            \"conversationId\": \"$CONV_ID\",
            \"clientId\": \"demo-client\",
            \"userId\": \"$USER_ID\",
            \"userAgent\": \"Mozilla/5.0\",
            \"ip\": \"192.168.1.$i\",
            \"pageUrl\": \"https://example.com\",
            \"referrer\": \"https://google.com\"
        }" > /dev/null
    
    # Send messages
    for j in {1..3}; do
        curl -s -X POST http://localhost:3000/api/analytics/message \
            -H "Content-Type: application/json" \
            -d "{
                \"messageId\": \"msg-$RANDOM\",
                \"conversationId\": \"$CONV_ID\",
                \"clientId\": \"demo-client\",
                \"userId\": \"$USER_ID\",
                \"role\": \"user\",
                \"content\": \"Test message $j\",
                \"responseTimeMs\": $((RANDOM % 2000 + 500)),
                \"tokensUsed\": $((RANDOM % 100 + 50))
            }" > /dev/null
    done
    
    # End conversation
    curl -s -X POST http://localhost:3000/api/analytics/conversation/end \
        -H "Content-Type: application/json" \
        -d "{
            \"conversationId\": \"$CONV_ID\",
            \"resolved\": true,
            \"satisfactionRating\": $((RANDOM % 5 + 1))
        }" > /dev/null
done

echo "Test data generated! Check analytics dashboard."
