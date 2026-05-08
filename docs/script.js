// ============================================
// Probe IT - Interactive JavaScript
// ============================================

document.addEventListener('DOMContentLoaded', function() {
    // Initialize Highlight.js for code syntax highlighting
    document.querySelectorAll('code').forEach(block => {
        hljs.highlightElement(block);
    });

    // Initialize scroll animations
    initScrollAnimations();
    
    // Smooth scroll for navigation links
    initSmoothScroll();
});

// ============================================
// Scroll Animations with Intersection Observer
// ============================================

function initScrollAnimations() {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -100px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                // Trigger animation
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
                
                // Remove observer after animation completes
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe all fade-in elements
    document.querySelectorAll('.fade-in').forEach(element => {
        observer.observe(element);
    });

    // Observe section headers
    document.querySelectorAll('.section-header').forEach(element => {
        observer.observe(element);
    });
}

// ============================================
// Smooth Scroll for Navigation Links
// ============================================

function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const href = this.getAttribute('href');
            
            // Skip if href is just "#"
            if (href === '#') return;
            
            e.preventDefault();
            const target = document.querySelector(href);
            
            if (target) {
                const offsetTop = target.offsetTop - 80; // Account for sticky nav
                
                window.scrollTo({
                    top: offsetTop,
                    behavior: 'smooth'
                });
                
                // Update active nav item
                updateActiveNav(href);
            }
        });
    });
}

// ============================================
// Update Active Navigation Item
// ============================================

function updateActiveNav(targetId) {
    // Remove active state from all nav items
    document.querySelectorAll('.nav-menu a').forEach(link => {
        link.style.opacity = '0.7';
    });
    
    // Add active state to current nav item
    const activeLink = document.querySelector(`a[href="${targetId}"]`);
    if (activeLink) {
        activeLink.style.opacity = '1';
    }
}

// ============================================
// Enhanced Scroll Event Handler
// ============================================

let scrollTimeout;
let isScrolling = false;

window.addEventListener('scroll', () => {
    if (!isScrolling) {
        isScrolling = true;
        updateNavOnScroll();
    }
    
    // Debounce scroll events
    clearTimeout(scrollTimeout);
    scrollTimeout = setTimeout(() => {
        isScrolling = false;
    }, 100);
});

function updateNavOnScroll() {
    const sections = document.querySelectorAll('[id^="overview"], [id^="architecture"], [id^="engine"], [id^="concurrency"], [id^="code"], [id^="testing"]');
    let currentSection = '';
    
    sections.forEach(section => {
        const sectionTop = section.offsetTop - 100;
        const sectionBottom = sectionTop + section.offsetHeight;
        const scrollPos = window.scrollY;
        
        if (scrollPos >= sectionTop && scrollPos < sectionBottom) {
            currentSection = section.getAttribute('id');
        }
    });
    
    if (currentSection) {
        updateActiveNav(`#${currentSection}`);
    }
}

// ============================================
// Parallax Effect on Hero Section
// ============================================

const heroSection = document.querySelector('.hero');

if (heroSection) {
    window.addEventListener('scroll', () => {
        const scrollY = window.scrollY;
        const parallaxElements = heroSection.querySelectorAll('.hero-content');
        
        parallaxElements.forEach(element => {
            element.style.transform = `translateY(${scrollY * 0.3}px)`;
            element.style.opacity = Math.max(1 - (scrollY / 800), 0.5);
        });
    });
}

// ============================================
// Card Hover Animation
// ============================================

document.querySelectorAll('.bento-card').forEach(card => {
    card.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-8px) scale(1.02)';
    });
    
    card.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0) scale(1)';
    });
});

// ============================================
// Dynamic Section Highlight
// ============================================

function highlightCurrentSection() {
    const sections = document.querySelectorAll('.section');
    const navLinks = document.querySelectorAll('.nav-menu a');
    
    sections.forEach(section => {
        const sectionId = section.getAttribute('id');
        const sectionTop = section.offsetTop - 150;
        const sectionBottom = sectionTop + section.offsetHeight;
        
        if (window.scrollY >= sectionTop && window.scrollY < sectionBottom) {
            navLinks.forEach(link => {
                link.style.color = 'var(--text-secondary)';
                link.style.fontWeight = '500';
            });
            
            const activeLink = document.querySelector(`a[href="#${sectionId}"]`);
            if (activeLink) {
                activeLink.style.color = 'var(--text-primary)';
                activeLink.style.fontWeight = '600';
            }
        }
    });
}

window.addEventListener('scroll', highlightCurrentSection);

// ============================================
// Code Copy Functionality
// ============================================

function addCopyButtonsToCodeBlocks() {
    document.querySelectorAll('.code-card pre').forEach((preBlock, index) => {
        // Create wrapper for code block
        const wrapper = document.createElement('div');
        wrapper.style.position = 'relative';
        preBlock.parentNode.insertBefore(wrapper, preBlock);
        wrapper.appendChild(preBlock);
        
        // Create copy button
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-btn';
        copyButton.textContent = 'Copy';
        copyButton.style.cssText = `
            position: absolute;
            top: 8px;
            right: 8px;
            padding: 6px 12px;
            background: rgba(0, 212, 255, 0.1);
            border: 1px solid rgba(0, 212, 255, 0.3);
            border-radius: 6px;
            color: var(--neon-blue);
            cursor: pointer;
            font-size: 0.8rem;
            font-weight: 600;
            transition: all 0.3s ease;
            z-index: 10;
        `;
        
        copyButton.addEventListener('mouseenter', function() {
            this.style.background = 'rgba(0, 212, 255, 0.2)';
            this.style.borderColor = 'rgba(0, 212, 255, 0.5)';
        });
        
        copyButton.addEventListener('mouseleave', function() {
            this.style.background = 'rgba(0, 212, 255, 0.1)';
            this.style.borderColor = 'rgba(0, 212, 255, 0.3)';
        });
        
        copyButton.addEventListener('click', function() {
            const code = preBlock.querySelector('code').textContent;
            navigator.clipboard.writeText(code).then(() => {
                const originalText = copyButton.textContent;
                copyButton.textContent = 'Copied!';
                copyButton.style.color = '#10b981';
                
                setTimeout(() => {
                    copyButton.textContent = originalText;
                    copyButton.style.color = 'var(--neon-blue)';
                }, 2000);
            });
        });
        
        wrapper.appendChild(copyButton);
    });
}

// Initialize copy buttons when DOM is ready
document.addEventListener('DOMContentLoaded', addCopyButtonsToCodeBlocks);

// ============================================
// Fade In On Load
// ============================================

function triggerInitialAnimations() {
    const cards = document.querySelectorAll('.bento-card');
    
    cards.forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(30px)';
        
        setTimeout(() => {
            card.style.transition = 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
            card.style.opacity = '1';
            card.style.transform = 'translateY(0)';
        }, 100 + (index * 50));
    });
}

window.addEventListener('load', triggerInitialAnimations);

// ============================================
// Keyboard Navigation
// ============================================

document.addEventListener('keydown', (e) => {
    // Skip navigation for Ctrl/Cmd key combinations
    if (e.ctrlKey || e.metaKey) return;
    
    const navLinks = Array.from(document.querySelectorAll('.nav-menu a'));
    const currentIndex = navLinks.findIndex(link => {
        const href = link.getAttribute('href');
        return window.location.hash === href;
    });
    
    if (e.key === 'ArrowRight' && currentIndex < navLinks.length - 1) {
        navLinks[currentIndex + 1].click();
    } else if (e.key === 'ArrowLeft' && currentIndex > 0) {
        navLinks[currentIndex - 1].click();
    }
});

// ============================================
// Mobile Menu - Scroll Behavior
// ============================================

function handleMobileScroll() {
    const navbar = document.querySelector('.navbar');
    let lastScrollTop = 0;
    
    window.addEventListener('scroll', () => {
        const currentScroll = window.scrollY;
        
        if (currentScroll <= 0) {
            navbar.style.boxShadow = '0 2px 8px var(--shadow-light)';
        } else {
            navbar.style.boxShadow = '0 4px 12px rgba(0, 212, 255, 0.1)';
        }
        
        lastScrollTop = currentScroll <= 0 ? 0 : currentScroll;
    });
}

handleMobileScroll();

// ============================================
// Performance Monitoring
// ============================================

if ('PerformanceObserver' in window) {
    try {
        const observer = new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
                if (entry.duration > 100) {
                    console.warn('Long task detected:', entry.name, entry.duration + 'ms');
                }
            }
        });
        observer.observe({ entryTypes: ['longtask'] });
    } catch (e) {
        // Long task API may not be available in all browsers
    }
}

// ============================================
// Accessibility Enhancements
// ============================================

document.addEventListener('keydown', (e) => {
    // Tab key: cycle through interactive elements
    if (e.key === 'Tab') {
        const interactiveElements = document.querySelectorAll('a, button');
        const focusedElement = document.activeElement;
        const elementArray = Array.from(interactiveElements);
        const currentIndex = elementArray.indexOf(focusedElement);
        
        if (e.shiftKey && currentIndex === 0) {
            e.preventDefault();
            elementArray[elementArray.length - 1].focus();
        }
    }
});

// ============================================
// Theme Persistence (Light theme maintained)
// ============================================

function initTheme() {
    // Always use light theme
    document.documentElement.style.colorScheme = 'light';
}

document.addEventListener('DOMContentLoaded', initTheme);

// ============================================
// Viewport-based Animations
// ============================================

const animateOnScroll = () => {
    const elements = document.querySelectorAll('.bento-card, .section-header');
    
    elements.forEach(element => {
        const elementTop = element.getBoundingClientRect().top;
        const elementBottom = element.getBoundingClientRect().bottom;
        
        if (elementTop < window.innerHeight && elementBottom > 0) {
            element.style.opacity = '1';
        }
    });
};

window.addEventListener('scroll', animateOnScroll);
window.addEventListener('load', animateOnScroll);
