using CTModels

partial_dyn_1!(r, t, x, u, v) = (@views r[1] .= x[1] + 2u[2])
partial_dyn_2!(r, t, x, u, v) = (@views r[1] .= 2x[3])
partial_dyn_3!(r, t, x, u, v) = (@views r[1] .= x[1] + u[2])

x = [1, 2, 3]
u = [-1, 2]

parts = [(1:1, partial_dyn_1!), (2:2, partial_dyn_2!), (3:3, partial_dyn_3!)]

dyn! = CTModels.__build_dynamics_from_parts(parts)

r = zeros(3)
dyn!(r, 0, x, u, nothing)

r - [x[1] + 2u[2], 2x[3], x[1] + u[2]]

###

r[1:1] .= 0

x = [1, 2, 3]
x[1] = 10
