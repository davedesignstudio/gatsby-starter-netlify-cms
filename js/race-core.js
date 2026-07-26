(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.RaceCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function wrapDistance(value, length) {
    return ((value % length) + length) % length;
  }

  function ordinal(value) {
    const tens = value % 100;
    if (tens >= 11 && tens <= 13) return `${value}th`;
    const suffix = value % 10 === 1 ? "st" : value % 10 === 2 ? "nd" : value % 10 === 3 ? "rd" : "th";
    return `${value}${suffix}`;
  }

  function formatTime(milliseconds) {
    const safeTime = Math.max(0, Number(milliseconds) || 0);
    const totalHundredths = Math.floor(safeTime / 10);
    const minutes = Math.floor(totalHundredths / 6000);
    const seconds = Math.floor((totalHundredths % 6000) / 100);
    const hundredths = totalHundredths % 100;
    return `${minutes}:${String(seconds).padStart(2, "0")}.${String(hundredths).padStart(2, "0")}`;
  }

  function projectRoadPoint(distance, horizonY, bottomY, roadTopWidth, roadBottomWidth, centerX) {
    const depth = clamp(1 - distance, 0, 1);
    const eased = depth * depth;
    return {
      y: horizonY + (bottomY - horizonY) * eased,
      width: roadTopWidth + (roadBottomWidth - roadTopWidth) * eased,
      scale: 0.12 + 0.88 * eased,
      centerX,
    };
  }

  function laneToX(lane, roadPoint) {
    return roadPoint.centerX + clamp(lane, -1.2, 1.2) * roadPoint.width * 0.36;
  }

  function hitTest(playerLane, objectLane, relativeDistance, laneTolerance, distanceTolerance) {
    return (
      Math.abs(playerLane - objectLane) <= (laneTolerance || 0.28) &&
      relativeDistance >= 0 &&
      relativeDistance <= (distanceTolerance || 32)
    );
  }

  function calculatePlace(playerProgress, opponents) {
    return 1 + opponents.reduce(function (ahead, opponent) {
      return ahead + (opponent.progress > playerProgress ? 1 : 0);
    }, 0);
  }

  return {
    clamp,
    wrapDistance,
    ordinal,
    formatTime,
    projectRoadPoint,
    laneToX,
    hitTest,
    calculatePlace,
  };
});
