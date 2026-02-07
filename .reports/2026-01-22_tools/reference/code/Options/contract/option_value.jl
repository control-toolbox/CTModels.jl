# Options Module - option_value.jl

"""
    OptionValue{T}

Represents an option value with its source.

# Fields
- `value::T` - The actual value
- `source::Symbol` - Where the value came from (`:default`, `:user`, `:computed`)

# Example
```julia
opt = OptionValue(100, :user)
opt.value   # => 100
opt.source  # => :user
```
"""
struct OptionValue{T}
    value::T
    source::Symbol
    
    function OptionValue(value::T, source::Symbol) where T
        if source ∉ (:default, :user, :computed)
            error("Invalid source: $source. Must be :default, :user, or :computed")
        end
        new{T}(value, source)
    end
end

# Convenience constructors
OptionValue(value) = OptionValue(value, :user)

# Display
Base.show(io::IO, opt::OptionValue) = print(io, "$(opt.value) ($(opt.source))")
