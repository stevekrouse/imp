module Flows

using Data
using Query

abstract Flow

type Create <: Flow
  output_name::Symbol
  keys::Vector{Type}
  vals::Vector{Type}
end

type Merge <: Flow
  output_name::Symbol
  input_names::Vector{Symbol}
  meta::Any
  eval::Function
end

type Sequence <: Flow
  flows::Vector{Flow}
end

type Fixpoint <: Flow
  flow::Flow
end

function output_names(create::Create)
  Set(create.output_name)
end

function output_names(merge::Merge)
  Set(merge.output_name)
end

function output_names(sequence::Sequence)
  union(map(output_names, sequence.flows)...)
end

function output_names(fixpoint::Fixpoint)
  output_names(fixpoint.flow)
end

function (create::Create)(inputs::Dict{Symbol, Relation})
  output = Relation(tuple((Vector{typ}() for typ in [create.keys..., create.vals...])...), length(create.keys))
  inputs[create.output_name] = output
end

function (merge::Merge)(inputs::Dict{Symbol, Relation})
  output = merge.eval(map((name) -> inputs[name], merge.input_names)...)
  inputs[merge.output_name] = Base.merge(inputs[merge.output_name], output)
end

function (sequence::Sequence)(inputs::Dict{Symbol, Relation})
  for flow in sequence.flows
    flow(inputs)
  end
end

function (fixpoint::Fixpoint)(inputs::Dict{Symbol, Relation})
  names = output_names(fixpoint.flow)
  while true
    old_values = map((name) -> inputs[name], names)
    fixpoint.flow(inputs)
    new_values = map((name) -> inputs[name], names)
    if old_values == new_values
      return
    end
  end
end

macro create(relation)
  (name, keys, vals) = parse_relation(relation)
  :(Create($(Expr(:quote, name)), [$(map(esc, keys)...)], [$(map(esc, vals)...)]))
end

macro merge(query)
  (clauses, vars, created_vars, input_names, return_clause) = Query.parse_query(query)
  code = Query.plan_query(clauses, vars, created_vars, input_names, return_clause, Set())
  escs = [:($(esc(input_name)) = $input_name) for input_name in input_names]
  code = quote
    $(escs...)
    $code
  end
  :(Merge($(Expr(:quote, return_clause.name)), $(collect(input_names)), $(Expr(:quote, query)), $(Expr(:->, Expr(:tuple, input_names...), code))))
end

type World
  inputs::Dict{Symbol, Relation}
  flow::Flow
  outputs::Dict{Symbol, Relation}
  watchers::Set{Any}
end

function World()
  World(Dict{Symbol, Relation}(), Sequence([]), Dict{Symbol, Relation}(), Set{Any}())
end

function refresh(world::World)
  old_outputs = world.outputs
  new_outputs = copy(world.inputs)
  world.outputs = new_outputs
  world.inputs = new_outputs # TODO this is a temporary kludge, till I figure out how to handle asnyc events
  world.flow(new_outputs)
  for watcher in world.watchers
    watcher(old_outputs, new_outputs)
  end
end

function Base.getindex(world::World, name::Symbol)
  world.outputs[name]
end

function Base.setindex!{R <: Relation}(world::World, input::R, name::Symbol)
  world.inputs[name] = input
  refresh(world)
end

function setflow(world::World, flow::Flow)
  world.flow = flow
  refresh(world)
end

function watch(watcher, world::World)
  push!(world.watchers, watcher)
end

export Create, Merge, Sequence, Fixpoint, @create, @merge, World, watch, setflow, refresh

end
