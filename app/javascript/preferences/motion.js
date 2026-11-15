// The person's motion preference, in one place for every animating controller
// (mascot, hero_scene, scroll_story, scroll_reveal, chat_message): the
// data-motion attribute the preferences controller mirrors onto <html> from
// the aluni_prefs cookie, or the operating system's reduced-motion setting.
export function reducedMotion() {
  if (document.documentElement.dataset.motion === "reduce") return true
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}
