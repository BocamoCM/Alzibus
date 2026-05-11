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
    // Live Bus Arrivals (Datos reales en landing)
    // ========================
    const liveTabs = document.querySelectorAll('.live-tab');
    const livePanel = document.getElementById('live-panel');
    let currentStopId = 1;
    let liveRefreshTimer = null;

    function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, c => ({
            '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
        }[c]));
    }

    function lineColor(line) {
        const l = line.toUpperCase();
        if (l.includes('L1')) return '#e63946';
        if (l.includes('L2')) return '#2a9d8f';
        if (l.includes('L3')) return '#f4a261';
        return '#800020';
    }

    async function loadArrivals(stopId, stopName) {
        if (!livePanel) return;
        currentStopId = stopId;
        livePanel.innerHTML = `
            <div class="live-loading">
                <div class="live-spinner"></div>
                <span>Cargando tiempos para ${escapeHtml(stopName)}…</span>
            </div>`;
        try {
            const res = await fetch(`/api/proxy/bus-times?id=${stopId}`);
            if (!res.ok) throw new Error('http ' + res.status);
            const html = await res.text();
            const doc = new DOMParser().parseFromString(html, 'text/html');
            const rows = doc.querySelectorAll('table tr');
            const arrivals = [];
            for (let i = 1; i < rows.length; i++) {
                const cells = rows[i].querySelectorAll('td');
                if (cells.length >= 3) {
                    const line = cells[0].textContent.trim();
                    const dest = cells[1].textContent.trim();
                    const time = cells[2].textContent.trim();
                    if (line && dest && time) arrivals.push({ line, dest, time });
                }
            }

            if (arrivals.length === 0) {
                livePanel.innerHTML = `
                    <div class="live-empty">
                        <span class="live-empty-icon">😴</span>
                        <p>No hay buses programados ahora mismo en <strong>${escapeHtml(stopName)}</strong>.</p>
                        <p class="live-empty-sub">Quizás está fuera del horario de servicio. <a href="https://play.google.com/store/apps/details?id=com.alzitrans.app" target="_blank" rel="noopener noreferrer">Descarga la app</a> para ver los horarios completos.</p>
                    </div>`;
                return;
            }

            const items = arrivals.slice(0, 6).map(a => {
                const c = lineColor(a.line);
                const isImmediate = /</.test(a.time) || /llega/i.test(a.time);
                const timeClass = isImmediate ? 'live-time-imm' : '';
                return `
                <li class="live-item">
                    <span class="live-line" style="background:${c}">${escapeHtml(a.line)}</span>
                    <div class="live-info">
                        <strong>${escapeHtml(a.dest)}</strong>
                        <small>Línea ${escapeHtml(a.line)} → ${escapeHtml(a.dest)}</small>
                    </div>
                    <span class="live-time ${timeClass}">${escapeHtml(a.time)}</span>
                </li>`;
            }).join('');

            livePanel.innerHTML = `
                <div class="live-header">
                    <h3>${escapeHtml(stopName)}</h3>
                    <span class="live-pulse"><span class="dot"></span> En vivo</span>
                </div>
                <ul class="live-list">${items}</ul>
                <p class="live-update">Actualizado a las ${new Date().toLocaleTimeString('es-ES', {hour:'2-digit', minute:'2-digit'})}</p>`;
        } catch (err) {
            console.warn('[Alzitrans] Live arrivals error:', err);
            livePanel.innerHTML = `
                <div class="live-empty">
                    <span class="live-empty-icon">⚠️</span>
                    <p>No se han podido cargar los tiempos ahora mismo.</p>
                    <p class="live-empty-sub">Inténtalo de nuevo en unos segundos o <a href="https://play.google.com/store/apps/details?id=com.alzitrans.app" target="_blank" rel="noopener noreferrer">descarga la app</a>.</p>
                </div>`;
        }
    }

    liveTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            liveTabs.forEach(t => {
                t.classList.remove('active');
                t.setAttribute('aria-selected', 'false');
            });
            tab.classList.add('active');
            tab.setAttribute('aria-selected', 'true');
            const stopId = parseInt(tab.dataset.stop, 10);
            const stopName = tab.dataset.name;
            loadArrivals(stopId, stopName);
        });
    });

    // Carga inicial cuando el bloque entra en pantalla (LCP-friendly)
    const liveSection = document.getElementById('tiempos');
    if (liveSection && liveTabs.length > 0) {
        const firstTab = liveTabs[0];
        const liveObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    loadArrivals(parseInt(firstTab.dataset.stop, 10), firstTab.dataset.name);
                    // Auto-refresh cada 30s mientras la sección esté visible
                    if (!liveRefreshTimer) {
                        liveRefreshTimer = setInterval(() => {
                            const activeTab = document.querySelector('.live-tab.active');
                            if (activeTab && document.visibilityState === 'visible') {
                                loadArrivals(parseInt(activeTab.dataset.stop, 10), activeTab.dataset.name);
                            }
                        }, 30000);
                    }
                    liveObserver.unobserve(liveSection);
                }
            });
        }, { threshold: 0.2 });
        liveObserver.observe(liveSection);
    }

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

    // ========================
    // Contact Form Handler
    // ========================
    const contactForm = document.getElementById('contact-form');
    const btnSubmit = document.getElementById('btn-submit');
    const btnLoader = document.getElementById('loader');
    const formMessage = document.getElementById('form-message');

    if (contactForm) {
        contactForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            // Deshabilitar botón y mostrar loader
            btnSubmit.disabled = true;
            btnSubmit.querySelector('span').style.opacity = '0.4';
            btnLoader.style.display = 'block';
            formMessage.innerHTML = '';
            formMessage.className = 'form-result';

            const formData = {
                name: contactForm.name.value,
                email: contactForm.email.value,
                subject: contactForm.subject.value,
                message: contactForm.message.value,
                website: contactForm.website.value // Honeypot field
            };

            try {
                const response = await fetch('/api/contact', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(formData)
                });

                const result = await response.json();

                if (response.ok) {
                    formMessage.innerHTML = '✅ ¡Mensaje enviado con éxito! Te contactaremos pronto.';
                    formMessage.classList.add('success');
                    contactForm.reset();
                } else {
                    formMessage.innerHTML = `❌ Error: ${result.error || 'No se pudo enviar el mensaje.'}`;
                    formMessage.classList.add('error');
                }
            } catch (err) {
                formMessage.innerHTML = '❌ Error de conexión. Inténtalo de nuevo más tarde.';
                formMessage.classList.add('error');
            } finally {
                btnSubmit.disabled = false;
                btnSubmit.querySelector('span').style.opacity = '1';
                btnLoader.style.display = 'none';
            }
        });
    }
});
