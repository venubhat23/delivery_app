// Production-Ready Sidebar JavaScript
// This file provides essential sidebar functionality

(function() {
  'use strict';
  
  // Wait for DOM to be ready
  function ready(fn) {
    if (document.readyState !== 'loading') {
      fn();
    } else {
      document.addEventListener('DOMContentLoaded', fn);
    }
  }
  
  ready(function() {
    // Get DOM elements
    var sidebarToggle = document.getElementById('sidebarToggle');
    var sidebar = document.getElementById('sidebar');
    var sidebarOverlay = document.getElementById('sidebarOverlay');
    var body = document.body;
    
    // State
    var sidebarOpen = false;
    
    // Toggle sidebar function
    function toggleSidebar() {
      sidebarOpen = !sidebarOpen;
      
      if (sidebarOpen) {
        if (sidebar) sidebar.classList.add('show');
        if (sidebarOverlay) sidebarOverlay.classList.add('show');
        body.style.overflow = 'hidden';
        if (sidebarToggle) sidebarToggle.setAttribute('aria-expanded', 'true');
      } else {
        if (sidebar) sidebar.classList.remove('show');
        if (sidebarOverlay) sidebarOverlay.classList.remove('show');
        body.style.overflow = '';
        if (sidebarToggle) sidebarToggle.setAttribute('aria-expanded', 'false');
      }
    }
    
    // Close sidebar function
    function closeSidebar() {
      if (sidebarOpen) {
        sidebarOpen = false;
        if (sidebar) sidebar.classList.remove('show');
        if (sidebarOverlay) sidebarOverlay.classList.remove('show');
        body.style.overflow = '';
        if (sidebarToggle) sidebarToggle.setAttribute('aria-expanded', 'false');
      }
    }
    
    // Event listeners
    if (sidebarToggle) {
      sidebarToggle.addEventListener('click', function(e) {
        e.preventDefault();
        toggleSidebar();
      });
    }
    
    if (sidebarOverlay) {
      sidebarOverlay.addEventListener('click', function() {
        closeSidebar();
      });
    }
    
    // Close sidebar on escape key
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && sidebarOpen) {
        closeSidebar();
      }
    });
    
    // Handle window resize
    var resizeTimer;
    window.addEventListener('resize', function() {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function() {
        if (window.innerWidth >= 768 && sidebarOpen) {
          closeSidebar();
        }
      }, 250);
    });
    
    // Initialize ARIA attributes
    if (sidebarToggle) {
      sidebarToggle.setAttribute('aria-expanded', 'false');
      sidebarToggle.setAttribute('aria-controls', 'sidebar');
    }
    
    // Add focus management for accessibility
    var navLinks = sidebar ? sidebar.querySelectorAll('.nav-link') : [];
    for (var i = 0; i < navLinks.length; i++) {
      navLinks[i].addEventListener('focus', function() {
        if (window.innerWidth < 768 && !sidebarOpen) {
          toggleSidebar();
        }
      });
    }
    
    // Add loading states for navigation links
    for (var i = 0; i < navLinks.length; i++) {
      navLinks[i].addEventListener('click', function() {
        this.classList.add('loading');
        
        var self = this;
        setTimeout(function() {
          self.classList.remove('loading');
        }, 3000);
      });
    }
    
    // Handle page visibility changes
    document.addEventListener('visibilitychange', function() {
      if (document.hidden && sidebarOpen && window.innerWidth < 768) {
        closeSidebar();
      }
    });
    
    // Add scroll shadow effect
    if (sidebar) {
      sidebar.addEventListener('scroll', function() {
        if (this.scrollTop > 10) {
          this.style.boxShadow = 'inset 0 10px 10px -10px rgba(0,0,0,0.1)';
        } else {
          this.style.boxShadow = '';
        }
      });
    }
    
    console.log('Sidebar initialized successfully');
  });
  
})();