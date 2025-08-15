const fs = require('fs').promises;
const path = require('path');

class ChatService {
  constructor() {
    this.configCache = new Map();
  }

  async loadClientConfig(clientId) {
    try {
      // Check cache first
      if (this.configCache.has(clientId)) {
        return this.configCache.get(clientId);
      }

      // Load from file
      const configPath = path.join(__dirname, '../config/clients', `${clientId}.json`);
      const configData = await fs.readFile(configPath, 'utf8');
      const config = JSON.parse(configData);
      
      // Cache the configuration
      this.configCache.set(clientId, config);
      
      return config;
    } catch (error) {
      console.error(`Failed to load config for client ${clientId}:`, error);
      
      // Try to load template as fallback
      try {
        const templatePath = path.join(__dirname, '../config/clients', 'template.json');
        const templateData = await fs.readFile(templatePath, 'utf8');
        return JSON.parse(templateData);
      } catch (templateError) {
        console.error('Failed to load template config:', templateError);
        return null;
      }
    }
  }

  generateSystemPrompt(config) {
    // Build FAQs string
    const faqsString = config.knowledgeBase.faqs
      .map(faq => `Q: ${faq.question}\nA: ${faq.answer}`)
      .join('\n\n');

    // Build policies string
    const policiesString = Object.entries(config.knowledgeBase.policies)
      .map(([key, value]) => `${key.charAt(0).toUpperCase() + key.slice(1)}: ${value}`)
      .join('\n');

    // Build services list
    const servicesString = config.knowledgeBase.services.join(', ');

    // Build limitations list
    const limitationsString = config.chatbotSettings.limitations
      .map((limitation, index) => `${index + 1}. ${limitation}`)
      .join('\n');

    return `You are a customer service assistant for ${config.businessName}. 
Your role is to provide helpful, accurate information about our company and services.

COMPANY INFORMATION:
- Business Name: ${config.businessName}
- Website: ${config.website}
- Industry: ${config.industry}
- About Us: ${config.knowledgeBase.about}

SERVICES OFFERED:
${servicesString}

FREQUENTLY ASKED QUESTIONS:
${faqsString}

COMPANY POLICIES:
${policiesString}

COMMUNICATION STYLE:
- Tone: ${config.chatbotSettings.tone}
- Maximum response length: ${config.chatbotSettings.maxResponseLength} characters
- Always be helpful, polite, and professional

YOUR LIMITATIONS:
${limitationsString}

ESCALATION CONTACT:
If you cannot help with a request, provide this contact: ${config.chatbotSettings.escalationEmail}

CRITICAL RULES:
1. ONLY answer questions related to ${config.businessName}, its services, and its website
2. NEVER make up or invent information that's not in your knowledge base
3. If you don't know something, admit it honestly and offer to connect them with human support
4. Keep all responses under ${config.chatbotSettings.maxResponseLength} characters
5. Do not discuss other companies or competitors
6. Do not provide personal opinions or recommendations outside of company information
7. If asked about topics unrelated to ${config.businessName}, politely redirect the conversation back to how you can help with company-related questions
8. Always maintain a ${config.chatbotSettings.tone} tone in your responses
9. When providing contact information, always use: ${config.chatbotSettings.escalationEmail}
10. If someone asks who you are, identify yourself as the customer service assistant for ${config.businessName}

Remember: You are here to help customers with questions about ${config.businessName} only. Stay focused on this role.`;
  }

  // Method to validate client configuration
  validateConfig(config) {
    const requiredFields = [
      'clientId',
      'businessName',
      'website',
      'knowledgeBase',
      'chatbotSettings',
      'customization'
    ];

    for (const field of requiredFields) {
      if (!config[field]) {
        throw new Error(`Missing required field: ${field}`);
      }
    }

    return true;
  }

  // Method to clear cache for a specific client
  clearClientCache(clientId) {
    this.configCache.delete(clientId);
  }

  // Method to clear all cached configurations
  clearAllCache() {
    this.configCache.clear();
  }

  // Method to get all available clients
  async getAllClients() {
    try {
      const clientsDir = path.join(__dirname, '../config/clients');
      const files = await fs.readdir(clientsDir);
      
      const clients = [];
      for (const file of files) {
        if (file.endsWith('.json') && file !== 'template.json') {
          const clientId = file.replace('.json', '');
          const config = await this.loadClientConfig(clientId);
          if (config) {
            clients.push({
              clientId: config.clientId,
              businessName: config.businessName,
              website: config.website
            });
          }
        }
      }
      
      return clients;
    } catch (error) {
      console.error('Failed to get all clients:', error);
      return [];
    }
  }

  // Method to save client configuration
  async saveClientConfig(clientId, config) {
    try {
      // Validate configuration
      this.validateConfig(config);
      
      // Ensure clientId matches
      config.clientId = clientId;
      
      // Save to file
      const configPath = path.join(__dirname, '../config/clients', `${clientId}.json`);
      await fs.writeFile(configPath, JSON.stringify(config, null, 2));
      
      // Clear cache for this client
      this.clearClientCache(clientId);
      
      return true;
    } catch (error) {
      console.error(`Failed to save config for client ${clientId}:`, error);
      throw error;
    }
  }

  // Method to delete client configuration
  async deleteClientConfig(clientId) {
    try {
      const configPath = path.join(__dirname, '../config/clients', `${clientId}.json`);
      await fs.unlink(configPath);
      
      // Clear cache for this client
      this.clearClientCache(clientId);
      
      return true;
    } catch (error) {
      console.error(`Failed to delete config for client ${clientId}:`, error);
      throw error;
    }
  }

  // Method to generate embed code for a client
  generateEmbedCode(clientId, options = {}) {
    const baseUrl = 'https://chatai.coastalweb.us';
    const { position = 'bottom-right', primaryColor, greeting } = options;
    
    let attributes = `data-client-id="${clientId}"`;
    if (position) attributes += ` data-position="${position}"`;
    if (primaryColor) attributes += ` data-primary-color="${primaryColor}"`;
    if (greeting) attributes += ` data-greeting="${greeting}"`;
    
    return `<!-- ChatAI Customer Service Bot -->
<script src="${baseUrl}/embed.js" ${attributes}></script>`;
  }
}

// Export singleton instance
module.exports = new ChatService();
