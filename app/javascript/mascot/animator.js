// Drives Aluni's parts frame by frame. States:
//
//   offstage -> entering -> waving -> idle <-> talking -> docking -> docked
//   plus static (nothing moves; the SVG twin is showing instead).
//
// Layers composed in update(dt, elapsed): breathing, leaf sway, blink, glance,
// the gait while entering, the wave, the talk, the dock settle. The controller
// owns the clock, the stage transforms and the events; this file only moves
// the character. All angles are radians, all times seconds.

const TWO_PI = Math.PI * 2
const clamp = (value, min, max) => Math.min(max, Math.max(min, value))
const lerp = (a, b, t) => a + (b - a) * t
const smooth = (t) => { const k = clamp(t, 0, 1); return k * k * (3 - 2 * k) }

export const TALK_MS_PER_CHAR = 28
export const TALK_MIN_MS = 900
export const TALK_MAX_MS = 5000
export const talkDuration = (chars) => clamp((Number(chars) || 0) * TALK_MS_PER_CHAR, TALK_MIN_MS, TALK_MAX_MS)

const BREATH_HZ = 0.25
const BREATH_AMOUNT = 0.02
const SWAY_HZ = 0.5
const SWAY_LEAF = 0.08
const SWAY_ARM = 0.05
const BLINK_SECONDS = 0.14
const BLINK_CLOSED = 0.08
const GLANCE_HOLD = 1.2
const GAIT_HZ = 2.2
const GAIT_FOOT = 0.45
const GAIT_BOB = 0.07
const GAIT_ROLL = 0.05
const WAVE_RAISE = 2.2
const WAVE_SWING = 0.35
const WAVE_TILT = -0.12
const TALK_MOUTH_HZ = 7
const TALK_NOD_HZ = 1.5
const TALK_NOD = 0.04
const DOCK_SETTLE = 0.4

export class Animator {
  constructor(parts, { random = Math.random } = {}) {
    this.parts = parts
    this.random = random
    this.state = "offstage"
    this.pointer = null
    this.time = 0
    this.gait = 0
    this.wave = null
    this.talk = null
    this.dock = null
    this.squash = 1
    this.blink = { countdown: this.between(2, 4), t: -1 }
    this.glance = { countdown: this.between(4, 9), hold: 0, target: { x: 0, y: 0 }, current: { x: 0, y: 0 } }
  }

  between(min, max) { return min + this.random() * (max - min) }

  setState(state) { this.state = state }

  // The stage starts sliding in: gait in place until arrive().
  enter() { this.state = "entering" }

  // The stage has stopped: stop walking, wave, then settle into idle.
  arrive() {
    this.state = "waving"
    this.wave = { t: 0 }
  }

  // Talk for `ms`; returns to the state it interrupted (idle or docked).
  speak(ms) {
    if (!["idle", "talking", "docked", "waving"].includes(this.state)) return
    const returnState = this.state === "talking" ? this.talk.returnState : this.state === "waving" ? "idle" : this.state
    this.wave = null
    this.talk = { t: 0, duration: Math.max(0.1, ms / 1000), returnState }
    this.state = "talking"
  }

  startDock() {
    this.wave = null
    if (this.talk) { this.parts.mouth.open(0); this.talk = null }
    this.state = "docking"
    this.dock = { t: 0 }
  }

  setStatic() { this.state = "static" }

  // Pointer in -1..1 relative to the stage centre, or null when none.
  setPointer(pointer) { this.pointer = pointer }

  update(dt) {
    if (this.state === "static") return
    this.time += dt
    const p = this.parts
    const t = this.time

    // Gait blends in while entering and eases out afterwards.
    const wantGait = this.state === "entering" ? 1 : 0
    this.gait += (wantGait - this.gait) * Math.min(1, dt * 8)
    if (this.gait < 0.001) this.gait = 0
    const stride = Math.sin(TWO_PI * GAIT_HZ * t)
    p.feet[0].rotation.x = GAIT_FOOT * stride * this.gait
    p.feet[1].rotation.x = -GAIT_FOOT * stride * this.gait
    const bob = Math.abs(stride) * GAIT_BOB * this.gait
    const roll = GAIT_ROLL * stride * this.gait

    let tilt = 0
    let nod = 0

    // Leaves and arms sway independently; the right arm may be waving.
    p.leaves.forEach((pivot) => {
      pivot.rotation.z = pivot.userData.rest.z + SWAY_LEAF * Math.sin(TWO_PI * SWAY_HZ * t + pivot.userData.phase)
    })
    p.armLeft.rotation.z = p.armLeft.userData.rest.z + SWAY_ARM * Math.sin(TWO_PI * SWAY_HZ * t + p.armLeft.userData.phase)
    if (this.wave) {
      tilt = this.updateWave(dt)
    } else {
      p.armRight.rotation.z = p.armRight.userData.rest.z + SWAY_ARM * Math.sin(TWO_PI * SWAY_HZ * t + p.armRight.userData.phase)
    }

    if (this.talk) nod = this.updateTalk(dt)
    if (this.dock) this.updateDock(dt)

    this.updateBlink(dt)
    this.updateGlance(dt)

    const breath = 1 + BREATH_AMOUNT * Math.sin(TWO_PI * BREATH_HZ * t)
    p.body.position.y = p.bodyY + bob
    p.body.rotation.set(nod, 0, roll + tilt)
    p.body.scale.set(breath, breath * this.squash, breath)
  }

  // Raise over 0.3 s, three swings over 1.0 s, back over 0.3 s; the head tilts along.
  updateWave(dt) {
    const arm = this.parts.armRight
    const rest = arm.userData.rest.z
    const raised = rest + WAVE_RAISE
    this.wave.t += dt
    const t = this.wave.t
    let envelope
    if (t < 0.3) {
      envelope = smooth(t / 0.3)
      arm.rotation.z = lerp(rest, raised, envelope)
    } else if (t < 1.3) {
      envelope = 1
      arm.rotation.z = raised + WAVE_SWING * Math.sin(TWO_PI * 3 * (t - 0.3))
    } else if (t < 1.6) {
      const k = smooth((t - 1.3) / 0.3)
      envelope = 1 - k
      arm.rotation.z = lerp(raised, rest, k)
    } else {
      arm.rotation.z = rest
      this.wave = null
      if (this.state === "waving") this.state = "idle"
      return 0
    }
    return WAVE_TILT * envelope
  }

  // Mouth opens at 7 Hz with a decaying amplitude; a small nod keeps time.
  updateTalk(dt) {
    this.talk.t += dt
    const u = this.talk.t / this.talk.duration
    if (u >= 1) {
      this.parts.mouth.open(0)
      const next = this.talk.returnState
      this.talk = null
      if (this.state === "talking") this.state = next
      return 0
    }
    const amplitude = lerp(1, 0.35, u)
    this.parts.mouth.open(amplitude * Math.abs(Math.sin(TWO_PI * TALK_MOUTH_HZ * this.talk.t)))
    return TALK_NOD * Math.sin(TWO_PI * TALK_NOD_HZ * this.talk.t) * (1 - smooth((u - 0.85) / 0.15))
  }

  // A short squash as the character lands in its docked spot.
  updateDock(dt) {
    this.dock.t += dt
    const u = this.dock.t / DOCK_SETTLE
    if (u >= 1) {
      this.squash = 1
      this.dock = null
      if (this.state === "docking") this.state = "docked"
      return
    }
    this.squash = 1 - 0.08 * Math.sin(Math.PI * u)
  }

  // Every 3-6 s both eyes close and open over 140 ms.
  updateBlink(dt) {
    const blink = this.blink
    let scale = 1
    if (blink.t < 0) {
      blink.countdown -= dt
      if (blink.countdown <= 0) blink.t = 0
    } else {
      blink.t += dt
      const k = blink.t / BLINK_SECONDS
      if (k >= 1) {
        blink.t = -1
        blink.countdown = this.between(3, 6)
      } else {
        scale = 1 - (1 - BLINK_CLOSED) * Math.sin(Math.PI * k)
      }
    }
    this.parts.eyeMeshes.forEach((eye) => { eye.scale.y = scale })
  }

  // Every 4-9 s the eyes drift toward a random point (or the pointer on
  // desktop), hold 1.2 s and come back.
  updateGlance(dt) {
    const glance = this.glance
    if (glance.hold > 0) {
      glance.hold -= dt
      if (glance.hold <= 0) { glance.target.x = 0; glance.target.y = 0 }
    } else {
      glance.countdown -= dt
      if (glance.countdown <= 0) {
        if (this.pointer) {
          glance.target.x = clamp(this.pointer.x, -1, 1)
          glance.target.y = clamp(this.pointer.y, -1, 1)
        } else {
          glance.target.x = this.between(-1, 1)
          glance.target.y = this.between(-0.6, 0.8)
        }
        glance.hold = GLANCE_HOLD
        glance.countdown = this.between(4, 9)
      }
    }
    const k = 1 - Math.exp(-dt * 6)
    glance.current.x += (glance.target.x - glance.current.x) * k
    glance.current.y += (glance.target.y - glance.current.y) * k
    this.parts.eyes.position.x = glance.current.x * 0.07
    this.parts.eyes.position.y = glance.current.y * 0.045
  }
}
