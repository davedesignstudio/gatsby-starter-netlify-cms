(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.CartDashCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
  }

  function lerp(from, to, amount) {
    return from + (to - from) * amount;
  }

  function wrap(value, length) {
    return ((value % length) + length) % length;
  }

  function forwardDistance(from, to, length) {
    return wrap(to - from, length);
  }

  function ordinal(value) {
    const tens = value % 100;
    if (tens >= 11 && tens <= 13) return `${value}th`;
    switch (value % 10) {
      case 1:
        return `${value}st`;
      case 2:
        return `${value}nd`;
      case 3:
        return `${value}rd`;
      default:
        return `${value}th`;
    }
  }

  function formatTime(milliseconds) {
    if (!Number.isFinite(milliseconds) || milliseconds < 0) return "--:--.--";
    const totalHundredths = Math.floor(milliseconds / 10);
    const hundredths = totalHundredths % 100;
    const seconds = Math.floor(totalHundredths / 100) % 60;
    const minutes = Math.floor(totalHundredths / 6000);
    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}.${String(hundredths).padStart(2, "0")}`;
  }

  function calculateRank(playerDistance, rivals) {
    return 1 + rivals.filter((rival) => rival.distance > playerDistance).length;
  }

  function seededRandom(seed) {
    let state = seed >>> 0;
    return function random() {
      state = (state * 1664525 + 1013904223) >>> 0;
      return state / 4294967296;
    };
  }

  return {
    clamp,
    lerp,
    wrap,
    forwardDistance,
    ordinal,
    formatTime,
    calculateRank,
    seededRandom,
  };
});
