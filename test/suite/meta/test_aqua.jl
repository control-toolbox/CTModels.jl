module TestAqua

using Test
using CTModels
using Aqua
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_aqua()
    Test.@testset "Aqua.jl" verbose = VERBOSE showtiming = SHOWTIMING begin
        Aqua.test_all(
            CTModels;
            ambiguities=false,
            #stale_deps=(ignore=[:SomePackage],),
            deps_compat=(ignore=[:LinearAlgebra, :Unicode],),
            piracies=true,
        )
        # do not warn about ambiguities in dependencies
        Aqua.test_ambiguities(CTModels)
    end
end

end # module

test_aqua() = TestAqua.test_aqua()
