
function allocate_matrix end
function allocate_matrix_and_vector end

"""
    allocate_vector(::Type{V},indices) where V

Allocate a vector of type `V` indexable at the indices `indices`
"""
function allocate_vector(::Type{V},indices) where V
  n = length(indices)
  allocate_vector(V,n)
end

function allocate_vector(::Type{V},n::Integer) where V
  T = eltype(V)
  zeros(T,n)
end

"""
    allocate_in_range(::Type{V},matrix) where V

Allocate a vector of type `V` in the range of matrix `matrix`.
"""
function allocate_in_range(::Type{V},matrix) where V
  n = size(matrix,1)
  allocate_vector(V,n)
end

"""
    allocate_in_domain(::Type{V},matrix) where V

Allocate a vector of type `V` in the domain of matrix `matrix`.
"""
function allocate_in_domain(::Type{V},matrix) where V
  n = size(matrix,2)
  allocate_vector(V,n)
end

"""
    fill_entries!(a,v)

Fill the entries of array `a` with the value `v`. Returns `a`.
"""
function fill_entries!(a,v)
  fill!(a,v)
  a
end

"""
    copy_entries!(a,b)

Copy the entries of array `b` into array `a`. Returns `a`.
"""
function copy_entries!(a,b)
  if a !== b
    copyto!(a,b)
  end
  a
end

"""
    add_entries!(a,b,combine=+)

Perform the operation `combine` element-wise in the entries of arrays `a` and `b`
and store the result in array `a`. Returns `a`.
"""
function add_entries!(a,b,combine=+)
  @assert length(a) == length(b)
  @inbounds for i in eachindex(a)
    a[i] = combine(a[i],b[i])
  end
  a
end

"""
    add_entry!(A,v,i,j,combine=+)

Add an entry given its position and the operation to perform.
"""
function add_entry!(A,v,i::Integer,j::Integer,combine=+)
  aij = A[i,j]
  A[i,j] = combine(aij,v)
end

"""
    add_entry!(A,v,i,combine=+)

Add an entry given its position and the operation to perform.
"""
function add_entry!(A,v,i::Integer,combine=+)
  ai = A[i]
  A[i] = combine(ai,v)
end

"""
    scale_entries!(a,v)

Scale the entries of array `a` with the value `v`. Returns `a`.
"""
function scale_entries!(a,b)
  @inbounds for i in eachindex(a)
    a[i] = b*a[i]
  end
  a
end

# Base.mul!

"""
    muladd!(c,a,b)

Matrix multiply a*b and add to result to c. Returns c.
"""
function muladd!(c,a,b)
  _muladd!(c,a,b)
  c
end

@static if VERSION >= v"1.3"
  function _muladd!(c,a,b)
    mul!(c,a,b,1,1)
  end
else
  function _muladd!(c,a,b)
    @assert length(c) == size(a,1)
    @assert length(b) == size(a,2)
    @inbounds for j in 1:size(a,2)
      for i in 1:size(a,1)
        c[i] += a[i,j]*b[j]
      end
    end
  end
end
