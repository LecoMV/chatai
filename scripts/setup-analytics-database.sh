#!/bin/bash

# Setup Analytics Database
# This ensures PostgreSQL is properly configured for analytics

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Setting Up Analytics Database                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Install PostgreSQL if not installed
echo -e "${YELLOW}[1/5] Checking PostgreSQL installation...${NC}"
if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
else
    echo -e "${GREEN}✓ PostgreSQL is installed${NC}"
fi

# Step 2: Create database and user
echo -e "${YELLOW}[2/5] Setting up database...${NC}"

sudo -u postgres psql << EOSQL
-- Create user if not exists
DO
\$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'chatai_user') THEN
      CREATE USER chatai_user WITH PASSWORD 'chatai_analytics_2024';
   END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE chatai_analytics OWNER chatai_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'chatai_analytics')\gexec

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE chatai_analytics TO chatai_user;

-- Connect to the database
\c chatai_analytics

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO chatai_user;
EOSQL

echo -e "${GREEN}✓ Database and user created${NC}"

# Step 3: Create tables
echo -e "${YELLOW}[3/5] Creating analytics tables...${NC}"

PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics << EOTABLES
-- Drop existing tables if needed for clean setup
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS analytics_events CASCADE;

-- Create conversations table
CREATE TABLE conversations (
    id SERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) UNIQUE NOT NULL,
    client_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    start_time TIMESTAMP DEFAULT NOW(),
    end_time TIMESTAMP,
    resolved BOOLEAN DEFAULT false,
    escalated BOOLEAN DEFAULT false,
    satisfaction_rating INTEGER CHECK (satisfaction_rating >= 1 AND satisfaction_rating <= 5),
    feedback TEXT,
    user_agent TEXT,
    ip_address VARCHAR(45),
    page_url TEXT,
    referrer TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create messages table
CREATE TABLE messages (
    id SERIAL PRIMARY KEY,
    message_id VARCHAR(100) UNIQUE NOT NULL,
    conversation_id VARCHAR(100) REFERENCES conversations(conversation_id),
    client_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    role VARCHAR(20) CHECK (role IN ('user', 'bot', 'system')),
    content TEXT,
    response_time_ms INTEGER,
    tokens_used INTEGER,
    sentiment VARCHAR(20),
    intent VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create analytics events table
CREATE TABLE analytics_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    client_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    event_data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_conversations_client_id ON conversations(client_id);
CREATE INDEX idx_conversations_start_time ON conversations(start_time);
CREATE INDEX idx_conversations_user_id ON conversations(user_id);

CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_client_id ON messages(client_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);

CREATE INDEX idx_events_client_id ON analytics_events(client_id);
CREATE INDEX idx_events_event_type ON analytics_events(event_type);
CREATE INDEX idx_events_created_at ON analytics_events(created_at);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO chatai_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO chatai_user;
EOTABLES

echo -e "${GREEN}✓ Tables created successfully${NC}"

# Step 4: Install PostgreSQL driver for Node.js
echo -e "${YELLOW}[4/5] Installing PostgreSQL Node.js driver...${NC}"
cd /opt/chatai/backend
npm install pg --save

# Step 5: Create database service
echo -e "${YELLOW}[5/5] Creating database service...${NC}"

cat > /opt/chatai/backend/services/dbService.js << 'EODBSERVICE'
const { Pool } = require('pg');

// Database connection pool
const pool = new Pool({
    user: 'chatai_user',
    host: 'localhost',
    database: 'chatai_analytics',
    password: 'chatai_analytics_2024',
    port: 5432,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Test connection
pool.query('SELECT NOW()', (err, res) => {
    if (err) {
        console.error('Database connection error:', err);
    } else {
        console.log('Database connected successfully at:', res.rows[0].now);
    }
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    pool: pool
};
EODBSERVICE

echo -e "${GREEN}✓ Database service created${NC}"

# Insert some test data
echo ""
echo -e "${YELLOW}Inserting test data...${NC}"

PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics << EOTESTDATA
-- Insert test conversations
INSERT INTO conversations (conversation_id, client_id, user_id, start_time, resolved, satisfaction_rating)
VALUES 
    ('test-conv-1', 'demo-client', 'user-1', NOW() - INTERVAL '1 day', true, 5),
    ('test-conv-2', 'demo-client', 'user-2', NOW() - INTERVAL '2 days', true, 4),
    ('test-conv-3', 'demo-client', 'user-3', NOW() - INTERVAL '3 days', false, 3),
    ('test-conv-4', 'demo-client', 'user-4', NOW() - INTERVAL '4 days', true, 5),
    ('test-conv-5', 'demo-client', 'user-5', NOW() - INTERVAL '5 days', true, 4)
ON CONFLICT (conversation_id) DO NOTHING;

-- Insert test messages
INSERT INTO messages (message_id, conversation_id, client_id, user_id, role, content, response_time_ms, tokens_used)
VALUES
    ('msg-1', 'test-conv-1', 'demo-client', 'user-1', 'user', 'Hello, I need help', 0, 5),
    ('msg-2', 'test-conv-1', 'demo-client', 'user-1', 'bot', 'Hello! How can I help you?', 500, 10),
    ('msg-3', 'test-conv-2', 'demo-client', 'user-2', 'user', 'What are your hours?', 0, 5),
    ('msg-4', 'test-conv-2', 'demo-client', 'user-2', 'bot', 'We are open Mon-Fri 9-5', 400, 12)
ON CONFLICT (message_id) DO NOTHING;
EOTESTDATA

echo -e "${GREEN}✓ Test data inserted${NC}"

# Test the database
echo ""
echo -e "${BLUE}Testing database connection...${NC}"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "
SELECT 
    COUNT(DISTINCT conversation_id) as total_conversations,
    COUNT(DISTINCT user_id) as unique_users
FROM conversations
WHERE client_id = 'demo-client';"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Analytics Database Setup Complete! ✅              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Database Details:"
echo "• Database: chatai_analytics"
echo "• User: chatai_user"
echo "• Password: chatai_analytics_2024"
echo "• Host: localhost"
echo "• Port: 5432"
echo ""
echo "Test the database:"
echo "PGPASSWORD='chatai_analytics_2024' psql -U chatai_user -h localhost -d chatai_analytics"
