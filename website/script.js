document.addEventListener('DOMContentLoaded', () => {

    // ========================
    // Smooth scrolling
    // ========================
    document.querySelectorAll('a[href^="#"]').forEach(link => {
        link.addEventListener('click', e => {
            e.preventDefault();
            const target = document.querySelector(link.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

    // ========================
    // telemetry (Visits & Clicks)
    // ========================
    async function sendTelemetry(eventType) {
        try {
            fetch('/api/metrics/web', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ event_type: eventType })
            });
        } catch (err) { }
    }

    // Registrar visita
    sendTelemetry('visit');

    // Registrar clics en descarga
    document.querySelectorAll('a[href*="play.google.com"]').forEach(link => {
        link.addEventListener('click', () => sendTelemetry('download_click'));
    });

    // ========================
    // Scroll-triggered animations
    // ========================
    const animatedElements = document.querySelectorAll('[data-animate], .feature-row');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.15,
        rootMargin: '0px 0px -60px 0px'
    });

    animatedElements.forEach(el => observer.observe(el));

    // ========================
    // Fetch User Count from API
    // ========================
    const userCountEl = document.getElementById('user-count');
    async function fetchUserCount() {
        if (!userCountEl) return;
        try {
            console.log('[Alzitrans] Fetching live users...');
            const response = await fetch('/api/stats/public');
            if (response.ok) {
                const data = await response.json();
                console.log('[Alzitrans] Users found:', data.totalUsers);
                if (data.totalUsers !== undefined) {
                    console.log('[Alzitrans] Starting animation for:', data.totalUsers);
                    userCountEl.innerHTML = `+0`; // Reset from ...
                    animateValue(userCountEl, 0, data.totalUsers, 1500);
                } else {
                    userCountEl.innerHTML = '+25'; // Fallback sensible
                }
            } else {
                console.warn('[Alzitrans] API response not ok:', response.status);
                userCountEl.innerHTML = '+40';
            }
        } catch (err) {
            console.error('[Alzitrans] Error fetching user count:', err);
            userCountEl.innerHTML = '+40'; // Fallback si el API no responde
        }
    }

    function animateValue(obj, start, end, duration) {
        let startTimestamp = null;
        const step = (timestamp) => {
            if (!startTimestamp) startTimestamp = timestamp;
            const progress = Math.min((timestamp - startTimestamp) / duration, 1);
            const value = Math.floor(progress * (end - start) + start);
            obj.innerHTML = `+${value}`;
            if (progress < 1) {
                window.requestAnimationFrame(step);
            }
        };
        window.requestAnimationFrame(step);
    }

    fetchUserCount();

    // ========================
    // Navbar background on scroll
    // ========================
    const navbar = document.getElementById('navbar');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 80) {
            navbar.style.background = 'rgba(10, 10, 15, 0.95)';
        } else {
            navbar.style.background = 'rgba(10, 10, 15, 0.7)';
        }
    });

    // ========================
    // Phone tilt on mouse move (desktop)
    // ========================
    document.querySelectorAll('.feature-row').forEach(row => {
        const phone = row.querySelector('.phone-3d .phone-frame');
        if (!phone) return;

        row.addEventListener('mousemove', (e) => {
            const rect = row.getBoundingClientRect();
            const x = (e.clientX - rect.left) / rect.width - 0.5;
            const y = (e.clientY - rect.top) / rect.height - 0.5;

            const rotateY = x * 20;
            const rotateX = -y * 10;

            phone.style.animationPlayState = 'paused';
            phone.style.transform = `perspective(800px) rotateY(${rotateY}deg) rotateX(${rotateX}deg) scale(1.02)`;
        });

        row.addEventListener('mouseleave', () => {
            phone.style.animationPlayState = 'running';
            phone.style.transform = '';
        });
    });
});
