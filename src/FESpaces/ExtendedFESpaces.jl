

struct ExtendedVector{T,A,B} <: AbstractVector{T}
  void_to_val::A
  cell_to_val::B
  oldcell_to_cell_or_void::Vector{Int}
  void_to_oldcell::Vector{Int}
  cell_to_oldcell::Vector{Int}
  function ExtendedVector(
    void_to_val::AbstractArray,
    cell_to_val::AbstractArray,
    oldcell_to_cell_or_void::Vector{Int},
    void_to_oldcell::Vector{Int},
    cell_to_oldcell::Vector{Int})

    A = typeof(void_to_val)
    B = typeof(cell_to_val)
    ai = testitem(void_to_val)
    bi = testitem(cell_to_val)
    T = eltype([ai,bi])

    new{T,A,B}(
      void_to_val,
      cell_to_val,
      oldcell_to_cell_or_void,
      void_to_oldcell,
      cell_to_oldcell)

  end
end

Base.size(a::ExtendedVector) = (length(a.oldcell_to_cell_or_void),)

Base.IndexStyle(::Type{<:ExtendedVector}) = IndexLinear()

function Base.getindex(a::ExtendedVector,i::Integer)
  cache = array_cache(a)
  getindex!(cache,a,i)
end

function array_cache(a::ExtendedVector)
  cv = array_cache(a.void_to_val)
  cc = array_cache(a.cell_to_val)
  (cv,cc)
end

@inline function getindex!(cache,a::ExtendedVector,oldcell)
  cv, cc = cache
  i = a.oldcell_to_cell_or_void[oldcell]
  if i > 0
    cell = i
    return getindex!(cc,a.cell_to_val,cell)
  else
    void = -i
    return getindex!(cv,a.void_to_val,void)
  end
end

function evaluate_field_array(a::ExtendedVector,x::AbstractArray)
  x_void = reindex(x,a.void_to_oldcell)
  x_cell = reindex(x,a.cell_to_oldcell)
  r_void = evaluate_field_array(a.void_to_val,x_void)
  r_cell = evaluate_field_array(a.cell_to_val,x_cell)
  ExtendedVector(
      r_void,
      r_cell,
      a.oldcell_to_cell_or_void,
      a.void_to_oldcell,
      a.cell_to_oldcell)
end

function evaluate_dof_array(dofs::AbstractArray,fields::ExtendedVector)
  _evaluate_dof_array_extended_fields(dofs,fields)
end

function evaluate_dof_array(dofs::AbstractArray{<:Dof},fields::ExtendedVector)
  _evaluate_dof_array_extended_fields(dofs,fields)
end

function _evaluate_dof_array_extended_fields(dofs,fields)
  dofs_void = reindex(dofs,fields.void_to_oldcell)
  dofs_cell = reindex(dofs,fields.cell_to_oldcell)
  r_void = evaluate_dof_array(dofs_void,fields.void_to_val)
  r_cell = evaluate_dof_array(dofs_cell,fields.cell_to_val)
  ExtendedVector(
      r_void,
      r_cell,
      fields.oldcell_to_cell_or_void,
      fields.void_to_oldcell,
      fields.cell_to_oldcell)
end

function reindex(a::ExtendedVector,ptrs::AbstractArray)
  _extended_reindex(a,ptrs)
end

function reindex(a::ExtendedVector,ptrs::IdentityVector)
  a
end

function reindex(a::ExtendedVector,ptrs::SkeletonPair)
  _extended_reindex(a,ptrs::SkeletonPair)
end

function apply(f::Fill,a::ExtendedVector...)
  a_void, a_cell = _split_void_non_void(a...)
  r_void = apply(f.value,a_void...)
  r_cell = apply(f.value,a_cell...)
  ExtendedVector(
      r_void,
      r_cell,
      a[1].oldcell_to_cell_or_void,
      a[1].void_to_oldcell,
      a[1].cell_to_oldcell)
end

function apply(::Type{T},f::Fill,a::ExtendedVector...) where T
  a_void, a_cell = _split_void_non_void(a...)
  r_void = apply(T,f.value,a_void...)
  r_cell = apply(T,f.value,a_cell...)
  ExtendedVector(
      r_void,
      r_cell,
      a[1].oldcell_to_cell_or_void,
      a[1].void_to_oldcell,
      a[1].cell_to_oldcell)
end

function _split_void_non_void(a::ExtendedVector...)
  @notimplementedif ! all(map(i->i.void_to_oldcell===a[1].void_to_oldcell,a))
  @notimplementedif ! all(map(i->i.cell_to_oldcell===a[1].cell_to_oldcell,a))
  a_void = map(i->i.void_to_val,a)
  a_cell = map(i->i.cell_to_val,a)
  a_void, a_cell
end

#function reindex(a::ExtendedVector,trian::Triangulation)
#  ptrs = get_cell_id(trian)
#  _extended_reindex(a,ptrs)
#end

function _extended_reindex(a,ptrs::SkeletonPair)
  left= _extended_reindex(a,ptrs.left)
  right = _extended_reindex(a,ptrs.right)
  SkeletonPair(left,right)
end

function _extended_reindex(a,ptrs::AbstractArray)
  if a.cell_to_oldcell === ptrs || a.cell_to_oldcell == ptrs
    return a.cell_to_val
  elseif a.void_to_oldcell === ptrs || a.void_to_oldcell == ptrs
    return a.void_to_val
  else
    j_to_oldcell = ptrs
    j_to_cell_or_void = a.oldcell_to_cell_or_void[j_to_oldcell]
    all_cell, all_void = _find_all_cell_all_void(j_to_cell_or_void)
    if all_cell
      return reindex(a.cell_to_val,j_to_cell_or_void)
    elseif all_void
      j_to_cell_or_void .*= -1
      return reindex(a.void_to_val,j_to_cell_or_void)
    else
      return Reindexed(a,ptrs)
    end
  end
end

function _find_all_cell_all_void(j_to_cell_or_void)
  all_cell = true
  all_void = true
  for k in j_to_cell_or_void
    all_cell = all_cell && (k>0)
    all_void = all_void && (k<0)
  end
  all_cell, all_void
end

struct VoidBasis{T,D} <: Field end

function field_cache(f::VoidBasis{T},x) where T
  Q = length(x)
  v = zeros(T,(Q,0))
  CachedArray(v)
end

@inline function evaluate_field!(cache,f::VoidBasis{T},x) where T
  Q = length(x)
  setsize!(cache,(Q,0))
  cache.array
end

function field_gradient(f::VoidBasis{T,D}) where {T,D}
  x = zero(Point{D,eltype(T)})
  G = gradient_type(T,x)
  VoidBasis{G,D}()
end

"""
"""
struct ExtendedFESpace <: SingleFieldFESpace
  space::SingleFieldFESpace
  trian::RestrictedTriangulation
end

constraint_style(::Type{ExtendedFESpace}) = Val{false}()

function get_cell_dofs(f::ExtendedFESpace)

  cell_to_val = get_cell_dofs(f.space)
  vi = testitem(cell_to_val)
  T = eltype(vi)
  void_to_val = Fill(T[],length(f.trian.void_to_oldcell))

  ExtendedVector(
    void_to_val,
    cell_to_val,
    f.trian.oldcell_to_cell,
    f.trian.void_to_oldcell,
    f.trian.cell_to_oldcell)

end

function get_cell_basis(f::ExtendedFESpace)
  cell_basis = get_cell_basis(f.space)
  cell_to_val = get_array(cell_basis)

  xi = testitem(get_cell_coordinates(f.trian))
  vi = testitem(cell_to_val)
  Tv = field_return_type(vi,xi)
  T = eltype(Tv)
  D = num_components(eltype(xi))
  void_to_val = Fill(VoidBasis{T,D}(),length(f.trian.void_to_oldcell))

  array = ExtendedVector(
    void_to_val,
    cell_to_val,
    f.trian.oldcell_to_cell,
    f.trian.void_to_oldcell,
    f.trian.cell_to_oldcell)

  cm = get_cell_map(f.trian.oldtrian)
  trial_style = TrialStyle(cell_basis)
  GenericCellBasis(trial_style,array,cm,RefStyle(cell_basis))
end

function get_cell_dof_basis(f::ExtendedFESpace)

  cell_to_val = get_cell_dof_basis(f.space)
  ref_trait = RefStyle(cell_to_val)
  cell_to_val = get_array(cell_to_val)

  D = num_dims(f.trian)
  T = Float64 # TODO
  void_to_val = Fill(LagrangianDofBasis(T,Point{D,T}[]),length(f.trian.void_to_oldcell))

  eb = ExtendedVector(
         void_to_val,
         cell_to_val,
         f.trian.oldcell_to_cell,
         f.trian.void_to_oldcell,
         f.trian.cell_to_oldcell)

  cell_dof_basis = GenericCellDofBasis(ref_trait,eb)

end

function scatter_free_and_dirichlet_values(f::ExtendedFESpace,fv,dv)

  cell_to_val = scatter_free_and_dirichlet_values(f.space,fv,dv)
  T = eltype(fv)
  void_to_val = Fill(T[],length(f.trian.void_to_oldcell))

  ExtendedVector(
    void_to_val,
    cell_to_val,
    f.trian.oldcell_to_cell,
    f.trian.void_to_oldcell,
    f.trian.cell_to_oldcell)
end

function gather_free_and_dirichlet_values!(fv,dv,f::ExtendedFESpace,cv)
  _cv = reindex(cv,f.trian.cell_to_oldcell)
  gather_free_and_dirichlet_values!(fv,dv,f.space,_cv)
end

# Delegated functions

function num_free_dofs(f::ExtendedFESpace)
  num_free_dofs(f.space)
end

function zero_free_values(f::ExtendedFESpace)
  zero_free_values(f.space)
end

function num_dirichlet_dofs(f::ExtendedFESpace)
  num_dirichlet_dofs(f.space)
end

function zero_dirichlet_values(f::ExtendedFESpace)
  zero_dirichlet_values(f.space)
end

function num_dirichlet_tags(f::ExtendedFESpace)
  num_dirichlet_tags(f.space)
end

function get_dirichlet_dof_tag(f::ExtendedFESpace)
  get_dirichlet_dof_tag(f.space)
end

function TrialFESpace(f::ExtendedFESpace)
  U = TrialFESpace(f.space)
  ExtendedFESpace(U,f.trian)
end
