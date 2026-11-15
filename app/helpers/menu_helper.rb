# frozen_string_literal: true

# The main menu dial: its sections, their panel options and the SVG geometry.
# Copy lives in pages.menu.*; each section key is also its tone (menu.css).
#
# The dial is drawn in a viewBox centred on 0,0. Every wedge is the same path
# at 12 o'clock, rotated into place, so its texture, label and selected lift
# all work in one local frame where "outwards" is straight up.
module MenuHelper
  SECTIONS = {
    fields:  %i[add map soil history],
    crops:   %i[current rotation calendar tips],
    weather: %i[forecast moisture alerts],
    staff:   %i[team tasks roles],
    reports: %i[season yield export]
  }.freeze

  INNER = 60
  OUTER = 95
  GAP = 3.5 # degrees between wedges

  def menu_sections = SECTIONS
  def dial_step = 360.0 / SECTIONS.size

  # "01 / 05" for the section at index i.
  def dial_kicker(index)
    t("pages.menu.kicker", number: format("%02d", index + 1), total: format("%02d", SECTIONS.size))
  end

  # An annular wedge centred on 12 o'clock (each spans well under 180 degrees,
  # so both arcs use the small-arc flag).
  def dial_wedge_path
    half = (dial_step - GAP) / 2
    "M#{dial_point(OUTER, -90 - half)} A#{OUTER} #{OUTER} 0 0 1 #{dial_point(OUTER, -90 + half)} " \
      "L#{dial_point(INNER, -90 + half)} A#{INNER} #{INNER} 0 0 0 #{dial_point(INNER, -90 - half)} Z"
  end

  # The tick ring as one path: a mark every 6 degrees, longer every 30.
  def dial_ticks_path(long:)
    (0...60).select { |i| (i % 5).zero? == long }.map do |i|
      "M#{dial_point(long ? 96.5 : 97.5, i * 6)} L#{dial_point(99.5, i * 6)}"
    end.join(" ")
  end

  def dial_point(radius, degrees)
    rad = degrees * Math::PI / 180
    format("%.2f %.2f", radius * Math.cos(rad), radius * Math.sin(rad))
  end
end
