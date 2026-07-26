var CACHE = "aisle-rush-v1";
var ASSETS = [
  "/",
  "/index.html",
  "/css/cart-racer.css",
  "/js/game-core.js",
  "/js/cart-racer.js",
  "/manifest.webmanifest",
  "/images/cart-racer-icon.svg",
];

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      return cache.addAll(ASSETS);
    }).then(function () {
      return self.skipWaiting();
    })
  );
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (key) {
        return key !== CACHE;
      }).map(function (key) {
        return caches.delete(key);
      }));
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener("fetch", function (event) {
  if (event.request.method !== "GET") return;
  event.respondWith(
    caches.match(event.request).then(function (cached) {
      return cached || fetch(event.request).then(function (response) {
        if (!response || response.status !== 200 || response.type === "opaque") return response;
        var copy = response.clone();
        caches.open(CACHE).then(function (cache) {
          cache.put(event.request, copy);
        });
        return response;
      });
    }).catch(function () {
      return caches.match("/index.html");
    })
  );
});
