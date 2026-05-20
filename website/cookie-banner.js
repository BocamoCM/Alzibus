/*
 * cookie-banner.js — Banner GDPR/RGPD para alzitrans.es
 * ─────────────────────────────────────────────────────────
 * Sin dependencias. Vanilla JS. ~5 KB minificable.
 *
 * Funcionalidad:
 *   - Si no hay consentimiento previo, muestra banner abajo.
 *   - 3 botones: "Aceptar todas" / "Rechazar opcionales" / "Configurar".
 *   - Modal de configuración con toggles por categoría.
 *   - Persiste decisión en localStorage.
 *   - Carga el script de Google AdSense SOLO si el usuario aceptó
 *     marketing cookies (GDPR-compliant).
 *
 * Para reabrir el banner desde la UI (footer "configurar cookies"):
 *   window.alzitransCookies.open();
 */

(function () {
    'use strict';

    const STORAGE_KEY = 'alzitrans-cookie-consent-v1';
    const ADSENSE_PUB_ID = 'ca-pub-8010840037570750';

    // ─── Storage helpers ─────────────────────────────────────────────
    function getConsent() {
        try {
            const raw = localStorage.getItem(STORAGE_KEY);
            return raw ? JSON.parse(raw) : null;
        } catch (e) {
            return null;
        }
    }

    function setConsent(consent) {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify({
                essential: true,
                analytics: !!consent.analytics,
                marketing: !!consent.marketing,
                timestamp: new Date().toISOString(),
                version: 1,
            }));
        } catch (e) { /* no-op si está disabled */ }
    }

    // ─── Carga condicional del script de AdSense ─────────────────────
    function loadAdSense() {
        if (window.__alziAdSenseLoaded) return;
        window.__alziAdSenseLoaded = true;
        const s = document.createElement('script');
        s.async = true;
        s.crossOrigin = 'anonymous';
        s.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' + ADSENSE_PUB_ID;
        document.head.appendChild(s);
    }

    // ─── Banner UI ───────────────────────────────────────────────────
    function buildBanner() {
        if (document.getElementById('alzitrans-cookie-banner')) return;

        const banner = document.createElement('div');
        banner.id = 'alzitrans-cookie-banner';
        banner.setAttribute('role', 'dialog');
        banner.setAttribute('aria-label', 'Consentimiento de cookies');
        banner.innerHTML = `
            <div class="alzi-banner-content">
                <div class="alzi-banner-text">
                    <h3>🍪 Usamos cookies</h3>
                    Alzitrans usa cookies propias y de terceros (Google AdSense)
                    para que la web funcione bien y para mostrar anuncios
                    relevantes. Puedes aceptarlas todas, rechazar las opcionales
                    o configurar qué permites.
                    <a href="/legal/cookies.html" target="_blank" rel="noopener">
                        Política de cookies
                    </a>
                </div>
                <div class="alzi-banner-buttons">
                    <button class="alzi-btn-config" type="button">Configurar</button>
                    <button class="alzi-btn-reject" type="button">Rechazar opcionales</button>
                    <button class="alzi-btn-accept" type="button">Aceptar todas</button>
                </div>
            </div>
        `;
        document.body.appendChild(banner);

        banner.querySelector('.alzi-btn-accept').addEventListener('click', () => {
            setConsent({ analytics: true, marketing: true });
            removeBanner();
            loadAdSense();
        });
        banner.querySelector('.alzi-btn-reject').addEventListener('click', () => {
            setConsent({ analytics: false, marketing: false });
            removeBanner();
        });
        banner.querySelector('.alzi-btn-config').addEventListener('click', () => {
            removeBanner();
            buildModal(getConsent() || { analytics: false, marketing: false });
        });
    }

    function removeBanner() {
        const el = document.getElementById('alzitrans-cookie-banner');
        if (el) el.remove();
    }

    // ─── Modal de configuración ──────────────────────────────────────
    function buildModal(current) {
        if (document.getElementById('alzitrans-cookie-modal')) return;

        const modal = document.createElement('div');
        modal.id = 'alzitrans-cookie-modal';
        modal.setAttribute('role', 'dialog');
        modal.setAttribute('aria-modal', 'true');
        modal.innerHTML = `
            <div class="alzi-modal-card">
                <h2>Configurar cookies</h2>
                <p>Elige qué cookies aceptas. Las esenciales son obligatorias
                   para que la web funcione. Las demás son opcionales.</p>

                <div class="alzi-cookie-row">
                    <div>
                        <strong>Esenciales</strong>
                        <p>Necesarias para que la web funcione (preferencia
                           de idioma, consentimiento guardado, etc.).</p>
                    </div>
                    <div class="alzi-switch on disabled" aria-label="Esenciales (obligatorias)"></div>
                </div>

                <div class="alzi-cookie-row">
                    <div>
                        <strong>Analítica</strong>
                        <p>Nos ayudan a entender cómo se usa la web para
                           mejorarla. Anonimizadas.</p>
                    </div>
                    <div class="alzi-switch ${current.analytics ? 'on' : ''}"
                         data-key="analytics" role="switch"
                         aria-checked="${current.analytics ? 'true' : 'false'}"></div>
                </div>

                <div class="alzi-cookie-row">
                    <div>
                        <strong>Marketing (Google AdSense)</strong>
                        <p>Permiten mostrar anuncios relevantes y medir su
                           efectividad. Google podrá usar tus datos según
                           su política.</p>
                    </div>
                    <div class="alzi-switch ${current.marketing ? 'on' : ''}"
                         data-key="marketing" role="switch"
                         aria-checked="${current.marketing ? 'true' : 'false'}"></div>
                </div>

                <div class="alzi-modal-buttons">
                    <button class="alzi-btn-save" type="button">Guardar selección</button>
                    <button class="alzi-btn-save-all" type="button">Aceptar todas</button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        // Switch toggle logic
        modal.querySelectorAll('.alzi-switch[data-key]').forEach((sw) => {
            sw.addEventListener('click', () => {
                sw.classList.toggle('on');
                sw.setAttribute('aria-checked', sw.classList.contains('on') ? 'true' : 'false');
            });
        });

        // Save selection
        modal.querySelector('.alzi-btn-save').addEventListener('click', () => {
            const analytics = modal.querySelector('[data-key="analytics"]').classList.contains('on');
            const marketing = modal.querySelector('[data-key="marketing"]').classList.contains('on');
            setConsent({ analytics, marketing });
            removeModal();
            if (marketing) loadAdSense();
        });

        // Save all
        modal.querySelector('.alzi-btn-save-all').addEventListener('click', () => {
            setConsent({ analytics: true, marketing: true });
            removeModal();
            loadAdSense();
        });

        // Cerrar al click fuera de la card
        modal.addEventListener('click', (e) => {
            if (e.target === modal) removeModal();
        });
    }

    function removeModal() {
        const el = document.getElementById('alzitrans-cookie-modal');
        if (el) el.remove();
    }

    // ─── Inicialización ──────────────────────────────────────────────
    function init() {
        const consent = getConsent();
        if (consent) {
            // Ya tiene decisión guardada
            if (consent.marketing) loadAdSense();
        } else {
            // Primera visita o sin decisión: mostrar banner
            buildBanner();
        }
    }

    // ─── API pública para reabrir desde footer ──────────────────────
    window.alzitransCookies = {
        open: function () {
            buildModal(getConsent() || { analytics: false, marketing: false });
        },
        reset: function () {
            try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
            location.reload();
        },
    };

    // Esperar a DOMContentLoaded si aún no está listo
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
