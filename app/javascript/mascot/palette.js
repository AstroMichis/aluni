// Aluni's colours as hex ints, mirroring the --color-mascot-* tokens in
// base/variables.css (change both together). Dark uses the cover-crop and
// olive greens of the hero palette; light the deeper greens so the seedling
// reads on cream. The light rig (hemisphere sky/ground, sun) is per theme too.
export const PALETTES = {
  dark: {
    seed: 0xA67C4E, seedShade: 0x6F4F2F,
    leaf: 0x3E7A4A, leafShade: 0x6B7650,
    eye: 0x1F1B16, eyeGlow: 0x3A332B, cheek: 0xD9C48F, mouth: 0x4A2E1A,
    sky: 0xE4E9DD, ground: 0x3A3328, sun: 0xF1EBDD
  },
  light: {
    seed: 0x9C7244, seedShade: 0x6A4A2A,
    leaf: 0x35703F, leafShade: 0x55663F,
    eye: 0x1F1B16, eyeGlow: 0x3A332B, cheek: 0xC9AF72, mouth: 0x3E2715,
    sky: 0xFFFFFF, ground: 0x8C7332, sun: 0xFFFFFF
  }
}

export const paletteFor = (theme) => PALETTES[theme === "light" ? "light" : "dark"]
