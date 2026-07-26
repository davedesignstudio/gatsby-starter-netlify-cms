(() => {
  // Segmented arcade track. Each segment has length + curve amount.
  // Curve: negative = left bend, positive = right bend.
  const SEGS = [
    { len: 40, curve: 0, theme: "entrance" },
    { len: 35, curve: 0, theme: "aisle" },
    { len: 45, curve: -2.4, theme: "produce" },
    { len: 30, curve: -3.2, theme: "produce" },
    { len: 40, curve: 0, theme: "dairy" },
    { len: 50, curve: 2.8, theme: "freezer" },
    { len: 35, curve: 3.0, theme: "freezer" },
    { len: 40, curve: 0, theme: "aisle" },
    { len: 45, curve: -1.8, theme: "checkout" },
    { len: 35, curve: 2.2, theme: "checkout" },
    { len: 50, curve: 0, theme: "aisle" },
    { len: 40, curve: -2.6, theme: "bakery" },
    { len: 45, curve: 2.5, theme: "bakery" },
    { len: 55, curve: 0, theme: "entrance" },
  ];

  const themes = {
    entrance: { road: "#3a3f45", edge: "#f0b429", wallL: "#6b4f3a", wallR: "#6b4f3a", shelf: "#8a6a4a" },
    aisle: { road: "#3d4248", edge: "#e23a2e", wallL: "#2f6f78", wallR: "#2f6f78", shelf: "#1f4f56" },
    produce: { road: "#3a4638", edge: "#3f8f4e", wallL: "#4f8f3e", wallR: "#6aa84f", shelf: "#3d6f30" },
    dairy: { road: "#3e464c", edge: "#c5d4d8", wallL: "#8fa4ad", wallR: "#8fa4ad", shelf: "#6f848c" },
    freezer: { road: "#33444a", edge: "#6ec4c8", wallL: "#4f7f8a", wallR: "#4f7f8a", shelf: "#3a6068" },
    checkout: { road: "#403a36", edge: "#f0b429", wallL: "#8a3a32", wallR: "#8a3a32", shelf: "#6a2a24" },
    bakery: { road: "#463f36", edge: "#d9a441", wallL: "#8a6a3a", wallR: "#8a6a3a", shelf: "#6a5030" },
  };

  let total = 0;
  const cumulative = SEGS.map((s) => {
    const start = total;
    total += s.len;
    return { ...s, start, end: total };
  });

  function sample(z) {
    const pos = ((z % total) + total) % total;
    for (const s of cumulative) {
      if (pos >= s.start && pos < s.end) {
        return {
          curve: s.curve,
          theme: themes[s.theme] || themes.aisle,
          name: s.theme,
          pos,
        };
      }
    }
    return { curve: 0, theme: themes.aisle, name: "aisle", pos };
  }

  // Soft curve ahead for camera lean / road projection
  function curveAhead(z, look = 18) {
    let sum = 0;
    for (let i = 0; i < look; i++) sum += sample(z + i).curve;
    return sum / look;
  }

  window.TRACK = {
    length: total,
    sample,
    curveAhead,
    themes,
  };
})();
