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
            const response = await fetch('/api/stats/public');
            if (response.ok) {
                const data = await response.json();
                if (data.totalUsers !== undefined) {
                    animateValue(userCountEl, 0, data.totalUsers, 1500);
                }
            }
        } catch (err) {
            console.error('Error fetching user count:', err);
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
