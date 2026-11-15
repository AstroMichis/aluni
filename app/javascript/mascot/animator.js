// Drives Aluni's parts frame by frame. States:
//
//   seed -> sprouting -> idle <-> speaking -> docking -> docked
//   idle -> retracting -> travelling -> emerging -> idle   (the root travel)
//   offstage / entering -> idle (mode "landing": the stage slides, the plant idles)
//   plus static (nothing moves; the SVG twin is showing instead).
//
// Growth is a continuous value g in 0..3 (growthPose): 0 a closed seed on the
// soil, 0.5 just germinated (what the landing shows after the sprout), 1 the
// cotyledons open (pin placed), 2 the first true leaves (crop chosen), 3 the
// roots showing (field saved). setStage(n) eases g there. Layers composed in
// update(dt): the growth or the running transition, the greeting (a lean and a
// dip of the apex toward the viewer), the speech (leaves lift and flutter, the
// tip glows in syllables and nods with each one), the dock lean, the attend
// lean (phototropism toward a target: the apex turns first, the base follows)
// and the idle drift, under which the apex traces the slow ellipse a real
// seedling does as it grows (circumnutation), so the tip light is never quite
// still. Wakefulness runs under all of it: with someone around (the pointer
// moving, a target, speech) the leaves stand up; after a while of nothing they
// droop and the light dims, and they perk up again the moment something
// happens. Nothing here overshoots; the controller owns the clock, the stage
// box and the events.
import { clamp, lerp, cubicOut, cubicInOut, quinticInOut, span, envelope } from "mascot/easing"
import { drift, pulse } from "mascot/noise"

export const TALK_MS_PER_CHAR = 28
export const TALK_MIN_MS = 900
export const TALK_MAX_MS = 5000
export const talkDuration = (chars) => clamp((Number(chars) || 0) * TALK_MS_PER_CHAR, TALK_MIN_MS, TALK_MAX_MS)

export const SPROUT_SECONDS = 2.8
export const RETRACT_SECONDS = 1.0
export const EMERGE_SECONDS = 1.2
export const GROW_SECONDS = 2.4
const GREET_SECONDS = 1.6
const DOCK_SECONDS = 0.7
const ATTEND_HOLD = 4
const ATTEND_TAU = 0.6
const RELAX_TAU = 1.8
const TIP_TAU = 0.25
const POINTER_WEIGHT = 1
const AWAKE_HOLD = 12
const WAKE_TAU = 0.6
const DROWSE_TAU = 3
const DROOP = 0.22
const PERK_SECONDS = 1.2
const GLOW_BASE = 0.3
const SWAY_Z = 0.035
const SWAY_X = 0.02
const WOBBLE = 0.02
const DOCKED_SCALE = 0.6
const LEAN_Z = 0.3
const LEAN_X = 0.1
const LEAN_YAW = 0.6
const REST_TILT = 0.12
const STEM_LEAN = 0.55
const TIP_LEAN_Y = 0.25
const GREET_DIP = 0.14
const SPEAK_NOD = 0.11
// Circumnutation: the apex circles once every NUTATION_PERIOD seconds, a few
// pixels wide on screen. Real seedlings take an hour or two; Aluni is quicker.
const NUTATION_X = 0.12
const NUTATION_Z = 0.08
const NUTATION_PERIOD = 11
const SPEAK_STATES = ["idle", "speaking", "docked", "entering", "offstage"]

// The plant's pose for a growth value g in 0..3.
export function growthPose(g) {
  const k = clamp(g, 0, 3)
  if (k <= 0.5) {
    const u = k / 0.5
    return {
      seedOpen: cubicOut(u), seedSink: 0,
      stemLength: 0.8 * cubicInOut(u), hook: 1 - span(u, 0.5, 1, quinticInOut),
      cotCurl: lerp(1, 0.55, span(u, 0.7, 1, cubicOut)), cotScale: lerp(0.35, 0.8, span(u, 0.4, 1)),
      trueCurl: 1, trueScale: 0, roots: 0, glow: span(u, 0.8, 1)
    }
  }
  if (k <= 1) {
    const u = (k - 0.5) * 2
    return {
      seedOpen: 1, seedSink: 0, stemLength: lerp(0.8, 1.25, u), hook: 0,
      cotCurl: lerp(0.55, 0, u), cotScale: lerp(0.8, 1, u),
      trueCurl: 1, trueScale: 0, roots: 0, glow: 1
    }
  }
  if (k <= 2) {
    const u = k - 1
    return {
      seedOpen: 1, seedSink: 0, stemLength: lerp(1.25, 1.6, u), hook: 0,
      cotCurl: 0, cotScale: 1,
      trueCurl: lerp(1, 0.1, u), trueScale: cubicOut(u), roots: 0, glow: 1
    }
  }
  const u = k - 2
  return {
    seedOpen: 1, seedSink: u, stemLength: lerp(1.6, 1.65, u), hook: 0,
    cotCurl: 0, cotScale: 1,
    trueCurl: lerp(0.1, 0.05, u), trueScale: 1, roots: u, glow: 1
  }
}

// The germination script, t in seconds from 0 to SPROUT_SECONDS: the coat
// cracks, the hook pushes up, straightens, the cotyledons part, the tip lights.
export function sproutPose(t) {
  return {
    seedOpen: span(t, 0.4, 1.2, cubicOut), seedSink: 0,
    stemLength: 0.8 * span(t, 0.8, 2.0, cubicInOut),
    hook: 1 - span(t, 1.7, 2.5, quinticInOut),
    cotCurl: lerp(1, 0.55, span(t, 2.1, 2.8, cubicOut)),
    cotScale: lerp(0.35, 0.8, span(t, 1.4, 2.7)),
    trueCurl: 1, trueScale: 0, roots: 0,
    glow: span(t, 2.4, 2.8)
  }
}

// Folding back into the soil from the pose `from`, u in 0..RETRACT_SECONDS.
function retractPose(from, u) {
  const curlK = span(u, 0, 0.6)
  const lengthK = span(u, 0.3, 1.0, cubicInOut)
  const sinkK = span(u, 0.5, 1.0)
  const rootsK = span(u, 0.2, 0.7)
  const glowK = span(u, 0, 0.6)
  return {
    seedOpen: from.seedOpen, seedSink: lerp(from.seedSink, 1, sinkK),
    stemLength: from.stemLength * (1 - lengthK), hook: lerp(from.hook, 0.4, lengthK),
    cotCurl: lerp(from.cotCurl, 1, curlK), cotScale: from.cotScale * (1 - 0.6 * lengthK),
    trueCurl: lerp(from.trueCurl, 1, curlK), trueScale: from.trueScale * (1 - 0.6 * lengthK),
    roots: from.roots * (1 - rootsK), glow: from.glow * (1 - glowK)
  }
}

// Growing out again toward `target` (growthPose(g)), u in 0..EMERGE_SECONDS.
function emergePose(target, u) {
  return {
    seedOpen: 1, seedSink: lerp(1, target.seedSink, span(u, 0.1, 0.5)),
    stemLength: target.stemLength * span(u, 0.2, 1.0, cubicOut), hook: 0,
    cotCurl: lerp(1, target.cotCurl, span(u, 0.5, 1.2, cubicOut)),
    cotScale: target.cotScale * lerp(0.3, 1, span(u, 0.2, 0.9, cubicOut)),
    trueCurl: lerp(1, target.trueCurl, span(u, 0.6, 1.2, cubicOut)),
    trueScale: target.trueScale * span(u, 0.5, 1.2, cubicOut),
    roots: target.roots * span(u, 0.7, 1.2), glow: target.glow * span(u, 0.9, 1.2)
  }
}

export class Animator {
  constructor(parts, { random = Math.random } = {}) {
    this.parts = parts
    this.random = random
    this.state = "seed"
    this.time = 0
    this.motion = 1
    this.g = 0
    this.growth = null
    this.sprouting = null
    this.retracting = null
    this.emerging = null
    this.talk = null
    this.greet = null
    this.dock = null
    this.dockDirection = 1
    this.pointer = null
    this.attendTarget = null
    this.attendHold = 0
    // The base lean and the apex: both ease toward the same target, the apex faster.
    this.lean = { x: 0, y: 0 }
    this.tip = { x: 0, y: 0 }
    // Wakefulness 0..1 and the moment of noticing someone again (perk).
    this.awake = 1
    this.lastActivity = 0
    this.perk = null
    this.restYaw = parts.plant.rotation.y
    this.currentPose = growthPose(0)
    this.render(this.currentPose, { soil: 1, stemLean: null, cotLift: 0, trueLift: 0, flutter: 0, wobbleAmp: 0, glow: 0 })
  }

  setState(state) { this.state = state }

  // mode "landing": the stage slides in while the plant idles.
  enter() { this.state = "entering" }

  // The preloader: germination from the closed seed. Returns the duration in ms.
  sprout() {
    this.state = "sprouting"
    this.g = 0
    this.growth = null
    if (!this.motion) { this.g = 0.5; this.state = "idle"; return 0 }
    this.sprouting = { t: 0 }
    return SPROUT_SECONDS * 1000
  }

  // The stage has settled in its corner: a short greeting (a lean and a dip of
  // the apex toward the viewer, the cotyledons lift, the tip brightens once).
  arrive() {
    if (["entering", "offstage", "seed"].includes(this.state)) this.state = "idle"
    if (this.motion) this.greet = { t: 0 }
    this.notice()
  }

  // Speak for `ms`; returns to the state it interrupted (idle or docked).
  speak(ms) {
    if (!SPEAK_STATES.includes(this.state)) return
    let returnState = this.state
    if (this.state === "speaking") returnState = this.talk.returnState
    else if (this.state === "entering" || this.state === "offstage") returnState = "idle"
    this.greet = null
    this.talk = { t: 0, duration: Math.max(0.1, ms / 1000), returnState }
    this.state = "speaking"
    this.notice()
  }

  // Growth stage 0..3 (fractions allowed); eased unless immediate.
  setStage(stage, { immediate = false } = {}) {
    const target = clamp(Number(stage) || 0, 0, 3)
    if (immediate || !this.motion) {
      this.g = target
      this.growth = null
      return
    }
    if (Math.abs(target - this.g) < 1e-4) { this.growth = null; return }
    this.growth = { from: this.g, to: target, t: 0 }
    this.notice()
  }

  // Fold back into the soil (the root travel starts). Returns the duration in ms.
  retract() {
    if (this.state === "travelling" || this.retracting) return 0
    this.sprouting = null
    this.talk = null
    this.greet = null
    this.retractFrom = this.currentPose
    if (!this.motion) { this.state = "travelling"; this.setVisible(false); return 0 }
    this.retracting = { t: 0 }
    this.state = "retracting"
    return RETRACT_SECONDS * 1000
  }

  // Grow out again at the current stage (the root has arrived). Returns ms.
  emerge() {
    this.retracting = null
    this.setVisible(true)
    if (!this.motion) { this.state = "idle"; return 0 }
    this.emerging = { t: 0 }
    this.state = "emerging"
    return EMERGE_SECONDS * 1000
  }

  startDock() {
    this.talk = null
    this.greet = null
    this.dock = { t: 0 }
    this.state = "docking"
  }

  // -1 or 1: which way the stage moves when it docks, so the plant leans into it.
  setDockDirection(sign) { this.dockDirection = sign < 0 ? -1 : 1 }

  setStatic() { this.state = "static" }

  // Pointer in -1..1 relative to the stage centre, or null when none. Called
  // on every move, so a pointer is always activity.
  setPointer(pointer) {
    this.pointer = pointer
    if (pointer) this.notice()
  }

  // Something happened: stay awake, or wake up; from drowsy, a visible perk.
  notice() {
    if (this.awake < 0.5 && !this.perk) this.perk = { t: 0 }
    this.lastActivity = this.time
  }

  // Lean toward a target in the same -1..1 units for a few seconds; null clears.
  attend(target) {
    if (!target) { this.attendTarget = null; return }
    this.attendTarget = { x: clamp(Number(target.x) || 0, -1, 1), y: clamp(Number(target.y) || 0, -1, 1) }
    this.attendHold = ATTEND_HOLD
    this.notice()
  }

  // Reduced motion: transitions snap, nothing sways, the tip's light still answers.
  setMotion(reduced) {
    this.motion = reduced ? 0 : 1
    if (!reduced) return
    if (this.sprouting) { this.sprouting = null; this.g = 0.5; if (this.state === "sprouting") this.state = "idle" }
    if (this.growth) { this.g = this.growth.to; this.growth = null }
    if (this.retracting) { this.retracting = null; this.state = "travelling"; this.setVisible(false) }
    if (this.emerging) { this.emerging = null; if (this.state === "emerging") this.state = "idle" }
    if (this.dock) { this.dock = null; if (this.state === "docking") this.state = "docked" }
    this.greet = null
  }

  setVisible(flag) {
    const p = this.parts
    p.lean.visible = flag
    p.soil.mesh.visible = flag
    p.roots.group.visible = flag
  }

  update(dt) {
    if (this.state === "static") return
    this.time += dt
    const t = this.time
    const m = this.motion
    const docked = this.state === "docked" || this.state === "docking"
    const amp = (docked ? DOCKED_SCALE : 1) * m

    let pose
    let soil = 1
    if (this.sprouting) {
      this.sprouting.t += dt
      pose = sproutPose(Math.min(this.sprouting.t, SPROUT_SECONDS))
      if (this.sprouting.t >= SPROUT_SECONDS) {
        this.sprouting = null
        this.g = 0.5
        if (this.state === "sprouting") this.state = "idle"
      }
    } else if (this.retracting) {
      this.retracting.t += dt
      const u = Math.min(this.retracting.t, RETRACT_SECONDS)
      pose = retractPose(this.retractFrom, u)
      soil = 1 - span(u, 0.6, 1.0, cubicInOut)
      if (this.retracting.t >= RETRACT_SECONDS) {
        this.retracting = null
        this.state = "travelling"
        this.render(pose, { soil: 0, stemLean: null, cotLift: 0, trueLift: 0, flutter: 0, wobbleAmp: 0, glow: 0 })
        this.setVisible(false)
        return
      }
    } else if (this.state === "travelling") {
      return
    } else if (this.emerging) {
      this.emerging.t += dt
      const u = Math.min(this.emerging.t, EMERGE_SECONDS)
      pose = emergePose(growthPose(this.g), u)
      soil = span(u, 0, 0.4, cubicOut)
      if (this.emerging.t >= EMERGE_SECONDS) {
        this.emerging = null
        if (this.state === "emerging") this.state = "idle"
      }
    } else {
      if (this.growth) {
        this.growth.t += dt
        this.g = lerp(this.growth.from, this.growth.to, cubicInOut(this.growth.t / GROW_SECONDS))
        if (this.growth.t >= GROW_SECONDS) { this.g = this.growth.to; this.growth = null }
      }
      pose = growthPose(this.g)
    }

    let glowBoost = 0
    let cotLift = 0
    let trueLift = 0
    let flutter = 0
    let tiltX = 0
    let tiltZ = 0
    let speakLean = 0
    // The apex bending toward the viewer (world +z): the greeting's dip, the nods.
    let toward = 0

    if (this.greet) {
      this.greet.t += dt
      const env = envelope(this.greet.t, 0.5, 0.4, 0.7)
      tiltX += 0.14 * env * m
      cotLift += 0.25 * env * m
      glowBoost += 0.7 * env
      toward += GREET_DIP * env * m
      if (this.greet.t >= GREET_SECONDS) this.greet = null
    }

    if (this.talk) {
      const talk = this.talk
      talk.t += dt
      const d = talk.duration
      const attack = Math.min(0.3, d * 0.3)
      const release = Math.min(0.6, d * 0.4)
      const env = envelope(talk.t, attack, Math.max(0, d - attack - release), release)
      // One stream of syllables drives both the light and the nod, so they coincide.
      const syllable = pulse(t, 5, 15)
      glowBoost += env * (0.45 + 0.25 * syllable)
      cotLift += 0.22 * env * m
      trueLift += 0.14 * env * m
      flutter = env * lerp(1, 0.5, talk.t / d) * m
      speakLean = 0.08 * env * m * this.tip.x
      toward += SPEAK_NOD * env * syllable * m
      if (talk.t >= d) {
        this.talk = null
        if (this.state === "speaking") this.state = talk.returnState
      }
    }

    if (this.dock) {
      this.dock.t += dt
      const u = Math.min(1, this.dock.t / DOCK_SECONDS)
      tiltZ += -0.06 * this.dockDirection * Math.sin(Math.PI * u) * m
      if (u >= 1) {
        this.dock = null
        if (this.state === "docking") this.state = "docked"
      }
    }

    // Wakefulness: the leaves stand up with someone around and droop after a
    // while of nothing (quick to wake, slow to drowse); the light dims with
    // them, and noticing someone again is a short lift and a brighter tip.
    const busy = this.talk || this.greet || this.growth || this.attendTarget
    const awakeTarget = busy || t - this.lastActivity < AWAKE_HOLD ? 1 : 0
    this.awake += (awakeTarget - this.awake) * (1 - Math.exp(-dt / (awakeTarget > this.awake ? WAKE_TAU : DROWSE_TAU)))
    const drowsy = (1 - this.awake) * m
    cotLift -= DROOP * drowsy
    trueLift -= 0.5 * DROOP * drowsy
    if (this.perk) {
      this.perk.t += dt
      const env = envelope(this.perk.t, 0.25, 0.3, 0.65)
      cotLift += 0.12 * env * m
      glowBoost += 0.5 * env
      if (this.perk.t >= PERK_SECONDS) this.perk = null
    }

    this.updateLean(dt)
    const lx = this.lean.x * m
    const ly = this.lean.y * m
    const tx = this.tip.x * m
    const ty = this.tip.y * m
    const p = this.parts
    p.lean.rotation.z = -LEAN_Z * lx + SWAY_Z * drift(t, 1, 0.35) * amp + tiltZ
    p.lean.rotation.x = -LEAN_X * ly + SWAY_X * drift(t, 7, 0.27) * amp + tiltX + REST_TILT
    const yaw = this.restYaw + LEAN_YAW * lx
    p.plant.rotation.y = yaw
    // The upper stem bends in world space: sideways toward the target (the apex
    // leads, the base follows), away from the viewer as the target rises and
    // toward it as it falls, plus the nods. Converted into the plant's own
    // (yawed) space, where the slow ellipse of circumnutation is added.
    const bx = STEM_LEAN * tx + speakLean
    const bz = -TIP_LEAN_Y * ty + toward
    const cos = Math.cos(yaw)
    const sin = Math.sin(yaw)
    const nutation = 2 * Math.PI / NUTATION_PERIOD
    const stemLean = {
      x: bx * cos - bz * sin + NUTATION_X * drift(t, 5, nutation) * amp,
      z: bx * sin + bz * cos + NUTATION_Z * Math.sin(t * nutation) * amp
    }
    const glow = pose.glow * (GLOW_BASE * (1 - 0.4 * drowsy) + 0.08 * drift(t, 3, 0.15) * amp + glowBoost)

    this.render(pose, { soil, stemLean, cotLift, trueLift, flutter, wobbleAmp: WOBBLE * amp, glow })
  }

  // The attend target (or the pointer: heliotropism, the plant turns to face
  // whoever is there) pulls the lean; the apex gets there first (TIP_TAU), the
  // base follows (ATTEND_TAU); both relax slowly once nothing pulls (RELAX_TAU).
  updateLean(dt) {
    if (this.attendTarget) {
      this.attendHold -= dt
      if (this.attendHold <= 0) this.attendTarget = null
    }
    const target = this.attendTarget || (this.pointer ? { x: this.pointer.x * POINTER_WEIGHT, y: this.pointer.y * POINTER_WEIGHT } : null)
    const tx = target ? clamp(target.x, -1, 1) : 0
    const ty = target ? clamp(target.y, -1, 1) : 0
    const k = 1 - Math.exp(-dt / (target ? ATTEND_TAU : RELAX_TAU))
    this.lean.x += (tx - this.lean.x) * k
    this.lean.y += (ty - this.lean.y) * k
    const kt = 1 - Math.exp(-dt / (target ? TIP_TAU : RELAX_TAU * 0.6))
    this.tip.x += (tx - this.tip.x) * kt
    this.tip.y += (ty - this.tip.y) * kt
  }

  render(pose, extras) {
    const p = this.parts
    const time = this.time
    p.soil.mesh.scale.setScalar(Math.max(0.001, extras.soil))
    p.soil.mesh.visible = extras.soil > 0.002
    p.seed.setOpen(pose.seedOpen, pose.seedSink)
    p.stem.deform({ length: pose.stemLength, hook: pose.hook, lean: extras.stemLean })
    p.stem.mesh.visible = pose.stemLength > 0.01
    p.cotyledons.forEach((leaf, i) => {
      leaf.setPose({ curl: pose.cotCurl, lift: extras.cotLift, wobble: extras.wobbleAmp * drift(time, 11 + 3 * i, 0.8), scale: pose.cotScale })
      leaf.deform({ curl: pose.cotCurl, flutter: extras.flutter, time })
    })
    p.trueLeaves.forEach((leaf, i) => {
      leaf.setPose({ curl: pose.trueCurl, lift: extras.trueLift, wobble: extras.wobbleAmp * drift(time, 17 + 3 * i, 0.9), scale: pose.trueScale })
      leaf.deform({ curl: pose.trueCurl, flutter: extras.flutter, time })
    })
    p.roots.reveal(pose.roots)
    const budScale = clamp(pose.stemLength / 0.8, 0.001, 1)
    p.bud.visible = pose.stemLength > 0.05
    p.bud.scale.set(budScale, 1.3 * budScale, budScale)
    if (p.halo) p.halo.visible = pose.stemLength > 0.05
    p.glow.set(clamp(extras.glow, 0, 1.2))
    this.currentPose = pose
  }
}
