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
