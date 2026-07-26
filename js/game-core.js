export const TOTAL_LAPS = 2;

export const RACERS = [
  {
    name: "JAY “FIXIT” REED",
    shortName: "Jay",
    number: "07",
    emoji: "🧢",
    color: "#53d6a8",
    accent: "#ffd541",
    bio: "Bike mechanic, master tinkerer, and the fastest set of hands on Harbor Street.",
    stats: { speed: 82, grip: 68, boost: 74 },
  },
  {
    name: "REINA “ROCKET” CRUZ",
    shortName: "Reina",
    number: "23",
    emoji: "🧣",
    color: "#ff725f",
    accent: "#ffe45e",
    bio: "Community-kitchen organizer, born navigator, and a fearless late-braker rebuilding her next chapter.",
    stats: { speed: 74, grip: 91, boost: 65 },
  },
  {
    name: "OTIS “BEATBOX” KING",
    shortName: "Otis",
    number: "11",
    emoji: "🎧",
    color: "#4e81ff",
    accent: "#ff8b6a",
    bio: "Former delivery driver, mixtape maker, and steady hand who always knows the quickest route.",
    stats: { speed: 69, grip: 75, boost: 94 },
  },
];

export const AI_RACERS = [
  { name: "Reina", color: "#ff725f", emoji: "🧣", pace: 0.91 },
  { name: "Otis", color: "#4e81ff", emoji: "🎧", pace: 0.88 },
  { name: "Mo", color: "#a77bee", emoji: "🧤", pace: 0.86 },
];

export const POWER_UPS = [
  { id: "boost", icon: "⚡", name: "COFFEE BOOST" },
  { id: "shield", icon: "🫧", name: "BUBBLE SHIELD" },
  { id: "magnet", icon: "🧲", name: "CART MAGNET" },
];

export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function wrapProgress(progress) {
  return ((progress % 1) + 1) % 1;
}

export function ordinal(place) {
  const suffixes = ["TH", "ST", "ND", "RD"];
  const mod100 = place % 100;
  return `${place}${suffixes[(mod100 - 20) % 10] || suffixes[mod100] || suffixes[0]}`;
}

export function formatTime(milliseconds) {
  const safe = Math.max(0, milliseconds);
  const minutes = Math.floor(safe / 60000);
  const seconds = Math.floor((safe % 60000) / 1000);
  const hundredths = Math.floor((safe % 1000) / 10);
  return `${minutes}:${String(seconds).padStart(2, "0")}.${String(hundredths).padStart(2, "0")}`;
}

export function raceScore(racer) {
  return racer.lap + wrapProgress(racer.progress);
}

export function calculatePosition(player, opponents) {
  const playerScore = raceScore(player);
  return 1 + opponents.filter((opponent) => raceScore(opponent) > playerScore).length;
}

export function advanceProgress(racer, delta) {
  const previous = racer.progress;
  racer.progress = wrapProgress(previous + delta);
  if (delta > 0 && racer.progress < previous) racer.lap += 1;
  return racer;
}

export function createRaceState(racerIndex = 0) {
  const racer = RACERS[racerIndex] || RACERS[0];
  return {
    phase: "countdown",
    elapsed: 0,
    countdown: 3.6,
    player: {
      name: racer.shortName,
      color: racer.color,
      emoji: racer.emoji,
      progress: 0.018,
      lap: 0,
      lane: 0,
      speed: 0,
      boost: 0,
      shield: 0,
      item: null,
      maxSpeed: 0.102 + racer.stats.speed * 0.00034,
      acceleration: 0.055,
      grip: 1.4 + racer.stats.grip * 0.012,
      boostPower: 0.045 + racer.stats.boost * 0.00025,
    },
    opponents: AI_RACERS.map((ai, index) => ({
      ...ai,
      progress: wrapProgress(0.006 - index * 0.014),
      lap: index === 0 ? 0 : -1,
      lane: [-30, 28, 2][index],
      speed: 0.108 + ai.pace * 0.022,
    })),
    collected: new Set(),
    lastLapAt: 0,
    lapTimes: [],
    position: 1,
  };
}

export function updatePlayer(state, input, dt) {
  const player = state.player;
  const gas = input.gas ? 1 : 0;
  const target = gas ? player.maxSpeed : player.maxSpeed * 0.48;
  const response = gas ? player.acceleration : 0.025;
  player.speed += clamp(target - player.speed, -response * dt, response * dt);

  if (player.boost > 0) {
    player.speed += player.boostPower * dt;
    player.boost = Math.max(0, player.boost - dt);
  }
  player.speed = clamp(player.speed, 0, player.maxSpeed + player.boostPower);

  const steer = (input.right ? 1 : 0) - (input.left ? 1 : 0);
  player.lane = clamp(player.lane + steer * player.grip * 47 * dt, -55, 55);
  if (!steer) player.lane *= Math.pow(0.996, dt * 60);
  if (Math.abs(player.lane) > 48) player.speed *= Math.pow(0.982, dt * 60);

  advanceProgress(player, player.speed * dt);
  return state;
}

export function updateOpponents(state, dt) {
  state.opponents.forEach((opponent, index) => {
    const wobble = Math.sin(state.elapsed * (0.7 + index * 0.09) + index * 2) * 20;
    opponent.lane += (wobble - opponent.lane) * dt * 0.45;
    const rubberBand = opponent.lap + opponent.progress < state.player.lap + state.player.progress - 0.16 ? 1.08 : 1;
    advanceProgress(opponent, opponent.speed * rubberBand * dt);
  });
  state.position = calculatePosition(state.player, state.opponents);
  return state;
}

export function usePowerUp(state) {
  const item = state.player.item;
  if (!item) return null;
  if (item === "boost") state.player.boost = Math.max(state.player.boost, 2.2);
  if (item === "shield") state.player.shield = 6;
  if (item === "magnet") state.player.boost = Math.max(state.player.boost, 1.4);
  state.player.item = null;
  return item;
}
