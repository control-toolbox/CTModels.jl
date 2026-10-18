# Fixtures

`json3_*.json` are solutions exported by CTModels 0.19.8, when the JSON format was written
with JSON3.jl. They check that files written by the previous version are still read after
the move to JSON.jl (`suite/serialization/test_json_format.jl`).

They come from `TestProblems.solution_example()` and `TestProblems.solution_example_dual()`
(`test/problems`), exported with `format=:JSON`. Do not regenerate them with a newer
version: their point is to be written by the previous one.
