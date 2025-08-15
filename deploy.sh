#!/bin/bash

# ChatAI Deployment Script
set -e

echo "🚀 Starting ChatAI deployment..."

# Update system
apt update && apt upgrade -y

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install dependencies
apt install -y nginx certbot python3-certbot-nginx ufw git

# Setup firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Create project directory
mkdir -p /opt/chatbot
cp -r backend frontend nginx /opt/chatbot/

# Install backend dependencies
cd /opt/chatbot/backend
npm install

# Install PM2
npm install -g pm2

# Configure nginx
cp /opt/chatbot/nginx/chatai.conf /etc/nginx/sites-available/chatai
ln -s /etc/nginx/sites-available/chatai /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# Start services
systemctl enable nginx
cd /opt/chatbot/backend
pm2 start ecosystem.config.js
pm2 save
pm2 startup

echo "✅ Deployment complete!"
echo "🔧 Next steps:"
echo "1. Edit /opt/chatbot/backend/.env and add your OpenAI API key"
echo "2. Restart backend: pm2 restart chatai-coastalweb"
echo "3. Setup SSL: certbot --nginx -d your-domain.com"
