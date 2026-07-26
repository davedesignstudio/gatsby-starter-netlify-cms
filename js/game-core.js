(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.CartCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function lerp(from, to, amount) {
    return from + (to - from) * amount;
  }

  function ordinal(value) {
    var tens = value % 100;
    if (tens >= 11 && tens <= 13) return "TH";
    return value % 10 === 1 ? "ST" : value % 10 === 2 ? "ND" : value % 10 === 3 ? "RD" : "TH";
  }

  function formatTime(seconds) {
    var safe = Math.max(0, seconds || 0);
    var minutes = Math.floor(safe / 60);
    var remainder = safe - minutes * 60;
    return minutes + ":" + remainder.toFixed(2).padStart(5, "0");
  }

  function racePosition(playerDistance, opponentDistances) {
    return 1 + opponentDistances.filter(function (distance) {
      return distance > playerDistance;
    }).length;
  }

  function forwardDistance(from, to, lapLength) {
    var distance = (to - from) % lapLength;
    return distance < 0 ? distance + lapLength : distance;
  }

  function seededRandom(seed) {
    var value = seed >>> 0;
    return function () {
      value += 0x6d2b79f5;
      var result = value;
      result = Math.imul(result ^ (result >>> 15), result | 1);
      result ^= result + Math.imul(result ^ (result >>> 7), result | 61);
      return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
    };
  }

  return {
    clamp: clamp,
    lerp: lerp,
    ordinal: ordinal,
    formatTime: formatTime,
    racePosition: racePosition,
    forwardDistance: forwardDistance,
    seededRandom: seededRandom,
  };
});
