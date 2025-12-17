# ==============================================================================
# CTModels Coverage Post-Processing
# ==============================================================================
#
# This script processes coverage files generated during test runs with
# coverage enabled. It uses CTBase.postprocess_coverage to generate:
#   - coverage/lcov.info      — LCOV format for CI integration
#   - coverage/cov_report.md  — Human-readable summary with uncovered lines
#   - coverage/cov/           — Archived .cov files
#
# ## Usage
#
#   julia --project=@. -e 'using Pkg; Pkg.test("CTModels"; coverage=true); include("test/coverage.jl")'
#
# ==============================================================================

pushfirst!(LOAD_PATH, @__DIR__)
using Coverage
using CTBase
CTBase.postprocess_coverage(; root_dir=dirname(@__DIR__))
