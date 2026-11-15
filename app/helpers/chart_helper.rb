# frozen_string_literal: true

# Geometry for the server-drawn SVG charts (shared/_chart_*): one measure per
# chart, one axis, recessive grid, rounded data ends on the baseline. The
# hover layer (crosshair and tooltip) is chart_controller.js.
module ChartHelper
  WIDTH = 640
  HEIGHT = 200
  LEFT = 44
  RIGHT = 6
  TOP = 12
  BOTTOM = 26

  Frame = Struct.new(:count, :min, :max, :step, keyword_init: true) do
    def plot_width = WIDTH - LEFT - RIGHT
    def baseline = HEIGHT - BOTTOM

    # Points spread edge to edge (lines).
    def x(index) = LEFT + (plot_width * (count <= 1 ? 0.5 : index.to_f / (count - 1)))

    # One slot per bar, 2px surface gap between bars.
    def slot = plot_width.to_f / count
    def bar_x(index) = LEFT + (slot * index) + 1
    def bar_width = [ slot - 2, 1 ].max

    def y(value) = TOP + ((baseline - TOP) * (1 - ((value - min) / (max - min).to_f)))
    def ticks = (min..max).step(step).to_a
  end

  # A frame whose bounds are the values rounded out to the step.
  def chart_frame(values, count:, step:, floor: nil)
    min = floor || ((values.min / step).floor * step)
    max = [ (values.max / step).ceil * step, min + step ].max
    Frame.new(count: count, min: min, max: max, step: step)
  end

  def line_path(points) = points.each_with_index.map { |(x, y), i| "#{i.zero? ? 'M' : 'L'}#{x.round(1)} #{y.round(1)}" }.join(" ")

  # A bar from the baseline with a 2px rounded top (the data end).
  def bar_path(x, top, width, baseline)
    r = [ 2, width / 2.0, (baseline - top) ].min
    "M#{x.round(1)} #{baseline} V#{(top + r).round(1)} Q#{x.round(1)} #{top.round(1)} #{(x + r).round(1)} #{top.round(1)} " \
      "H#{(x + width - r).round(1)} Q#{(x + width).round(1)} #{top.round(1)} #{(x + width).round(1)} #{(top + r).round(1)} V#{baseline} Z"
  end

  # Where an HTML label sits over the stretched SVG, in percent.
  def chart_left(x) = (x * 100.0 / WIDTH).round(2)
  def chart_top(y) = (y * 100.0 / HEIGHT).round(2)

  def chart_number(value, precision = 1) = number_with_precision(value, precision: precision, strip_insignificant_zeros: true, delimiter: "")
end
