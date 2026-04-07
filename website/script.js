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
