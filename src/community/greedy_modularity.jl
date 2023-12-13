function greedy_modularity(g::AbstractGraph; weights::AbstractMatrix=weights(g))
    if is_directed(g)
        throw(ArgumentError("The graph must not be directed"))
    end
    n = nv(g)
    c = Vector{Int}(1:n)
    Q, e, a = compute_modularity(g, c, weights)
    m = sum(a)
    Q_max = Q
    c_best = copy(c)
    for i in 2:n
        Q = modularity_greedy_step!(g, Q, e, a, c, m)
        if Q_max < Q
            Q_max = Q
            c_best = copy(c)
        else
            break
        end
    end
    return rewrite_class_ids(c_best)
end

function modularity_greedy_step!(
    g::AbstractGraph,
    Q::T,
    e::AbstractMatrix{T},
    a::AbstractVector{T},
    c::AbstractVector{<:Integer},
    m::T,
) where {T}
    n = nv(g)
    dq_max::typeof(Q) = typemin(Q)
    to_merge = (0, 0)
    _, y = size(e)
    rows = rowvals(e)
    vals = nonzeros(e)
    for col in 1:y
        for i in nzrange(e, col)
            row = rows[i]
            value = vals[i]
            if row != col
                dq = (value / m - a[row] * a[col] / m^2)
                if dq > dq_max
                    dq_max = dq
                    to_merge = (row, col)
                end
            end
        end
    end
    if dq_max > zero(typeof(Q))
        c1, c2 = to_merge
        for i in 1:n
            e[c1, i] += e[c2, i]
            e[c2, i] = 0
        end
        for i in 1:n
            if i == c2
                continue
            end
            e[i, c1] += e[i, c2]
        end
        e[:, c2] .= 0
        dropzeros!(e)
        a[c1] = a[c1] + a[c2]
        for i in 1:n
            if c[i] == c2
                c[i] = c1
            end
        end
        return Q + 2 * dq_max
    else
        return Q
    end
end

function compute_modularity(
    g::AbstractGraph, c::AbstractVector{<:Integer}, w::AbstractArray
)
    modularity_type = float(eltype(w))
    Q = zero(modularity_type)
    m = sum(w[src(e), dst(e)] for e in edges(g); init=Q) * 2
    n_groups = maximum(c)
    a = zeros(modularity_type, n_groups)
    ei, ej = Vector{Int}(), Vector{Int}()
    ev = Vector{modularity_type}()
    e = spzeros(modularity_type, n_groups, n_groups)
    m == 0 && return 0.0, e, a
    for u in vertices(g)
        for v in neighbors(g, u)
            if c[u] == c[v]
                Q += w[u, v]
            end
            push!(ei, c[u])
            push!(ej, c[v])
            push!(ev, w[u, v])
            a[c[u]] += w[u, v]
        end
    end
    Q *= m
    for i in 1:n_groups
        Q -= a[i]^2
    end
    Q /= m^2
    return Q, sparse(ei, ej, ev), a
end

function rewrite_class_ids(v::AbstractVector{<:Integer})
    d = Dict{Int,Int}()
    vn = zeros(Int64, length(v))
    for i in eachindex(v)
        if !(v[i] in keys(d))
            d[v[i]] = length(d) + 1
        end
        vn[i] = d[v[i]]
    end
    return vn
end
