// Smooth, aperiodic drift for idle motion: three sines at irrational ratios
// never line up, so nothing ticks like a metronome. `seed` offsets the phases
// so parts move independently of each other; `speed` is radians per second.
const PHI = 1.6180339887
const SILVER = 2.4142135624

export function drift(t, seed = 0, speed = 1) {
  const a = t * speed
  const s = seed * 1.7
  return 0.5 * Math.sin(a + s) + 0.3 * Math.sin(PHI * a + 2.1 * s) + 0.2 * Math.sin(SILVER * a + 3.3 * s)
}

// The positive half of drift: syllable-like pulses for the tip's light.
export function pulse(t, seed = 0, speed = 1) {
  return Math.max(0, drift(t, seed, speed))
}
