using Plots

function test_plot()

    #
    ocp, sol, pre_ocp = solution_example()

    #
    @test plot(sol; time=:default) isa Plots.Plot
    @test plot(sol; time=:normalize) isa Plots.Plot
    @test plot(sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; time=:wrong_choice)

    #
    @test plot(sol; layout=:group, control=:components) isa Plots.Plot
    @test plot(sol; layout=:group, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:group, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:group, control=:wrong_choice)

    #
    @test plot(sol; layout=:split, control=:components) isa Plots.Plot
    @test plot(sol; layout=:split, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:split, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:split, control=:wrong_choice)

    #
    @test plot(sol; layout=:split) isa Plots.Plot
    @test plot(sol; layout=:group) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:wrong_choice)

    # 
    plt = plot(sol; time=:default)
    @test plot!(plt, sol; time=:default) isa Plots.Plot
    @test plot!(plt, sol; time=:normalize) isa Plots.Plot
    @test plot!(plt, sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(plt, sol; time=:wrong_choice)

    # 
    plt = plot(sol; layout=:group, control=:components)
    @test plot!(plt, sol; layout=:group, control=:components) isa Plots.Plot
    @test plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

    plt = plot(sol; layout=:group, control=:norm)
    @test plot!(plt, sol; layout=:group, control=:components) isa Plots.Plot
    @test plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

    plt = plot(sol; layout=:group, control=:all)
    @test plot!(plt, sol; layout=:group, control=:all) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(
        plt, sol; layout=:group, control=:wrong_choice
    )

    # 
    plt = plot(sol; layout=:split, control=:components)
    @test plot!(plt, sol; layout=:split, control=:components) isa Plots.Plot
    @test plot!(plt, sol; layout=:split, control=:norm) isa Plots.Plot

    plt = plot(sol; layout=:split, control=:norm)
    @test plot!(plt, sol; layout=:split, control=:components) isa Plots.Plot
    @test plot!(plt, sol; layout=:split, control=:norm) isa Plots.Plot

    plt = plot(sol; layout=:split, control=:all)
    @test plot!(plt, sol; layout=:split, control=:all) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(
        plt, sol; layout=:split, control=:wrong_choice
    )

    #
    plt = plot(sol; layout=:split)
    @test plot!(plt, sol; layout=:split) isa Plots.Plot

    plt = plot(sol; layout=:group)
    @test plot!(plt, sol; layout=:group) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(plt, sol; layout=:wrong_choice)

    #
    @test display(sol) isa Nothing

    # --------------------------------------------------------
    # --------------------------------------------------------
    # other example with path constraints
    ocp, sol = solution_example_path_constraints()

    #
    @test plot(sol; time=:default) isa Plots.Plot
    @test plot(sol; time=:normalize) isa Plots.Plot
    @test plot(sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; time=:wrong_choice)

    @test plot(sol, ocp; time=:default) isa Plots.Plot
    @test plot(sol, ocp; time=:normalize) isa Plots.Plot
    @test plot(sol, ocp; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol, ocp; time=:wrong_choice)

    #
    @test plot(sol; layout=:group, control=:components) isa Plots.Plot
    @test plot(sol; layout=:group, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:group, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:group, control=:wrong_choice)

    @test plot(sol, ocp; layout=:group, control=:components) isa Plots.Plot
    @test plot(sol, ocp; layout=:group, control=:norm) isa Plots.Plot
    @test plot(sol, ocp; layout=:group, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol, ocp; layout=:group, control=:wrong_choice)

    #
    @test plot(sol; layout=:split, control=:components) isa Plots.Plot
    @test plot(sol; layout=:split, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:split, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:split, control=:wrong_choice)

    @test plot(sol, ocp; layout=:split, control=:components) isa Plots.Plot
    @test plot(sol, ocp; layout=:split, control=:norm) isa Plots.Plot
    @test plot(sol, ocp; layout=:split, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol, ocp; layout=:split, control=:wrong_choice)

    #
    @test plot(sol; layout=:split) isa Plots.Plot
    @test plot(sol; layout=:group) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:wrong_choice)

    @test plot(sol, ocp; layout=:split) isa Plots.Plot
    @test plot(sol, ocp; layout=:group) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol, ocp; layout=:wrong_choice)

    # 
    plt = plot(sol; time=:default)
    @test plot!(plt, sol; time=:default) isa Plots.Plot
    @test plot!(plt, sol; time=:normalize) isa Plots.Plot
    @test plot!(plt, sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(plt, sol; time=:wrong_choice)

    plt = plot(sol, ocp; time=:default)
    @test plot!(plt, sol, ocp; time=:default) isa Plots.Plot
    @test plot!(plt, sol, ocp; time=:normalize) isa Plots.Plot
    @test plot!(plt, sol, ocp; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(plt, sol, ocp; time=:wrong_choice)

    # 
    plt = plot(sol; layout=:group, control=:components)
    @test plot!(plt, sol; layout=:group, control=:components) isa Plots.Plot
    @test plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

    plt = plot(sol; layout=:group, control=:norm)
    @test plot!(plt, sol; layout=:group, control=:components) isa Plots.Plot
    @test plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

    plt = plot(sol; layout=:group, control=:all)
    @test plot!(plt, sol; layout=:group, control=:all) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(
        plt, sol; layout=:group, control=:wrong_choice
    )

    plt = plot(sol, ocp; layout=:group, control=:components)
    @test plot!(plt, sol, ocp; layout=:group, control=:components) isa Plots.Plot
    @test plot!(plt, sol, ocp; layout=:group, control=:norm) isa Plots.Plot

    plt = plot(sol, ocp; layout=:group, control=:norm)
    @test plot!(plt, sol, ocp; layout=:group, control=:components) isa Plots.Plot
    @test plot!(plt, sol, ocp; layout=:group, control=:norm) isa Plots.Plot

    plt = plot(sol, ocp; layout=:group, control=:all)
    @test plot!(plt, sol, ocp; layout=:group, control=:all) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(
        plt, sol, ocp; layout=:group, control=:wrong_choice
    )

    # 
    plt = plot(sol, ocp; layout=:split, control=:components)
    @test plot!(plt, sol, ocp; layout=:split, control=:components) isa Plots.Plot
    @test plot!(plt, sol, ocp; layout=:split, control=:norm) isa Plots.Plot

    plt = plot(sol, ocp; layout=:split, control=:norm)
    @test plot!(plt, sol, ocp; layout=:split, control=:components) isa Plots.Plot
    @test plot!(plt, sol, ocp; layout=:split, control=:norm) isa Plots.Plot

    plt = plot(sol, ocp; layout=:split, control=:all)
    @test plot!(plt, sol, ocp; layout=:split, control=:all) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(
        plt, sol, ocp; layout=:split, control=:wrong_choice
    )

    plt = plot(sol, ocp; layout=:split, control=:components)
    @test plot!(plt, sol, ocp; layout=:split, control=:components) isa Plots.Plot
    @test plot!(plt, sol, ocp; layout=:split, control=:norm) isa Plots.Plot

    plt = plot(sol, ocp; layout=:split, control=:norm)
    @test plot!(plt, sol, ocp; layout=:split, control=:components) isa Plots.Plot
    @test plot!(plt, sol, ocp; layout=:split, control=:norm) isa Plots.Plot

    plt = plot(sol, ocp; layout=:split, control=:all)
    @test plot!(plt, sol, ocp; layout=:split, control=:all) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(
        plt, sol, ocp; layout=:split, control=:wrong_choice
    )

    #
    plt = plot(sol; layout=:split)
    @test plot!(plt, sol; layout=:split) isa Plots.Plot

    plt = plot(sol; layout=:group)
    @test plot!(plt, sol; layout=:group) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(plt, sol; layout=:wrong_choice)

    plt = plot(sol, ocp; layout=:split)
    @test plot!(plt, sol, ocp; layout=:split) isa Plots.Plot

    plt = plot(sol, ocp; layout=:group)
    @test plot!(plt, sol, ocp; layout=:group) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(plt, sol, ocp; layout=:wrong_choice)

end
