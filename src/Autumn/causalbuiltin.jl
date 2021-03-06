module CausalBuiltIn
using Random
using MLStyle
import Base.Cartesian.lreplace
using Distributions: Categorical

export builtin

builtin = quote
abstract type Object end
abstract type KeyPress end

struct Left <: KeyPress end
struct Right <: KeyPress end
struct Up <: KeyPress end
struct Down <: KeyPress end

struct Click
  x::Int
  y::Int
end

mutable struct Position
  x::Int
  y::Int
end

struct Cell
  position::Position
  color::String
  opacity::Float64
end

Cell(position::Position, color::String) = Cell(position, color, 0.8)
Cell(x::Int, y::Int, color::String) = Cell(Position(floor(Int, x), floor(Int, y)), color, 0.8)
Cell(x::Int, y::Int, color::String, opacity::Float64) = Cell(Position(floor(Int, x), floor(Int, y)), color, opacity)

struct Scene
  objects::Array{Object}
  background::String
end

Scene(objects::AbstractArray) = Scene(objects, "#ffffff00")

function render(scene::Scene)::Array{Cell}
  vcat(map(obj -> render(obj), filter(obj -> obj.alive && !obj.hidden, scene.objects))...)
end

function render(obj::Object)::Array{Cell}
  map(cell -> Cell(move(cell.position, obj.origin), cell.color), obj.render)
end

function isWithinBounds(obj::Object)::Bool
  # println(filter(cell -> !isWithinBounds(cell.position),render(obj)))
  length(filter(cell -> !isWithinBounds(cell.position), render(obj))) == 0
end

function clicked(click::Union{Click, Nothing}, object)::Bool
  if click == nothing
    false
  else
    GRID_SIZE = state.GRID_SIZEHistory[0]
    nums = map(cell -> GRID_SIZE*cell.position.y + cell.position.x, render(object))
    (GRID_SIZE * click.y + click.x) in nums
  end
end

function clicked(click::Union{Click, Nothing}, objects::AbstractArray)
  # println("LOOK AT ME")
  # println(reduce(&, map(obj -> clicked(click, obj), objects)))
  reduce(|, map(obj -> clicked(click, obj), objects))
end

function objClicked(click::Union{Click, Nothing}, objects::AbstractArray)::Object
  filter(obj -> clicked(click, obj), objects)[1]
end

function clicked(click::Union{Click, Nothing}, x::Int, y::Int)::Bool
  if click == nothing
    false
  else
    click.x == x && click.y == y
  end
end

function clicked(click::Union{Click, Nothing}, pos::Position)::Bool
  if click == nothing
    false
  else
    click.x == pos.x && click.y == pos.y
  end
end

function intersects(obj1::Object, obj2::Object)::Bool
  nums1 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, render(obj1))
  nums2 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, render(obj2))
  length(intersect(nums1, nums2)) != 0
end

function intersects(obj1::Object, obj2::Array{<:Object})::Bool
  nums1 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, render(obj1))
  nums2 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, vcat(map(render, obj2)...))
  length(intersect(nums1, nums2)) != 0
end

# function intersects(list1, list2)::Bool
#   length(intersect(list1, list2)) != 0
# end

function intersects(object::Object)::Bool
  objects = state.scene.objects
  intersects(object, objects)
end

function addObj(list::Array{<:Object}, obj::Object)
  new_list = vcat(list, obj)
  new_list
end

function addObj(list::Array{<:Object}, objs::Array{<:Object})
  new_list = vcat(list, objs)
  new_list
end

function removeObj(list::Array{<:Object}, obj::Object)
  filter(x -> x.id != obj.id, list)
end

function removeObj(list::Array{<:Object}, fn)
  orig_list = filter(obj -> !fn(obj), list)
end

function removeObj(obj::Object)
  obj.alive = false
  deepcopy(obj)
end

function updateObj(obj, field::String, value)
  fields = fieldnames(typeof(obj))
  custom_fields = fields[5:end-1]
  origin_field = (fields[2],)

  constructor_fields = (custom_fields..., origin_field...)
  constructor_values = map(x -> x == Symbol(field) ? value : getproperty(obj, x), constructor_fields)

  new_obj = typeof(obj)(constructor_values...)
  setproperty!(new_obj, :id, obj.id)
  setproperty!(new_obj, :alive, obj.alive)
  setproperty!(new_obj, :hidden, obj.hidden)

  setproperty!(new_obj, Symbol(field), value)
  new_obj
end

function filter_fallback(obj::Object)
  true
end

Base.:(==)(a::Position, b::Position) = equalPosition(a, b)

function equalPosition(a, b)
  return a.x == b.x && a.y == b.y
end

function updateObj(list::Array{<:Object}, map_fn, filter_fn=filter_fallback)
  orig_list = filter(obj -> !filter_fn(obj), list)
  filtered_list = filter(filter_fn, list)
  new_filtered_list = map(map_fn, filtered_list)
  vcat(orig_list, new_filtered_list)
end

function adjPositions(position::Position)::Array{Position}
  filter(isWithinBounds, [Position(position.x, position.y + 1), Position(position.x, position.y - 1), Position(position.x + 1, position.y), Position(position.x - 1, position.y)])
end

function isWithinBounds(position::Position)::Bool
  (position.x >= 0) && (position.x < state.GRID_SIZEHistory[0]) && (position.y >= 0) && (position.y < state.GRID_SIZEHistory[0])
end

function isFree(position::Position)::Bool
  length(filter(cell -> cell.position.x == position.x && cell.position.y == position.y, render(state.scene))) == 0
end

function isFree(click::Union{Click, Nothing})::Bool
  if click == nothing
    false
  else
    isFree(Position(click.x, click.y))
  end
end

function unitVector(position1::Position, position2::Position)::Position
  deltaX = position2.x - position1.x
  deltaY = position2.y - position1.y
  if (floor(Int, abs(sign(deltaX))) == 1 && floor(Int, abs(sign(deltaY))) == 1)
    uniformChoice([Position(sign(deltaX), 0), Position(0, sign(deltaY))])
  else
    Position(sign(deltaX), sign(deltaY))
  end
end

function unitVector(object1::Object, object2::Object)::Position
  position1 = object1.origin
  position2 = object2.origin
  unitVector(position1, position2)
end
function unitVector(object1, object2)::Position
  position1 = object1.origin
  position2 = object2.origin
  deltaX = position2.x - position1.x
  deltaY = position2.y - position1.y
  if (floor(Int, abs(sign(deltaX))) == 1 && floor(Int, abs(sign(deltaY))) == 1)
    uniformChoice([Position(sign(deltaX), 0), Position(0, sign(deltaY))])
  else
    Position(sign(deltaX), sign(deltaY))
  end
end

function unitVector(object::Object, position::Position)::Position
  unitVector(object.origin, position)
end

function unitVector(position::Position, object::Object)::Position
  unitVector(position, object.origin)
end

function unitVector(position::Position)::Position
  unitVector(Position(0,0), position)
end

function displacement(position1::Position, position2::Position)::Position
  Position(floor(Int, position2.x - position1.x), floor(Int, position2.y - position1.y))
end

function displacement(cell1::Cell, cell2::Cell)::Position
  displacement(cell1.position, cell2.position)
end

function adjacent(position1::Position, position2::Position):Bool
  displacement(position1, position2) in [Position(0,1), Position(1, 0), Position(0, -1), Position(-1, 0)]
end

function adjacent(cell1::Cell, cell2::Cell)::Bool
  adjacent(cell1.position, cell2.position)
end

function adjacent(cell::Cell, cells::Array{Cell})
  length(filter(x -> adjacent(cell, x), cells)) != 0
end

function rotate(object::Object)::Object
  new_object = deepcopy(object)
  new_object.render = map(x -> Cell(rotate(x.position), x.color), new_object.render)
  new_object
end

function rotate(position::Position)::Position
  Position(-position.y, position.x)
 end

function rotateNoCollision(object::Object)::Object
  (isWithinBounds(rotate(object)) && isFree(rotate(object), object)) ? rotate(object) : object
end

function move(position1::Position, position2::Position)
  Position(position1.x + position2.x, position1.y + position2.y)
end

function move(position::Position, cell::Cell)
  Position(position.x + cell.position.x, position.y + cell.position.y)
end

function move(cell::Cell, position::Position)
  Position(position.x + cell.position.x, position.y + cell.position.y)
end

function move(object::Object, position::Position)
  new_object = deepcopy(object)
  new_object.origin = move(object.origin, position)
  new_object
end

function move(object, position::Position)
  new_object = deepcopy(object)
  new_origin = move(Position(object.origin.x, object.origin.y), position)
  new_object.origin.x = new_origin.x
  new_object.origin.y = new_origin.y
    new_object
end

function move(object::Object, x::Int, y::Int)::Object
  move(object, Position(x, y))
end

function moveNoCollision(object::Object, position::Position)::Object
  (isWithinBounds(move(object, position)) && isFree(move(object, position.x, position.y), object)) ? move(object, position.x, position.y) : object
end

function moveNoCollision(object::Object, x::Int, y::Int)
  (isWithinBounds(move(object, x, y)) && isFree(move(object, x, y), object)) ? move(object, x, y) : object
end

function moveWrap(object::Object, position::Position)::Object
  new_object = deepcopy(object)
  new_object.position = moveWrap(object.origin, position.x, position.y)
  new_object
end

function moveWrap(cell::Cell, position::Position)
  moveWrap(cell.position, position.x, position.y)
end

function moveWrap(position::Position, cell::Cell)
  moveWrap(cell.position, position)
end

function moveWrap(object::Object, x::Int, y::Int)::Object
  new_object = deepcopy(object)
  new_object.position = moveWrap(object.origin, x, y)
  new_object
end

function moveWrap(position1::Position, position2::Position)::Position
  moveWrap(position1, position2.x, position2.y)
end

function moveWrap(position::Position, x::Int, y::Int)::Position
  GRID_SIZE = state.GRID_SIZEHistory[0]
  # println("hello")
  # println(Position((position.x + x + GRID_SIZE) % GRID_SIZE, (position.y + y + GRID_SIZE) % GRID_SIZE))
  Position((position.x + x + GRID_SIZE) % GRID_SIZE, (position.y + y + GRID_SIZE) % GRID_SIZE)
end

function randomPositions(GRID_SIZE::Int, n::Int)::Array{Position}
  nums = uniformChoice([0:(GRID_SIZE * GRID_SIZE - 1);], n)
  # println(nums)
  # println(map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums))
  map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums)
end

function distance(position1::Position, position2::Position)::Int
  abs(position1.x - position2.x) + abs(position1.y - position2.y)
end

function distance(object1::Object, object2::Object)::Int
  position1 = object1.origin
  position2 = object2.origin
  distance(position1, position2)
end

function distance(object::Object, position::Position)::Int
  distance(object.origin, position)
end

function distance(position::Position, object::Object)::Int
  distance(object.origin, position)
end

function closest(object::Object, type::DataType)::Position
  objects_of_type = filter(obj -> (obj isa type) && (obj.alive), state.scene.objects)
  if length(objects_of_type) == 0
    object.origin
  else
    min_distance = min(map(obj -> distance(object, obj), objects_of_type))
    filter(obj -> distance(object, obj) == min_distance, objects_of_type)[1].origin
  end
end

function mapPositions(constructor, GRID_SIZE::Int, filterFunction, args...)::Union{Object, Array{<:Object}}
  map(pos -> constructor(args..., pos), filter(filterFunction, allPositions(GRID_SIZE)))
end

function allPositions(GRID_SIZE::Int)
  nums = [0:(GRID_SIZE * GRID_SIZE - 1);]
  map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums)
end

function updateOrigin(object::Object, new_origin::Position)::Object
  new_object = deepcopy(object)
  new_object.origin = new_origin
  new_object
end

function updateAlive(object::Object, new_alive::Bool)::Object
  new_object = deepcopy(object)
  new_object.alive = new_alive
  new_object
end

function nextLiquid(object::Object)::Object
  # println("nextLiquid")
  GRID_SIZE = state.GRID_SIZEHistory[0]
  new_object = deepcopy(object)
  if object.origin.y != GRID_SIZE - 1 && isFree(move(object.origin, Position(0, 1)))
    new_object.origin = move(object.origin, Position(0, 1))
  else
    leftHoles = filter(pos -> (pos.y == object.origin.y + 1)
                               && (pos.x < object.origin.x)
                               && isFree(pos), allPositions())
    rightHoles = filter(pos -> (pos.y == object.origin.y + 1)
                               && (pos.x > object.origin.x)
                               && isFree(pos), allPositions())
    if (length(leftHoles) != 0) || (length(rightHoles) != 0)
      if (length(leftHoles) == 0)
        closestHole = closest(object, rightHoles)
        if isFree(move(closestHole, Position(0, -1)), move(object.origin, Position(1, 0)))
          new_object.origin = move(object.origin, unitVector(object, move(closestHole, Position(0, -1))))
        end
      elseif (length(rightHoles) == 0)
        closestHole = closest(object, leftHoles)
        if isFree(move(closestHole, Position(0, -1)), move(object.origin, Position(-1, 0)))
          new_object.origin = move(object.origin, unitVector(object, move(closestHole, Position(0, -1))))
        end
      else
        closestLeftHole = closest(object, leftHoles)
        closestRightHole = closest(object, rightHoles)
        if distance(object.origin, closestLeftHole) > distance(object.origin, closestRightHole)
          if isFree(move(object.origin, Position(1, 0)), move(closestRightHole, Position(0, -1)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestRightHole, Position(0, -1))))
          elseif isFree(move(closestLeftHole, Position(0, -1)), move(object.origin, Position(-1, 0)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestLeftHole, Position(0, -1))))
          end
        else
          if isFree(move(closestLeftHole, Position(0, -1)), move(object.origin, Position(-1, 0)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestLeftHole, Position(0, -1))))
          elseif isFree(move(object.origin, Position(1, 0)), move(closestRightHole, Position(0, -1)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestRightHole, Position(0, -1))))
          end
        end
      end
    end
  end
  new_object
end

function range(start::Int, stop::Int)
  [start:stop;]
end

function nextSolid(object::Object)::Object
  # println("nextSolid")
  GRID_SIZE = state.GRID_SIZEHistory[0]
  new_object = deepcopy(object)
  if (isWithinBounds(move(object, Position(0, 1))) && reduce(&, map(x -> isFree(x, object), map(cell -> move(cell.position, Position(0, 1)), render(object)))))
    new_object.origin = move(object.origin, Position(0, 1))
  end
  new_object
end

function closest(object::Object, positions::Array{Position})::Position
  closestDistance = sort(map(pos -> distance(pos, object.origin), positions))[1]
  closest = filter(pos -> distance(pos, object.origin) == closestDistance, positions)[1]
  closest
end

function isFree(start::Position, stop::Position)::Bool
  GRID_SIZE = state.GRID_SIZEHistory[0]
  nums = [(GRID_SIZE * start.y + start.x):(GRID_SIZE * stop.y + stop.x);]
  reduce(&, map(num -> isFree(Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE))), nums))
end

function isFree(start::Position, stop::Position, object::Object)::Bool
  GRID_SIZE = state.GRID_SIZEHistory[0]
  nums = [(GRID_SIZE * start.y + start.x):(GRID_SIZE * stop.y + stop.x);]
  reduce(&, map(num -> isFree(Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), object), nums))
end

function isFree(position::Position, object::Object)
  length(filter(cell -> cell.position.x == position.x && cell.position.y == position.y,
  filter(x -> !(x in render(object)), render(state.scene)))) == 0
end

function isFree(object::Object, orig_object::Object)::Bool
  reduce(&, map(x -> isFree(x, orig_object), map(cell -> cell.position, render(object))))
end

function allPositions()
  GRID_SIZE = state.GRID_SIZEHistory[0]
  nums = [1:GRID_SIZE*GRID_SIZE - 1;]
  map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums)
end
# uniformChoice(freePositions) = uniformChoice(1, freePositions)

function uniformChoice(rng, freePositions)
  freePositions[rand(rng, Categorical(ones(length(freePositions))/length(freePositions)))]
end

function uniformChoice(rng, freePositions, n)
  map(idx -> freePositions[idx], rand(rng, Categorical(ones(length(freePositions))/length(freePositions)), n))
end

function intersects(obj1, obj2)
  obj1.origin.x == obj2.origin.x && obj1.origin.y == obj2.origin.y
end

intersects(obj1::Array, obj2) = intersects(obj2, obj1)

function intersects(obj1, obj2::Array)
  for obj in obj2
    if obj1.origin == obj.origin
      return true
    end
  end
  false
end

function tostate(var)
  return Meta.parse("state.$(var)History[step]")
end

function totime(var)
  raw = reducenoeval(var)
  return Meta.parse("$(raw)[$(state.time)+1]")
end

function tostate(var, field)
  return Meta.parse("state.$(var)History[step].$field")
end

function tostateshort(var)
  return Meta.parse("state.$(var)History")
end

function isfield(var)
  (length(split(string(var), "].")) > 1 || length(split(string(var), ").")) > 1)
end

function getfieldnames(var)
  split_ = split(string(var), "].")
  if length(split_) > 1
    return split(split_[2], ".")
  end
  split(split(string(var), ").")[2], ".")
end

function reducenoeval(var)
  strvar = replace(string(var), "(" => "")
  strvar = replace(strvar, ")" => "")
  split_ = split(strvar, "[")
  Meta.parse(split_[1])
end

function reducetostep(var)
  strvar = replace(string(var), "(" => "")
  strvar = replace(strvar, ")" => "")
  split_ = split(strvar, "[")
  split1 = split_[1]
  split2 = split(split_[2], "]")[2]
  Meta.parse("$(split1)[step]$(split2)")
end


function pushbyfield(var, val)
  if isfield(a.args[2])
    eval(Expr(:(=), a.args[2], val))
  else
    push!(reduce(a.args[2]), step =>val)
  end
end

function fakereduce(var)
  Meta.parse(string(var))
end

function reduce(var)
  strvar = replace(string(var), "(" => "")
  strvar = replace(strvar, ")" => "")
  split_ = split(strvar, "[")
  eval(Meta.parse(split_[1]))
end

function getstep(var)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
end

function increment(var::Expr)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
  if index == :step
    return eval(Meta.parse(join([split_1[1], "[step]", split_2[2]])))
  end
  return Meta.parse(join([split_1[1], "[", string(state.time), "]", split_2[2]]))
end

function incrementfr(var::Expr)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
  if index == :step
    return eval(Meta.parse(join([split_1[1], "[step]", split_2[2]])))
  end
  return Meta.parse(join([split_1[1], "[", string(index + 1), "]", split_2[2]]))
end

function decrement(var::Expr)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
  if index == :step
    return eval(Meta.parse(join([split_1[1], "[step]", split_2[2]])))
  elseif index == 0
    return eval(Meta.parse(join([split_1[1], "[0]", split_2[2]])))
  end
  return Meta.parse(join([split_1[1], "[", string(index - 1), "]", split_2[2]]))
end

function possvals(val::Bool)
  [true, false]
end

function possvals(val::Union{BigInt, Int64})
  [-2^4:1:(2^4);]
end

function possvals(val::Expr)
  possvals(eval(val))
end

function possvalspos(val)
  vals = []
  for x in 0:16
    for y in 0:16
      push!(vals, Base.invokelatest(typeof(val), x, y))
    end
  end
  vals
end

function possiblevalues(var::Expr, val, restrictedvalues)
  try
    id = eval(reduce(var))[0].id
    field = Meta.parse(getfieldnames(var)[1])
    key = (id, field)
    if key in keys(restrictedvalues)
      return eval(restrictedvalues[key])
    end
  catch e
  end
  
  if :x in (fieldnames(typeof(val))) && :y in (fieldnames(typeof(val)))
    return possvalspos(val)
  end
  return possvals(val)
end

function wallintersect(ball)
  direction = ball.direction
  if ball.origin.y == 15
    if (direction < 180 && direction > 90)
      return 180 - direction
    elseif (direction == 180)
      return 0
    elseif (direction > 180 && direction <270)
      return 90 + direction
    end
  elseif ball.origin.x == 0
    if (direction < 270) && (direction > 180)
      return 360 - direction
    elseif direction == 270
      return 90
    elseif direction > 270
      return 360 - direction
    end
  elseif ball.origin.x == 15
    if direction < 90
      return 270 + direction
    elseif direction == 90
      return 270
    elseif direction > 90 && direction < 180
      return 90 + direction
    end
  elseif ball.origin.y == 0
    if direction > 270
      return 540 - direction
    elseif direction == 0
      return 180
    elseif direction < 90
      return 180 - direction
    end
  end
  return direction
end

function nextBall(ball)
  direction = ball.direction
  origin = ball.origin
  if direction < 45
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x, origin.y-1))
  elseif direction < 90
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x+1, origin.y-1))
  elseif direction < 135
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x+1, origin.y))
  elseif direction < 180
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x+1, origin.y+1))
  elseif direction < 225
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x, origin.y+1))
  elseif direction < 270
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x-1, origin.y+1))
  elseif direction < 315
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x-1, origin.y))
  elseif direction < 360
    return updateObj(ball, "origin", typeof(ball.origin)(origin.x-1, origin.y-1))

  end
  return ball
end

function ballcollision(ball1, ball2)
  difference = abs(ball1.direction - ball2.direction)
  if ball1.direction > 360
    return ball2.direction
  elseif ball2.direction >= 360
    return (ball1.direction + 180) % 360
  elseif (ball1.direction + 180) ÷ 45 == ball2.direction ÷ 45
    return (ball1.direction + 180) % 360
  elseif difference > 45
    if ball1.direction < 90 || (ball1.direction >= 180 && ball1.direction <270)
      return ball1.direction + 90
    else return ball1.direction - 90
    end
  end
  return ball2.direction
end

function equalPos(val1, val2)
  try
    return eval(val1).x == eval(val2).x && eval(val1).y == eval(val2).y
  catch e
    return false
  end
  false
end

function acaused(cause_a::Expr, cause_b::Expr, restrictedvalues)
  if (eval(cause_b) && eval(cause_a)) || equalPos(cause_a.args[2], cause_a.args[3])
    varstore = eval(cause_a.args[2])
    short = eval(reduce(cause_a.args[2]))
    index = getstep(cause_a.args[2])
    for val in possiblevalues(cause_a.args[2], cause_a.args[3], restrictedvalues)
      # println("start of val println")
      # println(val)
      # println(cause_a.args[2])
      # println(cause_b)
      # println(eval(cause_b))
      if isfield(cause_a.args[2])
        eval(Expr(:(=), cause_a.args[2], val))
      else
        push!(reduce(cause_a.args[2]), getstep(cause_a.args[2]) =>val)
      end
      if !(eval(cause_b))
        if isfield(cause_a.args[2])
          eval(Expr(:(=), cause_a.args[2], varstore))
        else
          push!(reduce(cause_a.args[2]), getstep(cause_a.args[2]) =>varstore)
        end
        return true
        break
      end
    end
    if isfield(cause_a.args[2])
      eval(Expr(:(=), cause_a.args[2], varstore))
    else
      push!(reduce(cause_a.args[2]), getstep(cause_a.args[2]) =>varstore)
    end
  end
  false
end

function tryb(cause_b)
  try
    return eval(cause_b)
  catch e
    return false
  end
end

end
end
