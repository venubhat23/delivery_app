// Voice Commands for Invoice Generation
class VoiceCommandHandler {
  constructor() {
    this.recognition = null;
    this.isListening = false;
    this.isSupported = this.checkBrowserSupport();
    this.init();
  }

  checkBrowserSupport() {
    return 'webkitSpeechRecognition' in window || 'SpeechRecognition' in window;
  }

  init() {
    if (!this.isSupported) {
      console.warn('Speech recognition not supported in this browser');
      return;
    }

    // Initialize Speech Recognition
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    this.recognition = new SpeechRecognition();
    
    // Configure recognition settings
    this.recognition.continuous = false;
    this.recognition.interimResults = false;
    this.recognition.lang = 'en-US';
    this.recognition.maxAlternatives = 1;

    // Event listeners
    this.recognition.onstart = () => {
      this.isListening = true;
      this.updateUI('listening');
      console.log('Voice recognition started');
    };

    this.recognition.onresult = (event) => {
      const command = event.results[0][0].transcript;
      console.log('Voice command received:', command);
      this.processCommand(command);
    };

    this.recognition.onerror = (event) => {
      console.error('Speech recognition error:', event.error);
      this.updateUI('error', `Error: ${event.error}`);
      this.isListening = false;
    };

    this.recognition.onend = () => {
      this.isListening = false;
      this.updateUI('idle');
      console.log('Voice recognition ended');
    };
  }

  startListening() {
    if (!this.isSupported) {
      this.showNotification('Voice recognition not supported in this browser', 'error');
      return;
    }

    if (this.isListening) {
      this.stopListening();
      return;
    }

    try {
      this.recognition.start();
      this.showNotification('🎤 Listening... Say "Generate Monthly for All"', 'info');
    } catch (error) {
      console.error('Error starting recognition:', error);
      this.showNotification('Error starting voice recognition', 'error');
    }
  }

  stopListening() {
    if (this.recognition && this.isListening) {
      this.recognition.stop();
    }
  }

  async processCommand(command) {
    this.updateUI('processing');
    this.showNotification('🔄 Processing command...', 'info');

    try {
      const response = await fetch('/voice_commands/process_command', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ command: command })
      });

      const result = await response.json();
      
      if (result.success) {
        this.showNotification(result.message, 'success');
        
        // Handle redirect if provided
        if (result.redirect_url) {
          setTimeout(() => {
            window.location.href = result.redirect_url;
          }, 2000);
        }
        
        // Show additional details if available
        if (result.details) {
          this.showCommandDetails(result.details);
        }
      } else {
        this.showNotification(result.message, 'warning');
      }
    } catch (error) {
      console.error('Error processing command:', error);
      this.showNotification('❌ Error processing voice command', 'error');
    } finally {
      this.updateUI('idle');
    }
  }

  updateUI(state) {
    const button = document.getElementById('voice-command-btn');
    const status = document.getElementById('voice-status');
    
    if (!button) return;

    switch (state) {
      case 'listening':
        button.classList.add('listening');
        button.innerHTML = '<i class="fas fa-microphone-slash"></i> Stop Listening';
        if (status) status.textContent = '🎤 Listening...';
        break;
      case 'processing':
        button.classList.add('processing');
        button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Processing...';
        if (status) status.textContent = '🔄 Processing...';
        break;
      case 'error':
        button.classList.remove('listening', 'processing');
        button.innerHTML = '<i class="fas fa-microphone"></i> Voice Command';
        if (status) status.textContent = '❌ Error occurred';
        break;
      default: // idle
        button.classList.remove('listening', 'processing');
        button.innerHTML = '<i class="fas fa-microphone"></i> Voice Command';
        if (status) status.textContent = 'Ready for voice commands';
    }
  }

  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `alert alert-${this.getBootstrapClass(type)} alert-dismissible fade show voice-notification`;
    notification.innerHTML = `
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;

    // Add to page
    const container = document.querySelector('.container-fluid') || document.body;
    container.insertBefore(notification, container.firstChild);

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.remove();
      }
    }, 5000);
  }

  showCommandDetails(details) {
    const detailsHtml = `
      <div class="mt-2 small">
        <strong>Details:</strong><br>
        📊 Success: ${details.success_count || 0}<br>
        ⚠️ Failed: ${details.failure_count || 0}<br>
        📅 Month: ${details.month} ${details.year}
      </div>
    `;
    
    // Find the last notification and append details
    const lastNotification = document.querySelector('.voice-notification:last-of-type');
    if (lastNotification) {
      lastNotification.innerHTML += detailsHtml;
    }
  }

  getBootstrapClass(type) {
    const classMap = {
      'success': 'success',
      'error': 'danger',
      'warning': 'warning',
      'info': 'info'
    };
    return classMap[type] || 'info';
  }
}

// Initialize voice commands when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  window.voiceHandler = new VoiceCommandHandler();
  
  // Add event listener to voice command button
  const voiceButton = document.getElementById('voice-command-btn');
  if (voiceButton) {
    voiceButton.addEventListener('click', function(e) {
      e.preventDefault();
      window.voiceHandler.startListening();
    });
  }
});

// Add CSS styles for voice command UI
const voiceStyles = `
<style>
.voice-command-container {
  position: relative;
  display: inline-block;
}

#voice-command-btn {
  transition: all 0.3s ease;
}

#voice-command-btn.listening {
  background-color: #dc3545 !important;
  border-color: #dc3545 !important;
  animation: pulse 1.5s infinite;
}

#voice-command-btn.processing {
  background-color: #ffc107 !important;
  border-color: #ffc107 !important;
  color: #000 !important;
}

@keyframes pulse {
  0% { box-shadow: 0 0 0 0 rgba(220, 53, 69, 0.7); }
  70% { box-shadow: 0 0 0 10px rgba(220, 53, 69, 0); }
  100% { box-shadow: 0 0 0 0 rgba(220, 53, 69, 0); }
}

.voice-notification {
  position: fixed;
  top: 20px;
  right: 20px;
  z-index: 9999;
  max-width: 400px;
  animation: slideIn 0.3s ease-out;
}

@keyframes slideIn {
  from { transform: translateX(100%); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

#voice-status {
  font-size: 0.875rem;
  color: #6c757d;
  margin-top: 5px;
}

.voice-commands-help {
  background: #f8f9fa;
  border-left: 4px solid #007bff;
  padding: 10px 15px;
  margin: 15px 0;
  border-radius: 4px;
}

.voice-commands-help h6 {
  margin-bottom: 8px;
  color: #007bff;
}

.voice-commands-help ul {
  margin-bottom: 0;
  padding-left: 20px;
}
</style>
`;

// Inject styles into the page
document.head.insertAdjacentHTML('beforeend', voiceStyles);