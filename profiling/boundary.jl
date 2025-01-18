begin
    using Revise
    using CTModels

    using JET
    using BenchmarkTools
    using Profile 

    # define problem with new model: simple integrator
    function simple_integrator_model()
        pre_ocp = CTModels.PreModel()
        CTModels.state!(pre_ocp, 1)
        CTModels.control!(pre_ocp, 2)
        CTModels.time!(pre_ocp, t0=0.0, tf=1.0)
        f!(r, t, x, u, v) = r .=  .- x[1] .- u[1] .+ u[2] 
        CTModels.dynamics!(pre_ocp, f!)
        l(t, x, u, v) = (u[1] .+ u[2]).^2
        CTModels.objective!(pre_ocp, :min, lagrange=l)
        function bc!(r, x0, xf, v)
            r[1] = x0[1]
            r[2] = xf[1]
            return nothing
        end
        #bc!(r, x0, xf, v) = r .= [x0[1], xf[1]]
        CTModels.constraint!(pre_ocp, :boundary, f=bc!, lb=[-1, 0], ub=[-1, 0], label=:boundary1)
        CTModels.constraint!(pre_ocp, :boundary, f=bc!, lb=[-1, 0], ub=[-1, 0], label=:boundary2)
        CTModels.constraint!(pre_ocp, :boundary, f=bc!, lb=[-1, 0], ub=[-1, 0], label=:boundary3)
        CTModels.constraint!(pre_ocp, :control, rg=1:2, lb=[0, 0], ub=[Inf, Inf], label=:control_rg)
        CTModels.definition!(pre_ocp, Expr(:simple_integrator_min_energy))
        ocp = CTModels.build_model(pre_ocp)
        return ocp
    end

    ocp = simple_integrator_model()

    x0 = [1.0]
    xf = [0.0]
    v  = Float64[]
    r = zeros(Float64, 6)
    bc_constraint = CTModels.boundary_constraints_nl(ocp)
    boundary! = bc_constraint[2]
    boundary!(r, x0, xf, v)
    r

    function bc!(r, x0, xf, v)
        r[1] = x0[1]
        r[2] = xf[1]
        return nothing
    end
end

let
    println("--------------------------------")
    println("Boundary constraint")
    @code_warntype bc!(r, x0, xf, v)

    println("--------------------------------")
    println("Boundary constraint from model")
    @code_warntype boundary!(r, x0, xf, v)
end

let
    println("Boundary constraint")
    @btime bc!(r, x0, xf, v)
    println("Boundary constraint from model")
    @btime boundary!(r, x0, xf, v)
end

let
    println("--------------------------------")
    println("Boundary constraint")
    @code_native debuginfo=:none dump_module=false bc!(r, x0, xf, v)

    println("--------------------------------")
    println("Boundary constraint from model")
    @code_native debuginfo=:none dump_module=false boundary!(r, x0, xf, v)
end