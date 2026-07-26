export const TRACK_LENGTH = 2600;
export const TOTAL_LAPS = 3;
export const MAX_SPEED = 430;

export const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

export function ordinalSuffix(value) {
  const remainder100 = value % 100;
  if (remainder100 >= 11 && remainder100 <= 13) return "th";
  return { 1: "st", 2: "nd", 3: "rd" }[value % 10] || "th";
}

export function formatTime(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return "00:00.00";
  const minutes = Math.floor(seconds / 60);
  const remaining = seconds - minutes * 60;
  return `${String(minutes).padStart(2, "0")}:${remaining.toFixed(2).padStart(5, "0")}`;
}

export function playerPlace(playerDistance, opponents) {
  return 1 + opponents.filter((opponent) => opponent.distance > playerDistance).length;
}

export function lapForDistance(distance) {
  return clamp(Math.floor(Math.max(0, distance) / TRACK_LENGTH) + 1, 1, TOTAL_LAPS);
}

export function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

export function createTrackObjects(seed = 90477) {
  const random = seededRandom(seed);
  const objects = [];
  const lanes = [-0.72, -0.35, 0, 0.35, 0.72];
  const obstacleTypes = ["box", "spill", "cones"];

  for (let lap = 0; lap < TOTAL_LAPS; lap += 1) {
    for (let distance = 300; distance < TRACK_LENGTH - 120; distance += 170 + random() * 100) {
      const isPickup = random() > 0.67;
      objects.push({
        distance: lap * TRACK_LENGTH + distance,
        lane: lanes[Math.floor(random() * lanes.length)],
        type: isPickup ? "boost" : obstacleTypes[Math.floor(random() * obstacleTypes.length)],
        collected: false,
      });
    }
  }

  return objects;
}
