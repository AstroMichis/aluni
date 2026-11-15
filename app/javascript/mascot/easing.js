// Pure easing helpers for Aluni (app/javascript/mascot/*). Every curve here
// settles without overshoot: plants never bounce. Times are in seconds.
export const clamp = (value, min, max) => Math.min(max, Math.max(min, value))
export const lerp = (a, b, t) => a + (b - a) * t
export const smoothstep = (t) => { const k = clamp(t, 0, 1); return k * k * (3 - 2 * k) }
export const cubicOut = (t) => { const k = 1 - clamp(t, 0, 1); return 1 - k * k * k }
export const cubicInOut = (t) => {
  const k = clamp(t, 0, 1)
  return k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2
}
export const quinticInOut = (t) => {
  const k = clamp(t, 0, 1)
  return k < 0.5 ? 16 * k * k * k * k * k : 1 - Math.pow(-2 * k + 2, 5) / 2
}

// Eased progress of `t` through the window [start, end]: 0 before, 1 after.
export const span = (t, start, end, ease = cubicInOut) => ease((t - start) / Math.max(1e-6, end - start))

// Rise over `attack`, hold for `hold`, fall over `release`: 0..1 for a time
// `t` counted from the start.
export const envelope = (t, attack, hold, release) => {
  if (t <= 0) return 0
  if (t < attack) return cubicOut(t / attack)
  if (t < attack + hold) return 1
  if (t < attack + hold + release) return 1 - cubicInOut((t - attack - hold) / release)
  return 0
}
