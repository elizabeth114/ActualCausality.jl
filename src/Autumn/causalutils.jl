module CausalUtils

using ..AExpressions, ..CompileUtils
using Distributions: Categorical
using MLStyle: @match

import MacroTools: striplines

export compilecausal, tryb, equalpos, acaused

function tostate(var)
  return Meta.parse("state.$(var)History[step]")
end
function tostate(var, field)
  return Meta.parse("state.$(var)History[step].$field")
end

function tostateshort(var)
  return Meta.parse("state.$(var)History")
end

function convertprev(next_value, data)
  if next_value in keys(data["types"])
    return tostate(next_value)
  end
  return next_value
end


function replacelambda(lambdaval, next_value)
  if next_value == lambdaval
    return :(state.rocksHistory[step][1])
  end
  return next_value
end

function replacelambda(lambdaval, next_value::Union{Expr, AExpr})
  for index in 1:length(next_value.args)
    next_value.args[index] = replacelambda(lambdaval, next_value.args[index])
  end
end

function convertprev(next_value::Union{AExpr, Expr}, data)
  new_expr = []
  if next_value.head == :lambda
    replacelambda(next_value.args[1], next_value)
  end
  if length(next_value.args) == 2 && next_value.args[1] == :prev
    store = convertprev(next_value.args[2], data)
    return store
  end
  for index in 1:length(next_value.args)
      push!(new_expr, convertprev(next_value.args[index], data))
  end
  if next_value.head == :if
    return Expr(:if, new_expr...)
  end
  if next_value.head == :(.)
    for index in 1:length(next_value.args)
      next_value.args[index] = new_expr[index]
    end
    return next_value
  end
  if next_value.head == :field
    join(new_expr, ".")
    return Meta.parse(join(new_expr, "."))
  end
  Expr(:call, :eval, Expr(:call, new_expr...))
end

function causalon(data)
  on_clauses = []
  for on_clause in data["on"]
    mapped1 = convertprev(copy(on_clause[1]), data)
    mapped2 = copy(on_clause[2])

    for index in 1:length(mapped2.args)
      mapped2.args[index] = convertprev(mapped2.args[index], data)
    end

    if mapped2.head == :(=)
      mapped2 = Expr(:call, :(==), mapped2.args...)
    end
    quote_clause = Meta.quot(mapped1)
    quote_clause2 = Meta.quot(mapped2)
    ifstatement = quote
      if (eval($quote_clause))
        varstore = eval(a.args[2])
        for val in possiblevalues(a.args[2], eval(a.args[3]))
          if isfield(a.args[2])
            eval(Expr(:(=), a.args[2], val))
          else
            push!(reduce(a.args[2]), step =>val)
          end
          if !(eval($quote_clause))
            if isfield(a.args[2])
              eval(Expr(:(=), a.args[2], varstore))
            else
              push!(reduce(a.args[2]), step =>varstore)
            end
            push!(causes, $(quote_clause2))
            break
          end
        end
        if isfield(a.args[2])
          eval(Expr(:(=), a.args[2], varstore))
        else
          push!(reduce(a.args[2]), step =>varstore)
        end
      end
    end
    push!(on_clauses, ifstatement)
  end
  on_clauses
end

function causalin(data)
  in_clauses = []
  for clause in data["initnext"]
    mapped = tostate(clause.args[1])
    mapped = Meta.quot(mapped)
    next_value = clause.args[2].args[2]
    new_expr = []
    if next_value.args[1] == :prev
      continue
    else
      new_expr = convertprev(next_value, data)
    end
    shortmap = tostateshort(clause.args[1])
    ifstatement = quote
      varstore = a.args[3]
      if length(fieldnames(typeof(eval($mapped)))) == 0
        push!(causes, Expr(:call, :(==), (increment(a.args[2])), $new_expr))
      end
        for field in fieldnames(typeof(eval($mapped)))
          if field == :render
            continue
          end
          prevval = getfield(eval($new_expr), field)
          for val in possiblevalues(a.args[2], eval(a.args[3]))
            if isfield(a.args[2])
              eval(Expr(:(=), a.args[2], val))
            else
              push!(reduce(a.args[2]), step =>val)
            end
            if prevval != getfield(eval($new_expr), field)
              if isfield(a.args[2])
                eval(Expr(:(=), a.args[2], varstore))
              else
                push!(reduce(a.args[2]), step =>varstore)
              end
              push!(causes, Expr(:call, :(==), Meta.parse(join([increment($mapped), field], ".")), prevval))
              if isfield(a.args[2])
                eval(Expr(:(=), a.args[2], varstore))
              else
                push!(reduce(a.args[2]), step =>varstore)
              end
              break
            end
          end
        if isfield(a.args[2])
          eval(Expr(:(=), a.args[2], varstore))
        else
          push!(reduce(a.args[2]), step =>varstore)
        end
      end
    end
    push!(in_clauses, ifstatement)
    end
  in_clauses
end

function compilecausal(data)
  on_clauses = causalon(data)
  in_clauses = causalin(data)
  expr = quote
    function a_causes(a)
      causes = []
      if a.args[1] == :(==)
        $(on_clauses...)
        $(in_clauses...)
      end
      if length(causes) == 0
        return [a]
      else
        return causes
      end
    end
    $(data["functions"]...)
  end
end

end
