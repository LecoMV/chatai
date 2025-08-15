#!/bin/bash

# Push ChatAI Project to GitHub Repository
# This script will push all your project files to the v2-customer-service branch

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Push ChatAI Project to GitHub Repository          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

PROJECT_DIR="/opt/chatai"
cd $PROJECT_DIR

# Step 1: Check current git status
echo -e "${CYAN}[1/8] Checking current Git status...${NC}"
echo "Current branch:"
git branch --show-current || echo "Not in a git repository"
echo ""
echo "Remote repositories:"
git remote -v
echo ""

# Step 2: Ensure we're on the right branch
echo -e "${CYAN}[2/8] Switching to v2-customer-service branch...${NC}"

# Check if branch exists locally
if git show-ref --verify --quiet refs/heads/v2-customer-service; then
    echo "Branch v2-customer-service exists locally"
    git checkout v2-customer-service
else
    echo "Creating v2-customer-service branch"
    git checkout -b v2-customer-service
fi
echo ""

# Step 3: Update .gitignore
echo -e "${CYAN}[3/8] Updating .gitignore...${NC}"
cat > ${PROJECT_DIR}/.gitignore << 'EOGITIGNORE'
# Node modules
node_modules/
*/node_modules/

# Environment files
.env
.env.local
.env.*.local
*.env

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pm2.log
.pm2/

# Database
*.sqlite
*.sqlite3
*.db

# Backups
*.backup
*.backup-*
backups/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS Files
.DS_Store
Thumbs.db

# Build outputs
dist/
build/

# Temporary files
tmp/
temp/
*.tmp

# Sensitive data
config/clients/*.json
!config/clients/template.json
!config/clients/demo-client.json

# SSL Certificates
*.pem
*.key
*.crt
*.cer

# Python
__pycache__/
*.py[cod]
*$py.class

# Test coverage
coverage/
.nyc_output/

# Analytics data
chatai_analytics.sql
analytics-installation.log
EOGITIGNORE

echo -e "${GREEN}✓ Updated .gitignore${NC}"

# Step 4: Create README for v2
echo -e "${CYAN}[4/8] Creating comprehensive README...${NC}"
cat > ${PROJECT_DIR}/README.md << 'EOREADME'
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
EOREADME

echo -e "${GREEN}✓ Created README.md${NC}"

# Step 5: Add all files
echo -e "${CYAN}[5/8] Adding files to Git...${NC}"

# Add all files except those in .gitignore
git add -A

# Show what will be committed
echo "Files to be committed:"
git status --short | head -20
echo "..."
echo "Total files: $(git status --short | wc -l)"
echo ""

# Step 6: Commit changes
echo -e "${CYAN}[6/8] Committing changes...${NC}"
echo "Enter commit message (or press Enter for default):"
read -t 10 COMMIT_MSG || COMMIT_MSG=""

if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="Complete v2 customer service chatbot implementation with analytics"
fi

git commit -m "$COMMIT_MSG" || echo "No changes to commit"
echo ""

# Step 7: Push to GitHub
echo -e "${CYAN}[7/8] Pushing to GitHub...${NC}"
echo ""
echo -e "${YELLOW}GitHub Authentication Required${NC}"
echo "You'll need to enter your GitHub credentials:"
echo "Username: LecoMV"
echo "Password: Use your Personal Access Token (NOT your password)"
echo ""
echo "If you don't have a token:"
echo "1. Go to https://github.com/settings/tokens"
echo "2. Generate new token (classic)"
echo "3. Select 'repo' scope"
echo "4. Copy the token"
echo ""
echo -e "${YELLOW}Ready to push? (y/n)${NC}"
read -n 1 CONFIRM
echo ""

if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
    # Push the branch
    git push -u origin v2-customer-service
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully pushed to GitHub!${NC}"
    else
        echo -e "${RED}✗ Push failed. Trying alternative method...${NC}"
        echo ""
        echo "Alternative: Set up SSH authentication"
        echo "1. Generate SSH key: ssh-keygen -t ed25519 -C 'your-email@example.com'"
        echo "2. Add to GitHub: https://github.com/settings/keys"
        echo "3. Change remote to SSH:"
        echo "   git remote set-url origin git@github.com:LecoMV/chatai.git"
        echo "4. Try push again:"
        echo "   git push -u origin v2-customer-service"
    fi
else
    echo "Push cancelled."
fi

# Step 8: Create useful scripts for future updates
echo -e "${CYAN}[8/8] Creating helper scripts...${NC}"

# Create a quick update script
cat > ${PROJECT_DIR}/push-updates.sh << 'EOPUSH'
#!/bin/bash
cd /opt/chatai
git add -A
git commit -m "$1"
git push origin v2-customer-service
echo "Updates pushed to GitHub!"
EOPUSH
chmod +x ${PROJECT_DIR}/push-updates.sh

# Create a pull updates script
cat > ${PROJECT_DIR}/pull-updates.sh << 'EOPULL'
#!/bin/bash
cd /opt/chatai
git pull origin v2-customer-service
npm install --prefix backend
pm2 restart chatai
echo "Updates pulled and server restarted!"
EOPULL
chmod +x ${PROJECT_DIR}/pull-updates.sh

echo -e "${GREEN}✓ Created helper scripts${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              GitHub Push Complete! 🎉                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Your project is now on GitHub at:"
echo -e "${BLUE}https://github.com/LecoMV/chatai/tree/v2-customer-service${NC}"
echo ""
echo "Quick commands for future updates:"
echo "• Push updates: ./push-updates.sh 'Your commit message'"
echo "• Pull updates: ./pull-updates.sh"
echo ""
echo "To clone on another server:"
echo "git clone -b v2-customer-service https://github.com/LecoMV/chatai.git"
echo ""
echo "Files included:"
echo "✓ All backend code"
echo "✓ Frontend and admin panel"
echo "✓ Configuration templates"
echo "✓ Setup scripts"
echo "✓ Documentation"
echo ""
echo "Files excluded (for security):"
echo "✗ .env files"
echo "✗ node_modules"
echo "✗ Client secrets"
echo "✗ SSL certificates"
echo "✗ Database dumps"
