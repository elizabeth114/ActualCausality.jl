module CausalUtils

using ..AExpressions, ..CompileUtils
using Distributions: Categorical
using MLStyle: @match

import MacroTools: striplines

export compilecausal, equalpos, acaused

function tostate(var)
  return Meta.parse("state.$(var)History[step]")
end
function tostate(var, field)
  return Meta.parse("state.$(var)History[step].$field")
end

function getstep(var)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
end

function tostateprev(var)
  return Meta.parse("state.$(var)History[max(0, step-1)]")
end

function tostateshort(var)
  return Meta.parse("state.$(var)History")
end

function convertprev(next_value, data)
  if next_value in keys(data["types"])
    return tostateprev(next_value)
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
    varname = ""
    eval_clause2 = Meta.quot(mapped2)
    if mapped2.head == :(=)
      varname = Meta.quot(mapped2.args[1])
      mapped2 = Expr(:call, :(==), mapped2.args...)
    end
    quote_clause = Meta.quot(mapped1)
    quote_clause2 = Meta.quot(mapped2)

    ifstatement = quote
      if (eval($quote_clause))
        varstore = eval(a.args[2])
        for val in possiblevalues(a.args[2], eval(a.args[3]), restrictedvalues)
          if isfield(a.args[2])
            eval(Expr(:(=), a.args[2], val))
          else
            push!(reduce(a.args[2]), getstep(a.args[2]) =>val)
          end
          if !(eval($quote_clause))
            if isfield(a.args[2])
              eval(Expr(:(=), a.args[2], varstore))
            else
              push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
            end
            push!(causes, $(quote_clause2))
            break
          end
          if isfield(a.args[2])
            eval(Expr(:(=), a.args[2], varstore))
          else
            push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
          end
        end
        if isfield(a.args[2])
          eval(Expr(:(=), a.args[2], varstore))
        else
          push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
        end

        varstore = eval(a.args[3])

        store = eval(increment(($eval_clause2).args[1]))

        posssvals = possiblevalues(a.args[2], eval(a.args[3]), restrictedvalues)
        # store = eval(($eval_clause2).args[1])
        evaled = eval($eval_clause2)
        push!(reduce(($eval_clause2).args[1]), getstep(a.args[2]) => store)
        fields = fieldnames(typeof(eval(evaled)))
        for field in fields
          if field == :render
            continue
          end

          storefield = getfield(store, field)
          prevval = getfield(evaled, field)
          key = ((eval($eval_clause2).id, field))
          if !(key in keys(newDict))
            push!(newDict, key => [])
          end
          for val in posssvals
            if isfield(a.args[2])
              eval(Expr(:(=), a.args[2], val))
            else
              push!(reduce(a.args[2]), getstep(a.args[2]) =>val)
            end
            newval = getfield(eval($eval_clause2), field)
            if newval != prevval
              if isfield(a.args[2])
                eval(Expr(:(=), a.args[2], varstore))
              else
                push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
              end
              push!(reduce(($eval_clause2).args[1]), getstep(a.args[2]) => store)
              push!(causes, Expr(:call, :(==), Meta.parse(join([totime($varname), field], ".")), prevval))
              # break
            end
            if !(newval in values(newDict[key]))
              push!(newDict[key], newval)
            end
            push!(reduce(($eval_clause2).args[1]), getstep(a.args[2]) => store)



            if isfield(a.args[2])
               eval(Expr(:(=), a.args[2], varstore))
            else
              push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
            end
          end
          push!(reduce(($eval_clause2).args[1]), step => store)
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
      new_expr = convertprev(next_value.args[2], data)
    else
      new_expr = convertprev(next_value, data)
    end
    shortmap = tostateshort(clause.args[1])
    ifstatement = quote
      varstore = a.args[3]
      if length(fieldnames(typeof(eval($mapped)))) == 0 || getstep(a.args[2]) == 0
        if (reducenoeval(a.args[2]) == reducenoeval($mapped))
          if step == 0 && getstep(a.args[2]) == 0
            push!(causes, Expr(:call, :(==), (increment(a.args[2])), a.args[3]))
          else
            push!(causes, Expr(:call, :(==), (increment(a.args[2])), $new_expr))
          end
        end
      end
      for field in fieldnames(typeof(eval($mapped)))
        if field == :render
          continue
        end
        prevval = getfield(eval($new_expr), field)
        key = ((eval($new_expr).id, field))
        if !(key in keys(newDict))
          push!(newDict, key => [])
        end
        for val in possiblevalues(a.args[2], eval(a.args[3]), restrictedvalues)
          if isfield(a.args[2])
            eval(Expr(:(=), a.args[2], val))
          else
            push!(reduce(a.args[2]), getstep(a.args[2]) =>val)
          end
          newval = getfield(eval($new_expr), field)
          if prevval != newval
            if isfield(a.args[2])
              eval(Expr(:(=), a.args[2], varstore))
            else
              push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
            end
            push!(causes, Expr(:call, :(==), Meta.parse(join([increment($mapped), field], ".")), prevval))
            if isfield(a.args[2])
              eval(Expr(:(=), a.args[2], varstore))
            else
              push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
            end
            # break
          end
          if !(newval in values(newDict[key]))
            push!(newDict[key], newval)
          end
          if isfield(a.args[2])
            eval(Expr(:(=), a.args[2], varstore))
          else
            push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
          end
        end
        if isfield(a.args[2])
          eval(Expr(:(=), a.args[2], varstore))
        else
          push!(reduce(a.args[2]), getstep(a.args[2]) =>varstore)
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
    function a_causes(a, restrictedvalues)
      newDict = Dict()
      causes = []
      if a.args[1] == :(==)
        $(in_clauses...)
        $(on_clauses...)
      end
      for pair in newDict
        push!(restrictedvalues, pair)
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
