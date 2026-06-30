# ------------------------------------------------------------------------------ #
# Base.show for InitialGuess and PreInitialGuess
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print a human-readable summary of the initial guess to `io`.

Displays the type name, then each field (`state`, `control`, `variable`) with
semantic labels.  State and control are shown as `<callable>` since they are
functions; `variable` shows its value or `(none)` when empty.

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Init.InitialGuess`](@ref), [`CTModels.Init.PreInitialGuess`](@ref)
"""
function Base.show(io::IO, ::MIME"text/plain", init::InitialGuess)
    fmt = Core.get_format_codes(io)
    println(io, fmt.name, "InitialGuess", fmt.reset)
    println(io, "  ", fmt.label, "state:   ", fmt.reset, fmt.muted, "<callable>", fmt.reset)
    println(io, "  ", fmt.label, "control: ", fmt.reset, fmt.muted, "<callable>", fmt.reset)
    if isempty(init.variable)
        print(io, "  ", fmt.label, "variable:", fmt.reset, fmt.muted, " (none)", fmt.reset)
    else
        print(io, "  ", fmt.label, "variable:", fmt.reset, " ", fmt.value, init.variable, fmt.reset)
    end
end

"""
$(TYPEDSIGNATURES)

Print a compact one-line representation of the initial guess to `io`.

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Init.InitialGuess`](@ref)
"""
function Base.show(io::IO, init::InitialGuess)
    fmt = Core.get_format_codes(io)
    v_str = isempty(init.variable) ? "(none)" : string(init.variable)
    print(io, fmt.name, "InitialGuess", fmt.reset,
          "(state=<callable>, control=<callable>, variable=", v_str, ")")
end

"""
$(TYPEDSIGNATURES)

Print a human-readable summary of the pre-initial guess to `io`.

Displays the type name, then the `typeof` of each raw field (`state`, `control`,
`variable`), since `PreInitialGuess` stores unprocessed data.

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Init.PreInitialGuess`](@ref), [`CTModels.Init.InitialGuess`](@ref)
"""
function Base.show(io::IO, ::MIME"text/plain", pre::PreInitialGuess)
    fmt = Core.get_format_codes(io)
    println(io, fmt.name, "PreInitialGuess", fmt.reset)
    println(io, "  ", fmt.label, "state:   ", fmt.reset, fmt.type, typeof(pre.state), fmt.reset)
    println(io, "  ", fmt.label, "control: ", fmt.reset, fmt.type, typeof(pre.control), fmt.reset)
    print(io, "  ", fmt.label, "variable:", fmt.reset, " ", fmt.type, typeof(pre.variable), fmt.reset)
end

"""
$(TYPEDSIGNATURES)

Print a compact one-line representation of the pre-initial guess to `io`.

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Init.PreInitialGuess`](@ref)
"""
function Base.show(io::IO, pre::PreInitialGuess)
    fmt = Core.get_format_codes(io)
    print(io, fmt.name, "PreInitialGuess", fmt.reset,
          "(state=", typeof(pre.state),
          ", control=", typeof(pre.control),
          ", variable=", typeof(pre.variable), ")")
end
