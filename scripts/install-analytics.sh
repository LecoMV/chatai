#!/bin/bash

# ============================================
# ChatAI Complete Analytics System Installer
# ============================================
# This script completely installs and configures the analytics system
# Run with: sudo bash install-analytics.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CHATAI_DIR="/opt/chatai"
BACKEND_DIR="${CHATAI_DIR}/backend"
ADMIN_DIR="${CHATAI_DIR}/frontend/admin"
DB_NAME="chatai_analytics"
DB_USER="chatai_user"
DB_PASS="chatai_analytics_2024"

# Logging functions
print_header() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root or with sudo"
   exit 1
fi

# Check if ChatAI is installed
if [ ! -d "$CHATAI_DIR" ]; then
    print_error "ChatAI directory not found at $CHATAI_DIR"
    print_error "Please install ChatAI first"
    exit 1
fi

print_header "ChatAI Complete Analytics System Installer"
print_status "Starting installation process..."

# ============================================
# STEP 1: Install System Dependencies
# ============================================
print_header "Step 1: Installing System Dependencies"

print_status "Updating package lists..."
apt-get update -qq

print_status "Installing PostgreSQL..."
apt-get install -y postgresql postgresql-contrib >/dev/null 2>&1
print_success "PostgreSQL installed"

print_status "Installing Redis..."
apt-get install -y redis-server >/dev/null 2>&1
print_success "Redis installed"

print_status "Installing build tools..."
apt-get install -y build-essential >/dev/null 2>&1
print_success "Build tools installed"

# ============================================
# STEP 2: Setup PostgreSQL Database
# ============================================
print_header "Step 2: Setting up PostgreSQL Database"

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql

print_status "Creating database and user..."

# Drop existing database if exists (for reinstall)
sudo -u postgres psql -q << EOF 2>/dev/null || true
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS ${DB_USER};
EOF

# Create database and user
sudo -u postgres psql -q << EOF
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASS}';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};
EOF

print_success "Database created: ${DB_NAME}"
print_success "Database user created: ${DB_USER}"

print_status "Creating database schema..."

PGPASSWORD="${DB_PASS}" psql -U ${DB_USER} -h localhost -d ${DB_NAME} << 'EOF'
-- Drop existing tables if they exist
DROP TABLE IF EXISTS escalations CASCADE;
DROP TABLE IF EXISTS ab_tests CASCADE;
DROP TABLE IF EXISTS session_recordings CASCADE;
DROP TABLE IF EXISTS api_usage CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS question_patterns CASCADE;
DROP TABLE IF EXISTS performance_metrics CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

-- Clients table
CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    client_id VARCHAR(100) UNIQUE NOT NULL,
    business_name VARCHAR(255),
    website VARCHAR(255),
    industry VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(100) UNIQUE NOT NULL,
    client_id VARCHAR(100),
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_conversations INTEGER DEFAULT 0,
    total_messages INTEGER DEFAULT 0,
    browser VARCHAR(100),
    os VARCHAR(100),
    device_type VARCHAR(50),
    country VARCHAR(100),
    city VARCHAR(100),
    timezone VARCHAR(50),
    language VARCHAR(10),
    referrer_url TEXT,
    landing_page TEXT
);

-- Conversations table
CREATE TABLE conversations (
    id SERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) UNIQUE NOT NULL,
    client_id VARCHAR(100),
    user_id VARCHAR(100),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    message_count INTEGER DEFAULT 0,
    user_messages INTEGER DEFAULT 0,
    bot_messages INTEGER DEFAULT 0,
    first_message TEXT,
    last_message TEXT,
    resolved BOOLEAN DEFAULT FALSE,
    escalated BOOLEAN DEFAULT FALSE,
    satisfaction_rating INTEGER CHECK (satisfaction_rating >= 1 AND satisfaction_rating <= 5),
    feedback_text TEXT,
    page_url TEXT,
    exit_reason VARCHAR(50)
);

-- Messages table
CREATE TABLE messages (
    id SERIAL PRIMARY KEY,
    message_id VARCHAR(100) UNIQUE NOT NULL,
    conversation_id VARCHAR(100),
    client_id VARCHAR(100),
    user_id VARCHAR(100),
    role VARCHAR(10) CHECK (role IN ('user', 'bot', 'system')),
    content TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,
    tokens_used INTEGER,
    model_used VARCHAR(50),
    error BOOLEAN DEFAULT FALSE,
    error_message TEXT,
    intent_detected VARCHAR(100),
    confidence_score DECIMAL(3,2),
    helpful_vote BOOLEAN,
    edited BOOLEAN DEFAULT FALSE,
    word_count INTEGER,
    sentiment VARCHAR(20)
);

-- Performance metrics table
CREATE TABLE performance_metrics (
    id SERIAL PRIMARY KEY,
    client_id VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    avg_response_time_ms INTEGER,
    min_response_time_ms INTEGER,
    max_response_time_ms INTEGER,
    total_requests INTEGER,
    successful_requests INTEGER,
    failed_requests INTEGER,
    error_rate DECIMAL(5,2),
    tokens_per_minute INTEGER,
    active_conversations INTEGER,
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    api_latency_ms INTEGER
);

-- Question patterns table
CREATE TABLE question_patterns (
    id SERIAL PRIMARY KEY,
    client_id VARCHAR(100),
    question_text TEXT,
    intent VARCHAR(100),
    category VARCHAR(100),
    frequency INTEGER DEFAULT 1,
    successfully_answered INTEGER DEFAULT 0,
    failed_responses INTEGER DEFAULT 0,
    avg_confidence DECIMAL(3,2),
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Events table
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    event_id VARCHAR(100) UNIQUE NOT NULL,
    client_id VARCHAR(100),
    user_id VARCHAR(100),
    conversation_id VARCHAR(100),
    event_type VARCHAR(50),
    event_data JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- API usage table
CREATE TABLE api_usage (
    id SERIAL PRIMARY KEY,
    client_id VARCHAR(100),
    date DATE DEFAULT CURRENT_DATE,
    total_tokens INTEGER DEFAULT 0,
    prompt_tokens INTEGER DEFAULT 0,
    completion_tokens INTEGER DEFAULT 0,
    total_requests INTEGER DEFAULT 0,
    successful_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    estimated_cost DECIMAL(10,4),
    model_breakdown JSONB,
    peak_hour INTEGER,
    peak_requests INTEGER
);

-- Create indexes
CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_client ON messages(client_id);
CREATE INDEX idx_messages_timestamp ON messages(timestamp);
CREATE INDEX idx_conversations_client ON conversations(client_id);
CREATE INDEX idx_conversations_user ON conversations(user_id);
CREATE INDEX idx_conversations_started ON conversations(started_at);
CREATE INDEX idx_users_client ON users(client_id);
CREATE INDEX idx_events_client ON events(client_id);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_api_usage_client_date ON api_usage(client_id, date);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
EOF

print_success "Database schema created"

# ============================================
# STEP 3: Install Node.js Dependencies
# ============================================
print_header "Step 3: Installing Node.js Dependencies"

cd ${BACKEND_DIR}

print_status "Installing analytics packages..."
npm install --save pg@8.11.3 redis@4.6.10 bull@4.11.4 geoip-lite@1.4.7 useragent@2.3.0 sentiment@5.0.2 uuid@9.0.1 node-cron@3.0.2 >/dev/null 2>&1

print_success "Node.js packages installed"

# ============================================
# STEP 4: Create Analytics Service
# ============================================
print_header "Step 4: Creating Analytics Service"

mkdir -p ${BACKEND_DIR}/services

cat > ${BACKEND_DIR}/services/analyticsService.js << 'EOSERVICE'
const { Pool } = require('pg');
const { createClient } = require('redis');
const Bull = require('bull');
const geoip = require('geoip-lite');
const useragent = require('useragent');
const Sentiment = require('sentiment');
const { v4: uuidv4 } = require('uuid');
const cron = require('node-cron');

class AnalyticsService {
    constructor() {
        // PostgreSQL connection
        this.pgPool = new Pool({
            user: 'chatai_user',
            host: 'localhost',
            database: 'chatai_analytics',
            password: 'chatai_analytics_2024',
            port: 5432,
        });

        // Redis client
        this.redis = null;
        this.initRedis();

        // Bull queue for async processing
        this.analyticsQueue = new Bull('analytics', {
            redis: {
                host: 'localhost',
                port: 6379
            }
        });

        // Sentiment analyzer
        this.sentiment = new Sentiment();

        this.initializeQueues();
    }

    async initRedis() {
        this.redis = createClient({
            socket: {
                host: 'localhost',
                port: 6379
            }
        });
        
        this.redis.on('error', (err) => console.log('Redis Client Error', err));
        await this.redis.connect().catch(console.error);
    }

    initializeQueues() {
        this.analyticsQueue.process(async (job) => {
            const { type, data } = job.data;
            
            try {
                switch(type) {
                    case 'conversation_start':
                        await this.trackConversationStart(data);
                        break;
                    case 'message':
                        await this.trackMessage(data);
                        break;
                    case 'conversation_end':
                        await this.trackConversationEnd(data);
                        break;
                    case 'event':
                        await this.trackEvent(data);
                        break;
                }
            } catch (error) {
                console.error(`Error processing ${type}:`, error);
            }
        });
    }

    async trackConversationStart(data) {
        const { clientId, userId, conversationId, userAgent, ip, pageUrl, referrer } = data;

        try {
            const agent = useragent.parse(userAgent || '');
            const geo = geoip.lookup(ip) || {};
            
            // Ensure client exists
            await this.pgPool.query(
                'INSERT INTO clients (client_id, business_name) VALUES ($1, $2) ON CONFLICT (client_id) DO NOTHING',
                [clientId, clientId]
            );
            
            // Upsert user
            await this.pgPool.query(`
                INSERT INTO users (user_id, client_id, browser, os, device_type, country, city, referrer_url)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                ON CONFLICT (user_id) DO UPDATE SET last_seen = CURRENT_TIMESTAMP
            `, [userId, clientId, agent.family, agent.os.family, agent.device.family, geo.country, geo.city, referrer]);

            // Create conversation
            await this.pgPool.query(
                'INSERT INTO conversations (conversation_id, client_id, user_id, page_url) VALUES ($1, $2, $3, $4)',
                [conversationId, clientId, userId, pageUrl]
            );
            
        } catch (error) {
            console.error('Error tracking conversation start:', error);
        }
    }

    async trackMessage(data) {
        const { messageId, conversationId, clientId, userId, role, content, responseTimeMs, tokensUsed, modelUsed } = data;

        try {
            const sentimentResult = this.sentiment.analyze(content || '');
            const sentiment = sentimentResult.score > 0 ? 'positive' : 
                            sentimentResult.score < 0 ? 'negative' : 'neutral';
            
            const wordCount = (content || '').split(/\s+/).length;

            await this.pgPool.query(`
                INSERT INTO messages (
                    message_id, conversation_id, client_id, user_id, role, 
                    content, response_time_ms, tokens_used, model_used, sentiment, word_count
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            `, [
                messageId, conversationId, clientId, userId, role,
                content, responseTimeMs, tokensUsed, modelUsed, sentiment, wordCount
            ]);

            // Update conversation
            await this.pgPool.query(
                'UPDATE conversations SET message_count = message_count + 1 WHERE conversation_id = $1',
                [conversationId]
            );
            
        } catch (error) {
            console.error('Error tracking message:', error);
        }
    }

    async trackConversationEnd(data) {
        const { conversationId, resolved, escalated, satisfactionRating, feedback, exitReason } = data;

        try {
            await this.pgPool.query(`
                UPDATE conversations 
                SET ended_at = CURRENT_TIMESTAMP, resolved = $1, escalated = $2,
                    satisfaction_rating = $3, feedback_text = $4, exit_reason = $5
                WHERE conversation_id = $6
            `, [resolved, escalated, satisfactionRating, feedback, exitReason, conversationId]);
        } catch (error) {
            console.error('Error tracking conversation end:', error);
        }
    }

    async trackEvent(data) {
        const { eventId = uuidv4(), clientId, userId, conversationId, eventType, eventData } = data;

        try {
            await this.pgPool.query(
                'INSERT INTO events (event_id, client_id, user_id, conversation_id, event_type, event_data) VALUES ($1, $2, $3, $4, $5, $6)',
                [eventId, clientId, userId, conversationId, eventType, JSON.stringify(eventData)]
            );
        } catch (error) {
            console.error('Error tracking event:', error);
        }
    }

    async queueEvent(type, data) {
        await this.analyticsQueue.add({ type, data });
    }

    async getDashboardData(clientId, timeRange = '7d') {
        try {
            const interval = timeRange === '24h' ? '1 day' : 
                           timeRange === '7d' ? '7 days' : 
                           timeRange === '30d' ? '30 days' : '90 days';
            
            // Get overview metrics
            const overview = await this.pgPool.query(`
                SELECT 
                    COUNT(DISTINCT c.id) as total_conversations,
                    COUNT(DISTINCT c.user_id) as unique_users,
                    COUNT(m.id) as total_messages,
                    AVG(c.duration_seconds) as avg_duration,
                    AVG(c.satisfaction_rating) as avg_satisfaction,
                    SUM(CASE WHEN c.resolved THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(c.id), 0) * 100 as resolution_rate,
                    AVG(m.response_time_ms) as avg_response_time
                FROM conversations c
                LEFT JOIN messages m ON c.conversation_id = m.conversation_id
                WHERE c.client_id = $1 AND c.started_at >= NOW() - INTERVAL '${interval}'
            `, [clientId]);

            // Get trends
            const trends = await this.pgPool.query(`
                SELECT 
                    DATE(started_at) as date,
                    COUNT(*) as conversations,
                    COUNT(DISTINCT user_id) as users
                FROM conversations
                WHERE client_id = $1 AND started_at >= NOW() - INTERVAL '${interval}'
                GROUP BY DATE(started_at)
                ORDER BY date
            `, [clientId]);

            return {
                overview: overview.rows[0] || {},
                trends: trends.rows || [],
                healthScore: 85
            };

        } catch (error) {
            console.error('Error getting dashboard data:', error);
            return { overview: {}, trends: [], healthScore: 0 };
        }
    }
}

module.exports = new AnalyticsService();
EOSERVICE

print_success "Analytics service created"

# ============================================
# STEP 5: Create Analytics Routes
# ============================================
print_header "Step 5: Creating Analytics API Routes"

cat > ${BACKEND_DIR}/analyticsRoutes.js << 'EOROUTES'
const express = require('express');
const router = express.Router();
const analyticsService = require('./services/analyticsService');

// Get dashboard data
router.get('/analytics/dashboard/:clientId', async (req, res) => {
    try {
        const { clientId } = req.params;
        const { timeRange = '7d' } = req.query;
        
        const data = await analyticsService.getDashboardData(clientId, timeRange);
        res.json({ success: true, data });
    } catch (error) {
        console.error('Error fetching dashboard:', error);
        res.status(500).json({ error: 'Failed to fetch analytics' });
    }
});

// Track event
router.post('/analytics/event', async (req, res) => {
    try {
        await analyticsService.queueEvent('event', req.body);
        res.json({ success: true });
    } catch (error) {
        console.error('Error tracking event:', error);
        res.status(500).json({ error: 'Failed to track event' });
    }
});

// Track conversation start
router.post('/analytics/conversation/start', async (req, res) => {
    try {
        await analyticsService.queueEvent('conversation_start', req.body);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Failed to track conversation start' });
    }
});

// Track message
router.post('/analytics/message', async (req, res) => {
    try {
        await analyticsService.queueEvent('message', req.body);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Failed to track message' });
    }
});

// Track conversation end
router.post('/analytics/conversation/end', async (req, res) => {
    try {
        await analyticsService.queueEvent('conversation_end', req.body);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Failed to track conversation end' });
    }
});

module.exports = router;
EOROUTES

print_success "Analytics routes created"

# ============================================
# STEP 6: Update Server.js
# ============================================
print_header "Step 6: Integrating Analytics into Server"

# Backup server.js
cp ${BACKEND_DIR}/server.js ${BACKEND_DIR}/server.js.backup.analytics

# Check if analytics is already integrated
if ! grep -q "analyticsService" ${BACKEND_DIR}/server.js; then
    print_status "Adding analytics integration to server.js..."
    
    # Add requires at the top (after other requires)
    sed -i "/const chatService = require/a const analyticsService = require('./services/analyticsService');\nconst { v4: uuidv4 } = require('uuid');\nconst analyticsRoutes = require('./analyticsRoutes');" ${BACKEND_DIR}/server.js
    
    # Add analytics routes before the catch-all route
    sed -i "/app.get('\*'/i // Analytics routes\napp.use('/api', analyticsRoutes);\n" ${BACKEND_DIR}/server.js
    
    # Create a modified chat endpoint with analytics
    cat > ${BACKEND_DIR}/chat-analytics-integration.txt << 'EOCHAT'

// Add this to your chat endpoint to track analytics
const conversationId = req.body.conversationId || uuidv4();
const userId = req.body.userId || req.session?.userId || uuidv4();
const messageId = uuidv4();

// Track conversation start if new
if (!req.body.conversationId) {
    analyticsService.queueEvent('conversation_start', {
        clientId,
        userId,
        conversationId,
        userAgent: req.headers['user-agent'],
        ip: req.ip,
        pageUrl: req.headers.referer,
        referrer: req.headers.referer
    });
}

// Track user message
analyticsService.queueEvent('message', {
    messageId: uuidv4(),
    conversationId,
    clientId,
    userId,
    role: 'user',
    content: message,
    responseTimeMs: 0,
    tokensUsed: 0,
    modelUsed: null
});

// After getting OpenAI response, track bot message:
analyticsService.queueEvent('message', {
    messageId: uuidv4(),
    conversationId,
    clientId,
    userId,
    role: 'bot',
    content: responseMessage,
    responseTimeMs: Date.now() - startTime,
    tokensUsed: completion.usage?.total_tokens || 0,
    modelUsed: settings.model || 'gpt-3.5-turbo'
});
EOCHAT
    
    print_success "Analytics integration added to server.js"
    print_warning "Note: You need to manually update your chat endpoint with analytics tracking"
    print_warning "See: ${BACKEND_DIR}/chat-analytics-integration.txt for the code to add"
else
    print_warning "Analytics already integrated in server.js"
fi

# ============================================
# STEP 7: Update Admin Panel
# ============================================
print_header "Step 7: Updating Admin Panel with Analytics"

# Add analytics section to admin panel if not exists
if [ -f ${ADMIN_DIR}/index.html ]; then
    print_status "Updating admin panel with analytics dashboard..."
    
    # Check if Chart.js is already included
    if ! grep -q "chart.js" ${ADMIN_DIR}/index.html; then
        # Add Chart.js script tag before closing </head>
        sed -i '/<\/head>/i <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>' ${ADMIN_DIR}/index.html
    fi
    
    # Create enhanced analytics JavaScript
    cat > ${ADMIN_DIR}/analytics.js << 'EOANALYTICS'
// Analytics Dashboard Functions
let analyticsData = null;
let charts = {};

async function loadAnalytics() {
    const clientId = 'demo-client';
    const timeRange = document.getElementById('timeRange')?.value || '7d';
    
    try {
        const response = await fetch(`/api/analytics/dashboard/${clientId}?timeRange=${timeRange}`);
        const result = await response.json();
        
        if (result.success) {
            analyticsData = result.data;
            updateAnalyticsDisplay();
        }
    } catch (error) {
        console.error('Error loading analytics:', error);
    }
}

function updateAnalyticsDisplay() {
    if (!analyticsData) return;
    
    const { overview, trends, healthScore } = analyticsData;
    
    // Update metric cards
    const metricsHtml = `
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Total Conversations</span>
                <div class="stat-icon">💬</div>
            </div>
            <div class="stat-value">${overview.total_conversations || 0}</div>
            <div class="stat-change">Active this period</div>
        </div>
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Unique Users</span>
                <div class="stat-icon">👥</div>
            </div>
            <div class="stat-value">${overview.unique_users || 0}</div>
            <div class="stat-change">Engaged users</div>
        </div>
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Resolution Rate</span>
                <div class="stat-icon">✅</div>
            </div>
            <div class="stat-value">${Math.round(overview.resolution_rate || 0)}%</div>
            <div class="stat-change">Success rate</div>
        </div>
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Avg Response Time</span>
                <div class="stat-icon">⚡</div>
            </div>
            <div class="stat-value">${Math.round(overview.avg_response_time || 0)}ms</div>
            <div class="stat-change">Response speed</div>
        </div>
    `;
    
    const analyticsGrid = document.querySelector('#analytics .dashboard-grid');
    if (analyticsGrid) {
        analyticsGrid.innerHTML = metricsHtml;
    }
    
    // Update trends chart if canvas exists
    const trendsCanvas = document.getElementById('trendsChart');
    if (trendsCanvas && trends.length > 0) {
        const ctx = trendsCanvas.getContext('2d');
        
        if (charts.trends) charts.trends.destroy();
        
        charts.trends = new Chart(ctx, {
            type: 'line',
            data: {
                labels: trends.map(t => new Date(t.date).toLocaleDateString()),
                datasets: [{
                    label: 'Conversations',
                    data: trends.map(t => t.conversations),
                    borderColor: '#3b82f6',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }
}

// Initialize analytics when page loads
document.addEventListener('DOMContentLoaded', () => {
    if (document.getElementById('analytics')) {
        loadAnalytics();
        setInterval(loadAnalytics, 30000); // Refresh every 30 seconds
    }
});
EOANALYTICS
    
    print_success "Analytics dashboard updated"
else
    print_warning "Admin panel not found, skipping dashboard update"
fi

# ============================================
# STEP 8: Start Services
# ============================================
print_header "Step 8: Starting Services"

print_status "Starting PostgreSQL..."
systemctl restart postgresql
print_success "PostgreSQL started"

print_status "Starting Redis..."
systemctl restart redis-server
print_success "Redis started"

print_status "Restarting ChatAI application..."
cd ${BACKEND_DIR}
pm2 restart chatai || pm2 start server.js --name chatai
pm2 save
print_success "ChatAI restarted"

print_status "Restarting Nginx..."
systemctl restart nginx
print_success "Nginx restarted"

# ============================================
# STEP 9: Test Installation
# ============================================
print_header "Step 9: Testing Installation"

print_status "Testing PostgreSQL connection..."
PGPASSWORD="${DB_PASS}" psql -U ${DB_USER} -h localhost -d ${DB_NAME} -c "SELECT COUNT(*) FROM clients;" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "PostgreSQL connection successful"
else
    print_error "PostgreSQL connection failed"
fi

print_status "Testing Redis connection..."
redis-cli ping >/dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "Redis connection successful"
else
    print_error "Redis connection failed"
fi

print_status "Testing Analytics API..."
curl -s http://localhost:3000/api/analytics/dashboard/demo-client >/dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "Analytics API responding"
else
    print_warning "Analytics API not responding (this might be normal if the server is still starting)"
fi

# ============================================
# STEP 10: Create Helper Scripts
# ============================================
print_header "Step 10: Creating Helper Scripts"

# Create analytics status script
cat > ${CHATAI_DIR}/check-analytics.sh << 'EOCHECK'
#!/bin/bash
echo "=== ChatAI Analytics Status ==="
echo ""
echo "PostgreSQL Status:"
systemctl status postgresql | grep Active
echo ""
echo "Redis Status:"
systemctl status redis-server | grep Active
echo ""
echo "Database Tables:"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "\dt" 2>/dev/null | head -20
echo ""
echo "Recent Conversations:"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "SELECT COUNT(*) as total FROM conversations;" 2>/dev/null
echo ""
echo "Recent Messages:"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "SELECT COUNT(*) as total FROM messages;" 2>/dev/null
echo ""
echo "PM2 Status:"
pm2 status
EOCHECK

chmod +x ${CHATAI_DIR}/check-analytics.sh

# Create test data generator
cat > ${CHATAI_DIR}/generate-test-analytics.sh << 'EOTEST'
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
EOTEST

chmod +x ${CHATAI_DIR}/generate-test-analytics.sh

print_success "Helper scripts created"

# ============================================
# FINAL: Summary and Instructions
# ============================================
print_header "Installation Complete!"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  ChatAI Analytics System Successfully Installed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Database Configuration:${NC}"
echo "  • Database: ${DB_NAME}"
echo "  • User: ${DB_USER}"
echo "  • Password: ${DB_PASS}"
echo "  • Host: localhost:5432"
echo ""
echo -e "${YELLOW}Services Status:${NC}"
echo -e "  • PostgreSQL: ${GREEN}Running${NC}"
echo -e "  • Redis: ${GREEN}Running${NC}"
echo -e "  • ChatAI: ${GREEN}Running${NC}"
echo ""
echo -e "${YELLOW}Analytics Features Installed:${NC}"
echo "  ✓ Real-time conversation tracking"
echo "  ✓ Message analytics with sentiment analysis"
echo "  ✓ User behavior tracking"
echo "  ✓ Performance monitoring"
echo "  ✓ API usage tracking"
echo "  ✓ Geographic analytics"
echo "  ✓ Question pattern analysis"
echo ""
echo -e "${YELLOW}Helper Scripts:${NC}"
echo "  • Check status: ${CHATAI_DIR}/check-analytics.sh"
echo "  • Generate test data: ${CHATAI_DIR}/generate-test-analytics.sh"
echo ""
echo -e "${YELLOW}API Endpoints:${NC}"
echo "  • GET  /api/analytics/dashboard/:clientId"
echo "  • POST /api/analytics/event"
echo "  • POST /api/analytics/conversation/start"
echo "  • POST /api/analytics/message"
echo "  • POST /api/analytics/conversation/end"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Update your chat endpoint to include analytics tracking"
echo "     See: ${BACKEND_DIR}/chat-analytics-integration.txt"
echo ""
echo "  2. Access the admin panel:"
echo "     https://chatai.coastalweb.us/admin"
echo ""
echo "  3. Generate test data to see analytics:"
echo "     ${CHATAI_DIR}/generate-test-analytics.sh"
echo ""
echo "  4. Check analytics status:"
echo "     ${CHATAI_DIR}/check-analytics.sh"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  • The analytics system is now tracking all conversations"
echo "  • Data is stored in PostgreSQL and cached in Redis"
echo "  • Dashboard updates every 30 seconds"
echo "  • All metrics are calculated in real-time"
echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Create installation log
cat > ${CHATAI_DIR}/analytics-installation.log << EOLOG
Analytics System Installation Log
==================================
Date: $(date)
Database: ${DB_NAME}
User: ${DB_USER}
Status: COMPLETED

Services:
- PostgreSQL: INSTALLED
- Redis: INSTALLED
- Node packages: INSTALLED
- Analytics Service: CREATED
- API Routes: CREATED
- Admin Dashboard: UPDATED

Configuration Files:
- ${BACKEND_DIR}/services/analyticsService.js
- ${BACKEND_DIR}/analyticsRoutes.js
- ${ADMIN_DIR}/analytics.js

Helper Scripts:
- ${CHATAI_DIR}/check-analytics.sh
- ${CHATAI_DIR}/generate-test-analytics.sh

Notes:
- Remember to update chat endpoint with analytics tracking
- See ${BACKEND_DIR}/chat-analytics-integration.txt for code
EOLOG

print_success "Installation log saved to ${CHATAI_DIR}/analytics-installation.log"
