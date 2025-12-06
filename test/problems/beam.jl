# Beam optimal control problem definition used by tests and examples.
#
# Returns a NamedTuple with fields:
#   - ocp  :: the CTParser-defined optimal control problem
#   - obj  :: reference optimal objective value (Ipopt / MadNLP, Collocation)
#   - name :: a short problem name
#   - init :: NamedTuple of components for CTSolvers.initial_guess
function Beam()

    pre_ocp = CTModels.PreModel()

    CTModels.variable!(pre_ocp, 0)

    CTModels.time!(pre_ocp; t0=0.0, tf=1.0)

    CTModels.state!(pre_ocp, 2)

    CTModels.control!(pre_ocp, 1)

    dynamics!(r, t, x, u, v) = begin
        r[1] = x[2]
        r[2] = u[1]
        return nothing
    end
    CTModels.dynamics!(pre_ocp, dynamics!)

    lagrange(t, x, u, v) = u[1]^2
    CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

    f_boundary(r, x0, xf, v) = begin
        r[1] = x0[1] - 0.0
        r[2] = x0[2] - 1.0
        r[3] = xf[1] - 0.0
        r[4] = xf[2] + 1.0
        return nothing
    end
    CTModels.constraint!(pre_ocp, :boundary; f=f_boundary, lb=zeros(4), ub=zeros(4), label=:beam_boundary)

    CTModels.constraint!(pre_ocp, :state; rg=1:1, lb=[0.0], ub=[0.1], label=:beam_state_x1)
    CTModels.constraint!(pre_ocp, :control; rg=1:1, lb=[-10.0], ub=[10.0], label=:beam_control_u)

    definition = quote
        t ∈ [0, 1], time
        x ∈ R², state
        u ∈ R, control

        x(0) == [0, 1]
        x(1) == [0, -1]
        0 ≤ x₁(t) ≤ 0.1
        -10 ≤ u(t) ≤ 10

        ẋ(t) == [x₂(t), u(t)]

        ∫(u(t)^2) → min
    end
    CTModels.definition!(pre_ocp, definition)

    CTModels.time_dependence!(pre_ocp; autonomous=true)

    ocp = CTModels.build(pre_ocp)

    init = (state=[0.05, 0.1], control=0.1)

    return (ocp=ocp, obj=8.898598, name="beam", init=init)
end