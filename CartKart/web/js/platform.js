const ua = navigator.userAgent || '';

export const isAndroid = /Android/i.test(ua);
export const isMobile = isAndroid || /iPhone|iPad|iPod|Mobile/i.test(ua) || (navigator.maxTouchPoints > 1 && window.innerWidth < 1024);
export const prefersReducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches ?? false;

export function getPixelRatio() {
  const dpr = window.devicePixelRatio || 1;
  if (prefersReducedMotion) return 1;
  if (isAndroid) return Math.min(dpr, 1.5);
  if (isMobile) return Math.min(dpr, 2);
  return Math.min(dpr, 2);
}

export function getSafeInsets() {
  const style = getComputedStyle(document.documentElement);
  return {
    top: parseFloat(style.getPropertyValue('--sat')) || 0,
    right: parseFloat(style.getPropertyValue('--sar')) || 0,
    bottom: parseFloat(style.getPropertyValue('--sab')) || 0,
    left: parseFloat(style.getPropertyValue('--sal')) || 0,
  };
}

export class WakeLock {
  constructor() {
    this.lock = null;
  }

  async request() {
    if (!('wakeLock' in navigator)) return;
    try {
      this.lock = await navigator.wakeLock.request('screen');
      this.lock.addEventListener('release', () => { this.lock = null; });
    } catch {
      this.lock = null;
    }
  }

  async release() {
    try {
      await this.lock?.release();
    } catch {
      /* ignore */
    }
    this.lock = null;
  }
}

export async function lockLandscape() {
  try {
    await screen.orientation?.lock?.('landscape');
  } catch {
    /* unsupported or needs fullscreen */
  }
}

export async function unlockOrientation() {
  try {
    await screen.orientation?.unlock?.();
  } catch {
    /* ignore */
  }
}

export function vibrate(pattern) {
  if (isMobile && navigator.vibrate) navigator.vibrate(pattern);
}
