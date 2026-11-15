// Aluni's colours as hex ints, mirroring the --color-mascot-* tokens in
// base/variables.css (change both together). Dark sits on the deep green of
// the hero: cover-crop greens, pale herbarium roots, the accent gold at the
// growing tip. Light uses deeper greens and an older gold so the seedling
// reads on cream. The light rig (hemisphere sky and ground, the key sun, the
// gold rim light) and the tone-mapping exposure are per theme too.
export const PALETTES = {
  dark: {
    soil: 0x46392A, soilShade: 0x2E2619,
    seedCoat: 0x8C6A43, seedCoatShade: 0x5E4428,
    stem: 0xA6B587, leaf: 0x4F8F55, leafShade: 0x2F6A3E, vein: 0x86A06E,
    tip: 0xB69A5B, root: 0xD9CBA8,
    sky: 0xE4E9DD, ground: 0x3A3328, sun: 0xF1EBDD, rim: 0xB69A5B, exposure: 1.0
  },
  light: {
    soil: 0x5A4A33, soilShade: 0x43372A,
    seedCoat: 0x8C6A43, seedCoatShade: 0x5E4428,
    stem: 0x6F8A52, leaf: 0x35703F, leafShade: 0x24502E, vein: 0x9DB383,
    tip: 0x8A6A1E, root: 0x8C7A5A,
    sky: 0xFFFFFF, ground: 0x8C7332, sun: 0xFFFFFF, rim: 0x8A6A1E, exposure: 1.05
  }
}

export const paletteFor = (theme) => PALETTES[theme === "light" ? "light" : "dark"]
