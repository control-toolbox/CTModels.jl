# =============================================================================
# assemble.jl — turn lowered group nodes into the figure layout tree.
#
#   :group -> one cell per group in a horizontal row, except the four-cell
#             state|costate / control|norm case, which becomes a 2×2 grid;
#   :split -> paired columns (state|costate, path|dual) stacked with the control
#             column, row heights n : l : nc coming for free from the geometry-aware
#             `:auto` weights of `Stacked`.
#
# Docstrings deferred (Handbook convention).
# =============================================================================

# Pair two columns side by side, tolerating a missing one.
function _pair(a, b)
    a !== nothing && b !== nothing && return Plotting.Paired(a, b)
    return a !== nothing ? a : b
end

# Horizontal row of group cells (`:group`). Exactly four cells (state, costate,
# control, control-norm) fold into a 2×2 grid, as in the historical layout.
function _assemble_group(cells::AbstractVector{<:Plotting.AbstractLayoutNode})
    n = length(cells)
    n == 1 && return cells[1]
    if n == 4
        grid = Plotting.AbstractLayoutNode[
            cells[1] cells[2]
            cells[3] cells[4]
        ]
        return Plotting.Grid(grid)
    end
    return Plotting.Paired(collect(Plotting.AbstractLayoutNode, cells))
end

# Stacked columns (`:split`): (state|costate) over control over (path|dual). Returns
# `nothing` when there is nothing to draw.
function _assemble_split(;
    state=nothing, costate=nothing, control=nothing, path=nothing, dual=nothing
)
    xp = _pair(state, costate)
    cd = _pair(path, dual)
    blocks = Plotting.AbstractLayoutNode[b for b in (xp, control, cd) if b !== nothing]
    isempty(blocks) && return nothing
    length(blocks) == 1 && return blocks[1]
    return Plotting.Stacked(blocks)
end
