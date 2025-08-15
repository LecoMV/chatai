#!/bin/bash
echo "ChatAI Client Setup Wizard"
echo "=========================="
read -p "Enter client business name: " business_name
read -p "Enter client website URL: " website
read -p "Enter client ID (lowercase, no spaces): " client_id
read -p "Enter support email: " support_email

cat > /opt/chatai/backend/config/clients/${client_id}.json << EOF
{
  "clientId": "${client_id}",
  "businessName": "${business_name}",
  "website": "${website}",
  "industry": "General",
  "knowledgeBase": {
    "about": "Description of ${business_name}",
    "services": ["Service 1", "Service 2", "Service 3"],
    "faqs": [
      {
        "question": "What are your business hours?",
        "answer": "Monday-Friday, 9 AM - 5 PM"
      }
    ],
    "policies": {
      "returns": "30-day return policy",
      "privacy": "We respect your privacy"
    }
  },
  "chatbotSettings": {
    "tone": "professional and friendly",
    "maxResponseLength": 500,
    "escalationEmail": "${support_email}",
    "limitations": [
      "Cannot process payments",
      "Cannot access customer accounts"
    ]
  },
  "customization": {
    "primaryColor": "#2563eb",
    "greeting": "Hello! Welcome to ${business_name}. How can I help you?",
    "position": "bottom-right"
  }
}
EOF

echo "Client configuration created!"
echo "Edit /opt/chatai/backend/config/clients/${client_id}.json to customize"
echo ""
echo "Embed code:"
echo "<script src=\"https://chatai.coastalweb.us/embed.js\" data-client-id=\"${client_id}\"></script>"
