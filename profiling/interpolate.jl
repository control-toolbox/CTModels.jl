begin
    using Revise
    using CTModels

    using JET
    using BenchmarkTools
    using Profile

    function make_interpolation()
        T = [0, 1]

        A = [
            0 1
            2 3
        ]

        V = CTModels.matrix2vec(A, 1)

        f = CTModels.ctinterpolate(T, V)

        for x in LinRange(0, 1, 100)
            f(x)
        end

        return f(0.5)
    end

    let
        println("--------------------------------")
        println("Make interpolation")
        @code_warntype make_interpolation()
    end

    # let
    #     println("--------------------------------")
    #     println("Make interpolation")
    #     println(@report_opt make_interpolation())
    # end

    let
        println("--------------------------------")
        println("Make interpolation")
        display(@benchmark make_interpolation())
    end

    # let
    #     println("--------------------------------")
    #     println("Make interpolation")
    #     @code_native debuginfo = :none dump_module = false make_interpolation()
    # end

end
