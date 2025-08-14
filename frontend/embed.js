(function() {
    'use strict';
    
    if (window.CoastalWebChatbot) return;
    
    window.CoastalWebChatbot = {
        init: function(options = {}) {
            const defaults = {
                position: 'bottom-right',
                primaryColor: '#3B82F6'
            };
            
            const config = Object.assign(defaults, options);
            
            const createChatbot = () => {
                const chatbotHTML = `
                    <div id="coastalweb-chatbot" style="position: fixed; ${config.position.includes('right') ? 'right: 20px;' : 'left: 20px;'} bottom: 20px; z-index: 10000;">
                        <div id="chatbot-button" style="width: 60px; height: 60px; border-radius: 50%; background: linear-gradient(135deg, ${config.primaryColor}, #8B5CF6); color: white; display: flex; align-items: center; justify-content: center; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.3); font-size: 24px;">
                            💬
                        </div>
                        <iframe id="chatbot-iframe" src="https://chatai.coastalweb.us/" style="display: none; width: 400px; height: 600px; border: none; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.2); position: absolute; bottom: 70px; ${config.position.includes('right') ? 'right: 0;' : 'left: 0;'}"></iframe>
                    </div>
                `;
                
                document.body.insertAdjacentHTML('beforeend', chatbotHTML);
                
                const button = document.getElementById('chatbot-button');
                const iframe = document.getElementById('chatbot-iframe');
                
                button.addEventListener('click', () => {
                    if (iframe.style.display === 'none') {
                        iframe.style.display = 'block';
                        button.innerHTML = '❌';
                    } else {
                        iframe.style.display = 'none';
                        button.innerHTML = '💬';
                    }
                });
            };
            
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', createChatbot);
            } else {
                createChatbot();
            }
        }
    };
    
    const script = document.currentScript;
    if (script && script.dataset.autoInit !== 'false') {
        window.CoastalWebChatbot.init();
    }
})();
