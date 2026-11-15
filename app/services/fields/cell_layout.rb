# frozen_string_literal: true

module Fields
  # Where each crop of a season sits on the 10x10 field map (FieldCrop::GRID),
  # given the share of the field it covers. Deterministic, and mirrored line
  # for line in app/javascript/fields/cell_layout.js so the planner and the
  # server place cells the same way:
  #
  #   1. Each crop gets round(share * 100) cells (largest remainder, never
  #      past the grid).
  #   2. A crop keeps its previous cells, first ones first, up to its count.
  #   3. A crop that needs more grows from its own cells into free neighbours
  #      (breadth first: up, right, down, left), then anywhere free. A crop
  #      with no cells yet takes free cells in column order, so a fresh split
  #      reads as vertical bands, left to right.
  module CellLayout
    SIDE = FieldCrop::GRID_SIDE
    GRID = FieldCrop::GRID
    # Column order: down the first column, then the next.
    COLUMN_ORDER = (0...SIDE).flat_map { |col| (0...SIDE).map { |row| (row * SIDE) + col } }.freeze

    module_function

    # shares: [Float] in list order; previous: [[Integer]] per crop (or []).
    def allocate(shares, previous = [])
      counts = counts_for(shares)
      taken = Array.new(GRID, false)
      cells = counts.each_with_index.map do |count, i|
        kept = Array(previous[i]).select { |c| c.is_a?(Integer) && c.between?(0, GRID - 1) && !taken[c] }.first(count)
        kept.each { |c| taken[c] = true }
        kept
      end
      counts.each_with_index { |count, i| grow(cells[i], count, taken) }
      cells.map(&:sort)
    end

    # The share each list of cells covers.
    def shares_from(cells) = cells.map { |list| list.size / GRID.to_f }

    # Cells per share by the largest remainder, the total capped at the grid.
    def counts_for(shares)
      raw = shares.map { |s| [ s.to_f, 0 ].max * GRID }
      counts = raw.map(&:floor)
      target = [ raw.sum.round, GRID ].min
      raw.each_with_index.sort_by { |r, i| [ -(r - r.floor), i ] }.each do |_, i|
        break if counts.sum >= target

        counts[i] += 1
      end
      counts
    end

    def grow(own, count, taken)
      fresh = own.empty?
      queue = own.dup
      while own.size < count
        cell = (next_from(queue, taken) unless fresh) || COLUMN_ORDER.find { |c| !taken[c] }
        break unless cell

        taken[cell] = true
        own << cell
        queue << cell
      end
    end

    # The first free neighbour of the queued cells, breadth first.
    def next_from(queue, taken)
      until queue.empty?
        free = neighbours(queue.first).find { |c| !taken[c] }
        return free if free

        queue.shift
      end
      nil
    end

    def neighbours(cell)
      row, col = cell.divmod(SIDE)
      [ ([ row - 1, col ] if row.positive?), ([ row, col + 1 ] if col < SIDE - 1),
        ([ row + 1, col ] if row < SIDE - 1), ([ row, col - 1 ] if col.positive?) ].compact.map { |r, c| (r * SIDE) + c }
    end
  end
end
