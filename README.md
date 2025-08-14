# 🤖 ChatAI - CoastalWeb AI Assistant

[![Production Ready](https://img.shields.io/badge/Status-Production%20Ready-green.svg)](https://chatai.coastalweb.us)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-blue.svg)](https://nodejs.org/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4-orange.svg)](https://openai.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready AI chatbot widget powered by OpenAI GPT models. Embed intelligent conversations on any website with just one line of code.

🔗 **Live Demo**: [https://chatai.coastalweb.us](https://chatai.coastalweb.us)

## ✨ Features

- 🚀 **One-line embedding** - Add to any website instantly
- 🧠 **OpenAI GPT Integration** - Powered by latest AI models (GPT-3.5, GPT-4, GPT-4o)
- 💬 **Conversation Memory** - Maintains context throughout chat sessions
- 🎨 **Fully Customizable** - Match your brand colors, position, and style
- 🔒 **Production Security** - Rate limiting, CORS, secure API key storage
- 📱 **Responsive Design** - Works perfectly on desktop and mobile
- ⚡ **High Performance** - PM2 clustering and nginx caching
- 📊 **Analytics Ready** - Comprehensive logging and monitoring
- 🌐 **CORS Enabled** - Embed on any domain
- 🔧 **Easy Configuration** - Simple JavaScript API

## 🚀 Quick Start

### 1. Embed Widget (Simplest)
```html
<script src="https://chatai.coastalweb.us/embed.js"></script>
```

### 2. Custom Configuration
```html
<script src="https://chatai.coastalweb.us/embed.js" data-auto-init="false"></script>
<script>
  CoastalWebChatbot.init({
    position: 'bottom-left',
    primaryColor: '#10B981',
    title: 'My AI Assistant'
  });
</script>
```

### 3. Direct API Access
```javascript
const response = await fetch('https://chatai.coastalweb.us/api/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: "Hello, how can you help me?",
    conversationHistory: [],
    settings: { model: 'gpt-3.5-turbo' }
  })
});

const data = await response.json();
console.log(data.message);
```

## 🛠️ Installation & Deployment

### Quick Deployment (Ubuntu 20.04+)

```bash
# Clone the repository
git clone https://github.com/LecoMV/chatai.git
cd chatai

# Make deployment script executable
chmod +x deploy.sh

# Deploy with SSL
sudo ./deploy.sh production --ssl --domain your-domain.com
```

## 📚 Documentation

- [API Documentation](docs/API.md)
- [GitHub Repository](https://github.com/LecoMV/chatai)

## 🆘 Support

- 📧 **Email**: support@coastalweb.us
- 💬 **Live Chat**: Use the widget on [our website](https://chatai.coastalweb.us)!
- 🐛 **Issues**: [GitHub Issues](https://github.com/LecoMV/chatai/issues)

---

<div align="center">
  <strong>Made with ❤️ by <a href="https://coastalweb.us">CoastalWeb</a></strong>
  <br>
  <sub>Empowering websites with intelligent conversations</sub>
</div>
