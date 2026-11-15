// Where each crop of a season sits on the 10x10 field map, given its share
// of the field. Mirrors app/services/fields/cell_layout.rb line for line, so
// the planner (crop_layout_controller.js) and the server agree:
//   1. Each crop gets round(share * 100) cells (largest remainder, never past
//      the grid).
//   2. A crop keeps its previous cells, first ones first, up to its count.
//   3. A crop that needs more grows from its own cells into free neighbours
//      (breadth first: up, right, down, left), then anywhere free. A crop with
//      no cells yet takes free cells in column order (vertical bands).

export const SIDE = 10
export const GRID = SIDE * SIDE
const COLUMN_ORDER = Array.from({ length: GRID }, (_, i) => (i % SIDE) * SIDE + Math.floor(i / SIDE))

export function allocate(shares, previous = []) {
  const counts = countsFor(shares)
  const taken = new Array(GRID).fill(false)
  const cells = counts.map((count, i) => {
    const kept = (previous[i] || []).filter((c) => Number.isInteger(c) && c >= 0 && c < GRID && !taken[c]).slice(0, count)
    kept.forEach((c) => { taken[c] = true })
    return kept
  })
  counts.forEach((count, i) => grow(cells[i], count, taken))
  return cells.map((list) => list.sort((a, b) => a - b))
}

export function sharesFrom(cells) {
  return cells.map((list) => list.length / GRID)
}

export function countsFor(shares) {
  const raw = shares.map((s) => Math.max(Number(s) || 0, 0) * GRID)
  const counts = raw.map(Math.floor)
  const target = Math.min(Math.round(raw.reduce((a, b) => a + b, 0)), GRID)
  const order = raw.map((r, i) => [r - Math.floor(r), i]).sort((a, b) => b[0] - a[0] || a[1] - b[1])
  for (const [, i] of order) {
    if (counts.reduce((a, b) => a + b, 0) >= target) break
    counts[i] += 1
  }
  return counts
}

function grow(own, count, taken) {
  const fresh = own.length === 0
  const queue = [...own]
  while (own.length < count) {
    const cell = (fresh ? null : nextFrom(queue, taken)) ?? COLUMN_ORDER.find((c) => !taken[c])
    if (cell === undefined) break
    taken[cell] = true
    own.push(cell)
    queue.push(cell)
  }
}

function nextFrom(queue, taken) {
  while (queue.length) {
    const free = neighbours(queue[0]).find((c) => !taken[c])
    if (free !== undefined) return free
    queue.shift()
  }
  return null
}

function neighbours(cell) {
  const row = Math.floor(cell / SIDE)
  const col = cell % SIDE
  return [
    row > 0 ? [row - 1, col] : null, col < SIDE - 1 ? [row, col + 1] : null,
    row < SIDE - 1 ? [row + 1, col] : null, col > 0 ? [row, col - 1] : null
  ].filter(Boolean).map(([r, c]) => r * SIDE + c)
}
