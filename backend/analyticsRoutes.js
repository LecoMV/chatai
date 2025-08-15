const express = require('express');
const router = express.Router();

console.log('Analytics routes file loaded');

// Simple test endpoint
router.get('/test', (req, res) => {
    console.log('Analytics test endpoint hit');
    res.json({ message: 'Analytics routes are working!' });
});

// Main dashboard endpoint
router.get('/dashboard/:clientId', (req, res) => {
    console.log('Dashboard endpoint hit for client:', req.params.clientId);
    const { clientId } = req.params;
    const { timeRange = '7d' } = req.query;
    
    // Generate mock data
    const mockData = {
        success: true,
        data: {
            overview: {
                total_conversations: 247,
                unique_users: 89,
                resolution_rate: 78,
                avg_response_time: 1250,
                avg_satisfaction: 4.2
            },
            trends: generateTrends(timeRange),
            healthScore: 85,
            sentiment: {
                positive: 65,
                neutral: 25,
                negative: 10
            }
        }
    };
    
    res.json(mockData);
});

// Other endpoints
router.post('/conversation/start', (req, res) => {
    console.log('Conversation start:', req.body);
    res.json({ success: true });
});

router.post('/message', (req, res) => {
    console.log('Message tracked:', req.body);
    res.json({ success: true });
});

router.post('/conversation/end', (req, res) => {
    console.log('Conversation end:', req.body);
    res.json({ success: true });
});

router.post('/event', (req, res) => {
    console.log('Event tracked:', req.body);
    res.json({ success: true });
});

router.get('/realtime/:clientId', (req, res) => {
    res.json({
        success: true,
        metrics: {
            active_conversations: 5,
            messages_today: 234,
            resolved_today: 45,
            escalated_today: 2
        }
    });
});

router.get('/export/:clientId', (req, res) => {
    const { format = 'json' } = req.query;
    if (format === 'csv') {
        res.setHeader('Content-Type', 'text/csv');
        res.send('Date,Conversations,Users\n2024-01-01,100,50');
    } else {
        res.json({ data: 'export' });
    }
});

function generateTrends(timeRange) {
    const days = timeRange === '24h' ? 1 : timeRange === '7d' ? 7 : 30;
    const trends = [];
    for (let i = days - 1; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        trends.push({
            date: date.toISOString().split('T')[0],
            conversations: Math.floor(Math.random() * 50) + 20,
            users: Math.floor(Math.random() * 30) + 10,
            messages: Math.floor(Math.random() * 200) + 50
        });
    }
    return trends;
}

console.log('Analytics routes defined');
module.exports = router;
