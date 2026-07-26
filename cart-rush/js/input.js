export function createInput(root) {
  const state = {
    steer: 0,
    gas: false,
    brake: false,
    useItem: false,
    keys: new Set(),
  };

  const isCoarse = window.matchMedia("(pointer: coarse)").matches;

  function syncFromKeys() {
    let steer = 0;
    if (state.keys.has("ArrowLeft") || state.keys.has("a") || state.keys.has("A")) steer -= 1;
    if (state.keys.has("ArrowRight") || state.keys.has("d") || state.keys.has("D")) steer += 1;
    if (!isTouchingSteer) state.steer = steer;
    state.gas = state.keys.has("ArrowUp") || state.keys.has("w") || state.keys.has("W") || touchingGas;
    state.brake = state.keys.has("ArrowDown") || state.keys.has("s") || state.keys.has("S") || state.keys.has("Shift") || touchingBrake;
  }

  window.addEventListener("keydown", (e) => {
    state.keys.add(e.key);
    if (e.key === " " || e.key === "Spacebar") {
      e.preventDefault();
      state.useItem = true;
    }
    syncFromKeys();
  });
  window.addEventListener("keyup", (e) => {
    state.keys.delete(e.key);
    syncFromKeys();
  });

  let isTouchingSteer = false;
  let touchingGas = false;
  let touchingBrake = false;

  const steerEl = root.querySelector("#steer");
  const knob = root.querySelector("#steerKnob");
  const gasBtn = root.querySelector("#gas");
  const brakeBtn = root.querySelector("#brake");
  const itemBox = root.querySelector("#itemBox");

  function setKnob(dx, dy) {
    const max = 36;
    const dist = Math.hypot(dx, dy);
    const scale = dist > max ? max / dist : 1;
    knob.style.transform = `translate(${dx * scale}px, ${dy * scale}px)`;
  }

  function onSteer(clientX, clientY) {
    const rect = steerEl.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const dx = clientX - cx;
    const dy = clientY - cy;
    state.steer = Math.max(-1, Math.min(1, dx / 50));
    setKnob(dx, dy);
  }

  function endSteer() {
    isTouchingSteer = false;
    state.steer = 0;
    setKnob(0, 0);
    syncFromKeys();
  }

  if (steerEl) {
    steerEl.addEventListener("pointerdown", (e) => {
      isTouchingSteer = true;
      steerEl.setPointerCapture(e.pointerId);
      onSteer(e.clientX, e.clientY);
    });
    steerEl.addEventListener("pointermove", (e) => {
      if (!isTouchingSteer) return;
      onSteer(e.clientX, e.clientY);
    });
    steerEl.addEventListener("pointerup", endSteer);
    steerEl.addEventListener("pointercancel", endSteer);
  }

  function bindHold(btn, flag) {
    if (!btn) return;
    const down = (e) => {
      e.preventDefault();
      if (flag === "gas") touchingGas = true;
      if (flag === "brake") touchingBrake = true;
      syncFromKeys();
    };
    const up = () => {
      if (flag === "gas") touchingGas = false;
      if (flag === "brake") touchingBrake = false;
      syncFromKeys();
    };
    btn.addEventListener("pointerdown", down);
    btn.addEventListener("pointerup", up);
    btn.addEventListener("pointerleave", up);
    btn.addEventListener("pointercancel", up);
  }

  bindHold(gasBtn, "gas");
  bindHold(brakeBtn, "brake");

  if (itemBox) {
    itemBox.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      state.useItem = true;
    });
  }

  // Show touch controls on coarse pointers
  const touch = root.querySelector("#touch");
  if (touch && isCoarse) touch.classList.remove("hidden");

  return {
    state,
    consumeUseItem() {
      if (!state.useItem) return false;
      state.useItem = false;
      return true;
    },
    showTouch(show) {
      if (!touch) return;
      touch.classList.toggle("hidden", !show || !isCoarse);
    },
  };
}
