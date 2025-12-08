function test_definition()
    # TODO: add tests for src/ocp/definition.jl.

    # ========================================================================
    # Unit tests – setters/getters on PreModel and Model
    # ========================================================================

    Test.@testset "definition! and definition on PreModel" verbose=VERBOSE showtiming=SHOWTIMING begin
        pre = CTModels.PreModel()
        expr = :(x = 1)

        CTModels.definition!(pre, expr)

        Test.@test CTModels.definition(pre) === expr
    end

    # ========================================================================
    # Integration-style tests – definition propagated through build
    # ========================================================================

    Test.@testset "definition carried to Model after build" verbose=VERBOSE showtiming=SHOWTIMING begin
        pre = CTModels.PreModel()

        # Minimal consistent problem using the high-level API
        CTModels.time!(pre; t0=0.0, tf=1.0)
        CTModels.state!(pre, 1)
        CTModels.control!(pre, 1)
        CTModels.variable!(pre, 0)

        dyn!(r, t, x, u, v) = r .= 0
        CTModels.dynamics!(pre, dyn!)

        mayer(x0, xf, v) = 0.0
        lagrange(t, x, u, v) = 0.0
        CTModels.objective!(pre, :min; mayer=mayer, lagrange=lagrange)

        expr = quote
            t ∈ [0, 1], time
            x ∈ R, state
            u ∈ R, control
            ẋ(t) == u(t)
            ∫(0.5u(t)^2) → min
        end

        CTModels.definition!(pre, expr)
        CTModels.time_dependence!(pre; autonomous=false)

        model = CTModels.build(pre)

        Test.@test CTModels.definition(model) === expr
    end
end

