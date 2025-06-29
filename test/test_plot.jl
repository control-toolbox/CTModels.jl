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

    plot(sol; time=:default)
    @test plot!(sol; time=:default) isa Plots.Plot
    @test plot!(sol; time=:normalize) isa Plots.Plot
    @test plot!(sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(sol; time=:wrong_choice)

    plt = plot()
    @test plot!(plt, sol; time=:default) isa Plots.Plot
    @test plot!(plt, sol; time=:normalize) isa Plots.Plot
    @test plot!(plt, sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(plt, sol; time=:wrong_choice)

    plot()
    @test plot!(sol; time=:default) isa Plots.Plot
    @test plot!(sol; time=:normalize) isa Plots.Plot
    @test plot!(sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(sol; time=:wrong_choice)

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

    @test plot(sol; time=:default) isa Plots.Plot
    @test plot(sol; time=:normalize) isa Plots.Plot
    @test plot(sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; time=:wrong_choice)

    #
    @test plot(sol; layout=:group, control=:components) isa Plots.Plot
    @test plot(sol; layout=:group, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:group, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:group, control=:wrong_choice)

    @test plot(sol; layout=:group, control=:components) isa Plots.Plot
    @test plot(sol; layout=:group, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:group, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:group, control=:wrong_choice)

    #
    @test plot(sol; layout=:split, control=:components) isa Plots.Plot
    @test plot(sol; layout=:split, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:split, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:split, control=:wrong_choice)

    @test plot(sol; layout=:split, control=:components) isa Plots.Plot
    @test plot(sol; layout=:split, control=:norm) isa Plots.Plot
    @test plot(sol; layout=:split, control=:all) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:split, control=:wrong_choice)

    #
    @test plot(sol; layout=:split) isa Plots.Plot
    @test plot(sol; layout=:group) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:wrong_choice)

    @test plot(sol; layout=:split) isa Plots.Plot
    @test plot(sol; layout=:group) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot(sol; layout=:wrong_choice)

    # 
    plt = plot(sol; time=:default)
    @test plot!(plt, sol; time=:default) isa Plots.Plot
    @test plot!(plt, sol; time=:normalize) isa Plots.Plot
    @test plot!(plt, sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(plt, sol; time=:wrong_choice)

    plot(sol; time=:default)
    @test plot!(sol; time=:default) isa Plots.Plot
    @test plot!(sol; time=:normalize) isa Plots.Plot
    @test plot!(sol; time=:normalise) isa Plots.Plot
    @test_throws CTBase.IncorrectArgument plot!(sol; time=:wrong_choice)

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

    plt = plot(sol; layout=:split)
    @test plot!(plt, sol; layout=:split) isa Plots.Plot

    plt = plot(sol; layout=:group)
    @test plot!(plt, sol; layout=:group) isa Plots.Plot

    @test_throws CTBase.IncorrectArgument plot!(plt, sol; layout=:wrong_choice)
end
