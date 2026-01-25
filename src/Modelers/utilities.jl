# Modelers Utilities
#
# Utility functions and helpers for modeler strategies.
#
# Author: CTModels Development Team
# Date: 2026-01-25

# Note: AbstractOptimizationProblem will be available as CTModels.AbstractOptimalControlProblem
# when the module is used in the parent context

"""
    validate_initial_guess(initial_guess, expected_size)

Validate that the initial guess has the expected dimensions.

# Arguments
- `initial_guess`: Initial guess vector or array
- `expected_size`: Expected size tuple

# Throws
- `ArgumentError` if dimensions don't match
"""
function validate_initial_guess(initial_guess, expected_size)
    if size(initial_guess) != expected_size
        throw(ArgumentError(
            "Initial guess size $(size(initial_guess)) doesn't match expected size $expected_size"
        ))
    end
    return nothing
end

"""
    extract_modeler_options(modeler::AbstractModeler)

Extract options from a modeler strategy in a convenient format.

# Arguments
- `modeler`: The modeler strategy instance

# Returns
- `NamedTuple` of option values
"""
function extract_modeler_options(modeler::AbstractModeler)
    opts = Strategies.options(modeler)
    return NamedTuple{Strategies.option_names(opts)}(
        Strategies.option_value(opts, name) for name in Strategies.option_names(opts)
    )
end
