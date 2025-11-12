// App Launch Notification Handler for Atma Nirbhar Farm Page

class AppLaunchHandler {
    constructor() {
        this.isProcessing = false;
        this.initializeLaunchButton();
    }

    initializeLaunchButton() {
        // Wait for DOM to be ready
        document.addEventListener('DOMContentLoaded', () => {
            this.addLaunchButtonHandler();
        });
    }

    addLaunchButtonHandler() {
        // Find the Launch Software ribbon button
        const launchButton = document.querySelector('.ribbon-inaugurate-button');

        if (launchButton) {
            // Add click event listener
            launchButton.addEventListener('click', (e) => {
                // Don't prevent the original ceremony functionality
                // Just add our WhatsApp notification functionality
                setTimeout(() => {
                    this.sendAppLaunchNotifications();
                }, 5000); // Send after 5 seconds of ceremony start
            });

            console.log('🚀 App Launch Handler initialized');
        }
    }

    async sendAppLaunchNotifications() {
        if (this.isProcessing) {
            console.log('⏳ Notification sending already in progress...');
            return;
        }

        this.isProcessing = true;

        try {
            console.log('📱 Starting to send app launch notifications...');

            // Show a subtle notification to user
            this.showNotification('Sending app notifications to customers...', 'info');

            // Make API call to send notifications
            const response = await fetch('/send-app-launch-notifications', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': this.getCSRFToken()
                },
                body: JSON.stringify({
                    source: 'atma_nirbhar_launch_page'
                })
            });

            const result = await response.json();

            if (result.success) {
                console.log('✅ App launch notifications sent successfully!');
                console.log(`📊 Total: ${result.total_customers}, Success: ${result.success_count}, Failed: ${result.failure_count}`);

                this.showNotification(
                    `App notifications sent! ${result.success_count}/${result.total_customers} customers notified.`,
                    'success'
                );
            } else {
                console.error('❌ Failed to send app launch notifications:', result.message);
                this.showNotification('Failed to send notifications: ' + result.message, 'error');
            }

        } catch (error) {
            console.error('💥 Error sending app launch notifications:', error);
            this.showNotification('Error sending notifications. Please try again.', 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    showNotification(message, type = 'info') {
        // Create a subtle notification element
        const notification = document.createElement('div');
        notification.className = `app-launch-notification app-launch-notification-${type}`;
        notification.textContent = message;

        // Add styles
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: ${type === 'success' ? '#4caf50' : type === 'error' ? '#f44336' : '#2196f3'};
            color: white;
            padding: 12px 24px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 500;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            z-index: 10000;
            max-width: 300px;
            opacity: 0;
            transition: opacity 0.3s ease;
        `;

        document.body.appendChild(notification);

        // Fade in
        setTimeout(() => {
            notification.style.opacity = '1';
        }, 100);

        // Auto remove after 5 seconds
        setTimeout(() => {
            notification.style.opacity = '0';
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        }, 5000);
    }

    getCSRFToken() {
        const token = document.querySelector('meta[name="csrf-token"]');
        return token ? token.getAttribute('content') : '';
    }
}

// Initialize the handler
window.appLaunchHandler = new AppLaunchHandler();

// Also expose a manual trigger function for testing
window.triggerAppLaunchNotifications = () => {
    if (window.appLaunchHandler) {
        window.appLaunchHandler.sendAppLaunchNotifications();
    }
};