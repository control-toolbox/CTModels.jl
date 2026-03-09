module TestAqua

using Test: Test
using CTModels: CTModels
using Aqua: Aqua

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_aqua()
    Test.@testset "Aqua.jl Quality Checks" verbose=VERBOSE showtiming=SHOWTIMING begin
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

# CRITICAL: Redefine in outer scope for TestRunner
test_aqua() = TestAqua.test_aqua()
