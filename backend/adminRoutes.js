const express = require('express');
const router = express.Router();
const chatService = require('./services/chatService');
const fs = require('fs').promises;
const path = require('path');

// Basic admin authentication middleware
const adminAuth = (req, res, next) => {
    // In production, implement proper JWT authentication
    const authHeader = req.headers.authorization;
    if (authHeader === 'Bearer admin-token-here') {
        next();
    } else {
        res.status(401).json({ error: 'Unauthorized' });
    }
};

// Get all clients
router.get('/clients', async (req, res) => {
    try {
        const clients = await chatService.getAllClients();
        res.json({ clients, success: true });
    } catch (error) {
        console.error('Error fetching clients:', error);
        res.status(500).json({ error: 'Failed to fetch clients' });
    }
});

// Get specific client
router.get('/clients/:clientId', async (req, res) => {
    try {
        const { clientId } = req.params;
        const config = await chatService.loadClientConfig(clientId);
        
        if (!config) {
            return res.status(404).json({ error: 'Client not found' });
        }
        
        res.json({ config, success: true });
    } catch (error) {
        console.error('Error fetching client:', error);
        res.status(500).json({ error: 'Failed to fetch client' });
    }
});

// Create new client
router.post('/clients', async (req, res) => {
    try {
        const clientData = req.body;
        await chatService.saveClientConfig(clientData.clientId, clientData);
        res.json({ success: true, message: 'Client created successfully' });
    } catch (error) {
        console.error('Error creating client:', error);
        res.status(500).json({ error: 'Failed to create client' });
    }
});

// Update client
router.put('/clients/:clientId', async (req, res) => {
    try {
        const { clientId } = req.params;
        const clientData = req.body;
        await chatService.saveClientConfig(clientId, clientData);
        res.json({ success: true, message: 'Client updated successfully' });
    } catch (error) {
        console.error('Error updating client:', error);
        res.status(500).json({ error: 'Failed to update client' });
    }
});

// Delete client
router.delete('/clients/:clientId', async (req, res) => {
    try {
        const { clientId } = req.params;
        await chatService.deleteClientConfig(clientId);
        res.json({ success: true, message: 'Client deleted successfully' });
    } catch (error) {
        console.error('Error deleting client:', error);
        res.status(500).json({ error: 'Failed to delete client' });
    }
});

// Get analytics
router.get('/analytics', async (req, res) => {
    try {
        const analytics = {
            totalMessages: 5234,
            uniqueUsers: 892,
            avgResponseTime: 1.2,
            satisfactionRate: 94,
            apiUsage: 124000
        };
        res.json({ analytics, success: true });
    } catch (error) {
        console.error('Error fetching analytics:', error);
        res.status(500).json({ error: 'Failed to fetch analytics' });
    }
});

// Get conversations
router.get('/conversations', async (req, res) => {
    try {
        // This would query your database for conversation logs
        const conversations = [];
        res.json({ conversations, success: true });
    } catch (error) {
        console.error('Error fetching conversations:', error);
        res.status(500).json({ error: 'Failed to fetch conversations' });
    }
});

// Generate embed code
router.get('/embed/:clientId', async (req, res) => {
    try {
        const { clientId } = req.params;
        const { position = 'bottom-right', primaryColor, greeting } = req.query;
        
        const embedCode = chatService.generateEmbedCode(clientId, {
            position,
            primaryColor,
            greeting
        });
        
        res.json({ embedCode, success: true });
    } catch (error) {
        console.error('Error generating embed code:', error);
        res.status(500).json({ error: 'Failed to generate embed code' });
    }
});

module.exports = router;
