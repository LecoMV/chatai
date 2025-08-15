# ChatAI - Customer Service Chatbot Platform (v2)

A customizable AI-powered customer service chatbot platform that can be deployed on any website.

## Features

### Core Functionality
- 🤖 **AI-Powered Chat**: Powered by OpenAI GPT-3.5/GPT-4
- 🎯 **Multi-Client Support**: Manage multiple clients from one platform
- 🎨 **Customizable**: Fully customizable for each client's brand
- 📊 **Analytics Dashboard**: Comprehensive analytics and insights
- 🔒 **Secure**: Rate limiting, authentication, and security features

### Admin Panel
- Client management (CRUD operations)
- Knowledge base editor
- Real-time conversation monitoring
- Analytics and reporting
- Deployment tools

### Analytics System
- Real-time metrics tracking
- Conversation analytics
- User behavior insights
- Performance monitoring
- Export capabilities

## Installation

### Prerequisites
- Ubuntu 24.04 LTS
- Node.js 20+
- PostgreSQL 14+
- Redis
- Nginx
- PM2

### Quick Setup

1. Clone the repository:
```bash
git clone https://github.com/LecoMV/chatai.git
cd chatai
git checkout v2-customer-service
```

2. Install dependencies:
```bash
cd backend
npm install
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your OpenAI API key
```

4. Set up the database:
```bash
sudo -u postgres createdb chatai_analytics
# Run the setup scripts in /scripts
```

5. Start the application:
```bash
pm2 start server.js --name chatai
```

6. Configure Nginx:
```bash
sudo cp nginx/chatai.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/chatai.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Project Structure

```
/opt/chatai/
├── backend/
│   ├── server.js              # Main server file
│   ├── analyticsRoutes.js     # Analytics API endpoints
│   ├── services/
│   │   ├── chatService.js     # Chat service logic
│   │   ├── analyticsService.js # Analytics service
│   │   └── dbService.js       # Database service
│   └── config/
│       └── clients/           # Client configurations
├── frontend/
│   ├── index.html             # Chat widget
│   ├── embed.js               # Embeddable script
│   └── admin/                 # Admin dashboard
│       └── index.html         # Admin panel
├── scripts/                   # Utility scripts
│   ├── setup-analytics.sh     # Analytics setup
│   ├── onboard-client.sh      # Client onboarding
│   ├── backup.sh              # Backup script
│   └── monitor.sh             # Monitoring script
├── nginx/                     # Nginx configurations
└── docs/                      # Documentation
```

## Usage

### For Website Owners

Add this code to your website:

```html
<script src="https://chatai.coastalweb.us/embed.js" 
        data-client-id="YOUR_CLIENT_ID"></script>
```

### For Administrators

Access the admin panel at: `https://your-domain.com/admin`

#### Add a New Client
```bash
./scripts/onboard-client.sh
```

#### Monitor System
```bash
./scripts/monitor.sh
```

#### View Logs
```bash
pm2 logs chatai
```

## API Documentation

### Chat Endpoint
```
POST /api/chat
{
  "message": "User message",
  "conversationHistory": [],
  "clientId": "client-id"
}
```

### Analytics Endpoints
```
GET /api/analytics/dashboard/:clientId?timeRange=7d
GET /api/analytics/realtime/:clientId
GET /api/analytics/export/:clientId?format=csv
```

## Configuration

### Client Configuration Format
```json
{
  "clientId": "unique-client-id",
  "businessName": "Business Name",
  "website": "https://example.com",
  "knowledgeBase": {
    "about": "Company description",
    "services": ["Service 1", "Service 2"],
    "faqs": [{
      "question": "FAQ question",
      "answer": "FAQ answer"
    }]
  },
  "chatbotSettings": {
    "tone": "professional and friendly",
    "maxResponseLength": 500,
    "escalationEmail": "support@example.com"
  }
}
```

## Security

- Rate limiting on all endpoints
- CORS configuration
- Input validation
- SQL injection prevention
- XSS protection
- HTTPS enforcement

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, email: support@coastalweb.us

## Acknowledgments

- OpenAI for GPT API
- Node.js community
- Contributors and testers

---

**Version**: 2.0.0  
**Last Updated**: August 2025  
**Status**: Production Ready
