#!/bin/bash

# Fix GitHub Repository Errors
# This script identifies and fixes common errors in the ChatAI repository

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Fixing GitHub Repository Errors                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

cd /opt/chatai

# Pull latest changes from GitHub to sync
echo -e "${CYAN}[1/10] Syncing with GitHub...${NC}"
git pull origin v2-customer-service || echo "Already up to date"
echo ""

# Fix 1: Remove accidentally committed files
echo -e "${CYAN}[2/10] Removing accidentally committed files...${NC}"

# Remove backup files
find . -name "*.backup" -o -name "*.backup-*" -o -name "*.bak.*" -o -name "*.broken" | while read file; do
    if [ -f "$file" ]; then
        echo "Removing: $file"
        git rm --cached "$file" 2>/dev/null || rm "$file"
    fi
done

# Remove the weird file with spaces
if [ -f "dusLQSu postgres psql" ]; then
    echo "Removing: dusLQSu postgres psql"
    git rm --cached "dusLQSu postgres psql" 2>/dev/null || rm "dusLQSu postgres psql"
fi

# Remove temporary files
rm -f backend/chat-analytics-integration.txt
git rm --cached backend/chat-analytics-integration.txt 2>/dev/null || true

echo -e "${GREEN}✓ Cleaned up unnecessary files${NC}"

# Fix 2: Create missing essential files
echo -e "${CYAN}[3/10] Creating missing essential files...${NC}"

# Create .env.example if missing
if [ ! -f backend/.env.example ]; then
    cat > backend/.env.example << 'EOENV'
# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Server Configuration
PORT=3000
NODE_ENV=production

# Database Configuration (for analytics)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=chatai_analytics
DB_USER=chatai_user
DB_PASSWORD=your_database_password

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379

# Admin Panel
ADMIN_USERNAME=admin
ADMIN_PASSWORD=change_this_password

# CORS Settings
ALLOWED_ORIGINS=https://your-domain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=30
EOENV
    echo -e "${GREEN}✓ Created .env.example${NC}"
fi

# Create LICENSE file if missing
if [ ! -f LICENSE ]; then
    cat > LICENSE << 'EOLICENSE'
MIT License

Copyright (c) 2025 LecoMV

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOLICENSE
    echo -e "${GREEN}✓ Created LICENSE${NC}"
fi

# Fix 3: Create proper directory structure
echo -e "${CYAN}[4/10] Ensuring proper directory structure...${NC}"

# Create missing directories
mkdir -p scripts
mkdir -p nginx
mkdir -p docs
mkdir -p backend/config/clients
mkdir -p backend/services
mkdir -p frontend/admin

echo -e "${GREEN}✓ Directory structure verified${NC}"

# Fix 4: Move misplaced files
echo -e "${CYAN}[5/10] Moving misplaced files...${NC}"

# Move analytics files to correct location
if [ -f backend/src/analytics.js ] && [ ! -f backend/services/analyticsService.js ]; then
    mv backend/src/analytics.js backend/services/analyticsService.js
    echo "Moved analytics.js to services/"
fi

# Remove empty src directory if exists
if [ -d backend/src ] && [ -z "$(ls -A backend/src)" ]; then
    rmdir backend/src
fi

echo -e "${GREEN}✓ Files organized${NC}"

# Fix 5: Create demo client configuration
echo -e "${CYAN}[6/10] Creating demo client configuration...${NC}"

if [ ! -f backend/config/clients/demo-client.json ]; then
    cat > backend/config/clients/demo-client.json << 'EODEMO'
{
  "clientId": "demo-client",
  "businessName": "Demo Business",
  "website": "https://demo.example.com",
  "industry": "Technology",
  "knowledgeBase": {
    "about": "We are a demo company showcasing the ChatAI platform capabilities.",
    "services": [
      "Web Development",
      "AI Integration",
      "Customer Support"
    ],
    "faqs": [
      {
        "question": "What are your business hours?",
        "answer": "We're available Monday-Friday, 9 AM - 5 PM EST"
      },
      {
        "question": "How can I contact support?",
        "answer": "Email us at support@demo.com or use this chat!"
      }
    ],
    "policies": {
      "returns": "30-day return policy on all services",
      "privacy": "We respect your privacy and never share your data"
    }
  },
  "chatbotSettings": {
    "tone": "professional and friendly",
    "maxResponseLength": 500,
    "escalationEmail": "support@demo.com",
    "limitations": [
      "Cannot process payments",
      "Cannot access customer accounts",
      "Cannot provide legal advice"
    ]
  },
  "customization": {
    "primaryColor": "#0066cc",
    "greeting": "Hello! How can I help you today?",
    "placeholder": "Type your question here...",
    "position": "bottom-right"
  }
}
EODEMO
    echo -e "${GREEN}✓ Created demo client configuration${NC}"
fi

# Fix 6: Create essential scripts
echo -e "${CYAN}[7/10] Creating essential scripts...${NC}"

# Create setup script
cat > scripts/setup.sh << 'EOSETUP'
#!/bin/bash
echo "Setting up ChatAI..."
cd backend
npm install
cd ..
echo "Setup complete! Run 'npm start' in the backend directory to start."
EOSETUP
chmod +x scripts/setup.sh

# Create basic nginx config
if [ ! -f nginx/chatai.conf ]; then
    cat > nginx/chatai.conf << 'EONGINX'
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        root /opt/chatai/frontend;
        try_files $uri $uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EONGINX
    echo -e "${GREEN}✓ Created nginx config template${NC}"
fi

echo -e "${GREEN}✓ Essential scripts created${NC}"

# Fix 7: Update .gitignore
echo -e "${CYAN}[8/10] Updating .gitignore...${NC}"

cat > .gitignore << 'EOGITIGNORE'
# Node modules
node_modules/
*/node_modules/

# Environment files
.env
.env.local
.env.*.local
*.env
!.env.example

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
*.sql

# Backups
*.backup
*.backup-*
*.bak
*.bak.*
*.broken
backups/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# Build outputs
dist/
build/

# Temporary files
tmp/
temp/
*.tmp
*.temp
chat-analytics-integration.txt

# Sensitive data  
backend/config/clients/*.json
!backend/config/clients/template.json
!backend/config/clients/demo-client.json

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

# Misc
"dusLQSu postgres psql"
analytics-installation.log
EOGITIGNORE

echo -e "${GREEN}✓ Updated .gitignore${NC}"

# Fix 8: Clean up SQL files if they exist
echo -e "${CYAN}[9/10] Cleaning up SQL files...${NC}"

# Move SQL files to a sql directory instead of committing them
if ls backend/*.sql 1> /dev/null 2>&1; then
    mkdir -p backend/sql
    mv backend/*.sql backend/sql/ 2>/dev/null || true
    echo "Moved SQL files to backend/sql/"
fi

echo -e "${GREEN}✓ SQL files organized${NC}"

# Fix 9: Commit all fixes
echo -e "${CYAN}[10/10] Committing fixes to GitHub...${NC}"

# Add all changes
git add -A

# Check if there are changes to commit
if [[ -n $(git status -s) ]]; then
    git commit -m "Fix: Clean up repository structure and remove unnecessary files

- Removed backup and temporary files
- Added missing essential files (.env.example, LICENSE)
- Organized directory structure
- Created demo client configuration
- Updated .gitignore to prevent future issues
- Added setup scripts and nginx template"
    
    echo -e "${GREEN}✓ Changes committed${NC}"
    
    # Push to GitHub
    echo ""
    echo -e "${YELLOW}Pushing fixes to GitHub...${NC}"
    git push origin v2-customer-service
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully pushed fixes to GitHub!${NC}"
    else
        echo -e "${YELLOW}Could not push automatically. Run: git push origin v2-customer-service${NC}"
    fi
else
    echo "No changes needed - repository is clean!"
fi

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Repository Cleanup Complete! ✅                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Fixed Issues:"
echo "✓ Removed backup and temporary files"
echo "✓ Created missing essential files"
echo "✓ Organized directory structure"
echo "✓ Updated .gitignore"
echo "✓ Added demo configuration"
echo ""
echo "Your repository is now clean and professional!"
echo ""
echo "View your cleaned repository at:"
echo -e "${BLUE}https://github.com/LecoMV/chatai/tree/v2-customer-service${NC}"
echo ""
echo "Next steps:"
echo "1. Review the changes on GitHub"
echo "2. Update README if needed"
echo "3. Add any additional documentation to the docs/ folder"
