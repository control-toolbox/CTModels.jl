# Modelers Utilities
#
# Utility functions and helpers for modeler strategies.
#
# Author: CTModels Development Team
# Date: 2026-01-25

"""
$(TYPEDSIGNATURES)

Validate that the initial guess has the expected dimensions.

# Arguments
- `initial_guess`: Initial guess vector or array
- `expected_size`: Expected size tuple

# Throws
- `CTBase.IncorrectArgument`: If dimensions don't match
"""
function validate_initial_guess(initial_guess, expected_size)
    if size(initial_guess) != expected_size
        throw(CTBase.IncorrectArgument(
            "Initial guess size $(size(initial_guess)) doesn't match expected size $expected_size"
        ))
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Extract options from a modeler strategy in a convenient format.

# Arguments
- `modeler::AbstractOptimizationModeler`: The modeler strategy instance

# Returns
- `NamedTuple`: Named tuple of option values
"""
function extract_modeler_options(modeler::AbstractOptimizationModeler)
    opts = Strategies.options(modeler)
    return opts.options
end
