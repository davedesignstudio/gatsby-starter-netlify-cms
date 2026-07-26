/** Grocery-store race track — tile map + waypoints */
(function () {
  const TILE = 48;
  const W = 42;
  const H = 32;

  // 0 floor, 1 shelf/wall, 2 start line, 3 item crate spawn, 4 produce bump
  // Hand-authored MegaMart loop (outer ring + inner island shelves)
  const rows = [];
  for (let y = 0; y < H; y++) {
    const row = [];
    for (let x = 0; x < W; x++) {
      let t = 0;
      const edge = x < 2 || y < 2 || x >= W - 2 || y >= H - 2;
      if (edge) t = 1;
      // Inner shelf island
      if (x >= 12 && x <= 29 && y >= 10 && y <= 21) {
        const hole =
          (x >= 14 && x <= 27 && y >= 12 && y <= 19) ||
          (x >= 18 && x <= 23 && (y === 10 || y === 11 || y === 20 || y === 21));
        if (!hole) t = 1;
        // Open gates on left/right of island for flow
        if ((x === 12 || x === 29) && y >= 14 && y <= 17) t = 0;
      }
      // Aisle dividers (broken so you can race around)
      if (y === 6 && x >= 6 && x <= 18) t = 1;
      if (y === 6 && x >= 24 && x <= 35) t = 1;
      if (y === 25 && x >= 6 && x <= 18) t = 1;
      if (y === 25 && x >= 24 && x <= 35) t = 1;
      if (x === 6 && y >= 8 && y <= 12) t = 1;
      if (x === 35 && y >= 8 && y <= 12) t = 1;
      if (x === 6 && y >= 19 && y <= 23) t = 1;
      if (x === 35 && y >= 19 && y <= 23) t = 1;

      // Produce bumps (slow pads)
      if ((x === 9 && y === 4) || (x === 32 && y === 4) || (x === 9 && y === 27) || (x === 32 && y === 27)) {
        if (t === 0) t = 4;
      }
      if ((x === 20 && y === 8) || (x === 21 && y === 23)) {
        if (t === 0) t = 4;
      }

      row.push(t);
    }
    rows.push(row);
  }

  // Start/finish across bottom straight
  for (let x = 15; x <= 26; x++) {
    if (rows[H - 4][x] === 0) rows[H - 4][x] = 2;
  }

  // Item crates along racing line
  const crateSpots = [
    [8, 8], [10, 15], [8, 22],
    [20, 4], [28, 8], [33, 15], [28, 22], [20, 27],
    [15, 15], [26, 16],
  ];
  crateSpots.forEach(([x, y]) => {
    if (rows[y][x] === 0) rows[y][x] = 3;
  });

  // Clockwise waypoints around the store (progress / AI)
  const waypoints = [
    { x: 20.5 * TILE, y: (H - 3.5) * TILE },
    { x: 30 * TILE, y: (H - 3.5) * TILE },
    { x: 37 * TILE, y: 24 * TILE },
    { x: 37 * TILE, y: 16 * TILE },
    { x: 37 * TILE, y: 8 * TILE },
    { x: 30 * TILE, y: 4.5 * TILE },
    { x: 20 * TILE, y: 4.5 * TILE },
    { x: 10 * TILE, y: 4.5 * TILE },
    { x: 4.5 * TILE, y: 8 * TILE },
    { x: 4.5 * TILE, y: 16 * TILE },
    { x: 4.5 * TILE, y: 24 * TILE },
    { x: 10 * TILE, y: (H - 3.5) * TILE },
  ];

  function tileAt(px, py) {
    const tx = Math.floor(px / TILE);
    const ty = Math.floor(py / TILE);
    if (tx < 0 || ty < 0 || tx >= W || ty >= H) return 1;
    return rows[ty][tx];
  }

  function isWall(px, py) {
    return tileAt(px, py) === 1;
  }

  function solidAt(px, py, radius) {
    const samples = [
      [0, 0],
      [radius, 0],
      [-radius, 0],
      [0, radius],
      [0, -radius],
      [radius * 0.7, radius * 0.7],
      [-radius * 0.7, radius * 0.7],
      [radius * 0.7, -radius * 0.7],
      [-radius * 0.7, -radius * 0.7],
    ];
    for (const [dx, dy] of samples) {
      if (isWall(px + dx, py + dy)) return true;
    }
    return false;
  }

  function drawFloor(ctx, camX, camY, viewW, viewH) {
    const x0 = Math.max(0, Math.floor(camX / TILE) - 1);
    const y0 = Math.max(0, Math.floor(camY / TILE) - 1);
    const x1 = Math.min(W, Math.ceil((camX + viewW) / TILE) + 1);
    const y1 = Math.min(H, Math.ceil((camY + viewH) / TILE) + 1);

    for (let ty = y0; ty < y1; ty++) {
      for (let tx = x0; tx < x1; tx++) {
        const t = rows[ty][tx];
        const x = tx * TILE;
        const y = ty * TILE;

        if (t === 1) {
          // Shelf
          ctx.fillStyle = "#4a3228";
          ctx.fillRect(x, y, TILE, TILE);
          ctx.fillStyle = "#6b4a3a";
          ctx.fillRect(x + 4, y + 4, TILE - 8, 10);
          ctx.fillStyle = "#3d281e";
          ctx.fillRect(x + 4, y + 18, TILE - 8, 8);
          ctx.fillRect(x + 4, y + 32, TILE - 8, 8);
          // Product dots
          ctx.fillStyle = ["#e8452f", "#f0c419", "#2bb3ff", "#6dbf4b"][(tx + ty) % 4];
          ctx.beginPath();
          ctx.arc(x + 14, y + 9, 3, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = ["#f0c419", "#2bb3ff", "#6dbf4b", "#e8452f"][(tx + ty + 1) % 4];
          ctx.beginPath();
          ctx.arc(x + 28, y + 9, 3, 0, Math.PI * 2);
          ctx.fill();
        } else {
          // Floor tiles
          const checker = (tx + ty) % 2 === 0;
          ctx.fillStyle = checker ? "#d8c9a8" : "#cfc0a0";
          ctx.fillRect(x, y, TILE, TILE);
          // Subtle grout
          ctx.strokeStyle = "rgba(90, 70, 40, 0.15)";
          ctx.strokeRect(x + 0.5, y + 0.5, TILE - 1, TILE - 1);

          if (t === 2) {
            // Start/finish checkers
            const cell = 8;
            for (let i = 0; i < TILE / cell; i++) {
              for (let j = 0; j < TILE / cell; j++) {
                if ((i + j) % 2 === 0) {
                  ctx.fillStyle = "#1a1a1a";
                  ctx.fillRect(x + i * cell, y + j * cell, cell, cell);
                } else {
                  ctx.fillStyle = "#f7f3ea";
                  ctx.fillRect(x + i * cell, y + j * cell, cell, cell);
                }
              }
            }
          } else if (t === 4) {
            // Produce spill
            ctx.fillStyle = "rgba(109, 191, 75, 0.45)";
            ctx.beginPath();
            ctx.ellipse(x + TILE / 2, y + TILE / 2, 16, 12, 0, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "#e8452f";
            ctx.beginPath();
            ctx.arc(x + 18, y + 22, 4, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = "#f0c419";
            ctx.beginPath();
            ctx.arc(x + 30, y + 26, 3.5, 0, Math.PI * 2);
            ctx.fill();
          }
        }
      }
    }
  }

  function drawDecor(ctx) {
    // Overhead aisle signs (world space)
    const signs = [
      { x: 8 * TILE, y: 3 * TILE, label: "PRODUCE" },
      { x: 30 * TILE, y: 3 * TILE, label: "DAIRY" },
      { x: 8 * TILE, y: 28 * TILE, label: "FROZEN" },
      { x: 30 * TILE, y: 28 * TILE, label: "SNACKS" },
    ];
    signs.forEach((s) => {
      ctx.fillStyle = "rgba(26, 58, 42, 0.85)";
      ctx.fillRect(s.x - 36, s.y - 10, 72, 22);
      ctx.strokeStyle = "#f0c419";
      ctx.lineWidth = 2;
      ctx.strokeRect(s.x - 36, s.y - 10, 72, 22);
      ctx.fillStyle = "#f0c419";
      ctx.font = "bold 11px Space Grotesk, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(s.label, s.x, s.y + 5);
    });
  }

  window.Track = {
    TILE,
    W,
    H,
    width: W * TILE,
    height: H * TILE,
    rows,
    waypoints,
    tileAt,
    isWall,
    solidAt,
    drawFloor,
    drawDecor,
    startPositions() {
      // Grid on start line facing +x then curve — face toward right (angle 0)
      const baseY = (H - 3.2) * TILE;
      const baseX = 14 * TILE;
      return [
        { x: baseX, y: baseY - 28, angle: 0 },
        { x: baseX - 40, y: baseY + 8, angle: 0 },
        { x: baseX - 80, y: baseY - 28, angle: 0 },
        { x: baseX - 120, y: baseY + 8, angle: 0 },
        { x: baseX - 160, y: baseY - 28, angle: 0 },
        { x: baseX - 200, y: baseY + 8, angle: 0 },
      ];
    },
  };
})();
