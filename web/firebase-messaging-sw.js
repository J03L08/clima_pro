importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDHOJOzVQIIz4l9vCU4tY_GBKPHcLvnSAs",
  authDomain: "clima-pro-461e1.firebaseapp.com",
  projectId: "clima-pro-461e1",
  messagingSenderId: "1070073098005",
  appId: "1:1070073098005:web:57abe98bcd80293d39831c",
});

const messaging = firebase.messaging();

// Notificaciones en segundo plano
messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Background message recibido:', payload);

  const notificationTitle = payload.notification?.title || 'Nueva notificación';
  const notificationOptions = {
    body: payload.notification?.body || 'Tienes una actualización en ClimaPro.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

/* ============================
   Caché + Offline
   ============================ */

const CACHE_NAME = 'climapro-basic-v1';
const PRECACHE_URLS = [
  '/offline.html',
];

// INSTALACIÓN: cacheamos offline.html
self.addEventListener('install', (event) => {
  console.log('[SW] Install');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS))
  );
  self.skipWaiting();
});

// ACTIVACIÓN: limpiar caches viejos
self.addEventListener('activate', (event) => {
  console.log('[SW] Activate');
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

/* ============================
   IndexedDB para cola de solicitudes
   ============================ */

function abrirDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('climapro-db', 1);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains('solicitudes-pendientes')) {
        db.createObjectStore('solicitudes-pendientes', {
          keyPath: 'id',
          autoIncrement: true,
        });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function guardarSolicitudPendiente(data) {
  const db = await abrirDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction('solicitudes-pendientes', 'readwrite');
    tx.objectStore('solicitudes-pendientes').add({ data });
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function obtenerSolicitudesPendientes() {
  const db = await abrirDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction('solicitudes-pendientes', 'readonly');
    const store = tx.objectStore('solicitudes-pendientes');
    const req = store.getAll();
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function borrarSolicitudPendiente(id) {
  const db = await abrirDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction('solicitudes-pendientes', 'readwrite');
    tx.objectStore('solicitudes-pendientes').delete(id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

/* ============================
   Manejo de nueva solicitud (POST)
   ============================ */

async function manejarNuevaSolicitud(event) {
  const request = event.request;

  const bodyText = await request.clone().text();
  let data;
  try {
    data = JSON.parse(bodyText);
  } catch (e) {
    console.error('[SW] Body de solicitud inválido:', e);
    return new Response(
      JSON.stringify({ ok: false, error: 'Body inválido' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  console.log('[SW] Nueva solicitud enviada:', data);

  try {
    // Mandamos al backend real
    const resp = await fetch('http://localhost:4000/api/solicitudes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    console.log('[SW] Solicitud enviada correctamente al backend');
    return resp;
  } catch (e) {
    // SIN CONEXIÓN: guardamos en cola y registramos Background Sync
    console.warn('[SW] Sin conexión. Guardando solicitud en cola...', e);

    try {
      await guardarSolicitudPendiente(data);
      if ('sync' in self.registration) {
        await self.registration.sync.register('sync-solicitudes');
        console.log('[SW] Sync registrado: sync-solicitudes');
      } else {
        console.warn(
          '[SW] Background Sync no soportado, quedará en cola hasta que se abra la app.'
        );
      }
    } catch (err) {
      console.error('[SW] Error guardando solicitud pendiente:', err);
    }

    return new Response(
      JSON.stringify({ ok: true, offlineQueued: true }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  if (request.url.endsWith('favicon.ico')) {
    return;
  }

  if (request.method === 'POST' && url.pathname === '/api/solicitudes') {
    event.respondWith(manejarNuevaSolicitud(event));
    return;
  }

  if (request.method !== 'GET') return;

  const isNavigationRequest =
    request.mode === 'navigate' ||
    (request.headers.get('accept') || '').includes('text/html');

  // Navegación -> offline.html si no hay red
  if (isNavigationRequest) {
    event.respondWith(
      fetch(request).catch(async () => {
        const cachedOffline = await caches.match('/offline.html');
        if (cachedOffline) return cachedOffline;

        return new Response(
          'Estás sin conexión y no se pudo cargar la página.',
          { status: 503, headers: { 'Content-Type': 'text/plain' } }
        );
      })
    );
    return;
  }

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (!response || response.type === 'opaque' || response.bodyUsed) {
          return response;
        }
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
        return response;
      })
      .catch(() => caches.match(request))
  );
});

/* ============================
   Evento de sincronización en segundo plano
   ============================ */

self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-solicitudes') {
    console.log('[SW] Evento sync disparado: sync-solicitudes');
    
    event.waitUntil(
      (async () => {
        const pendientes = await obtenerSolicitudesPendientes();
        console.log('[SW] Reenviando solicitudes pendientes:', pendientes);

        for (const item of pendientes) {
          try {
            const resp = await fetch('http://localhost:4000/api/solicitudes', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(item.data),
            });

            console.log('[SW] Solicitud reenviada al backend con status:', resp.status);

            // Si la solicitud se envió correctamente, eliminarla de la cola:
            if (resp.ok) {
              await borrarSolicitudPendiente(item.id);
            } else {
              console.warn('[SW] Backend respondió con error, deteniendo reintentos.');
              break;
            }

          } catch (e) {
            console.error('[SW] Error reenviando solicitud pendiente:', e);
            // Si falló la conexión nuevamente, detener loop — Chrome intentará otro sync más tarde
            break;
          }
        }
      })()
    );
  }
});