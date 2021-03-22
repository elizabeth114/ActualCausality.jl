"Compilation to Julia"
module Causal
using Random

using ..AExpressions, ..SExpr, ..CompileUtils, ..CausalUtils, ..Compile, ..CausalBuiltIn
import MacroTools: striplines

export getcausal, test_ac

function getcausal(aexpr::AExpr)
  # dictionary containing types/definitions of global variables, for use in constructing init func.,
  # next func., etcetera; the three categories of global variable are external, initnext, and lifted
  historydata = Dict([("external" => [au"""(external (: click Click))""".args[1], au"""(external (: left KeyPress))""".args[1], au"""(external (: right KeyPress))""".args[1], au"""(external (: up KeyPress))""".args[1], au"""(external (: down KeyPress))""".args[1]]), # :typedecl aexprs for all external variables
               ("initnext" => []), # :assign aexprs for all initnext variables
               ("lifted" => []), # :assign aexprs for all lifted variables
               ("types" => Dict{Symbol, Any}([:click => :Click, :left => :KeyPress, :right => :KeyPress, :up => :KeyPress, :down => :KeyPress, :GRID_SIZE => :Int, :background => :String])), # map of global variable names (symbols) to types
               ("on" => []),
               ("objects" => []),
               ("functions" => [])])

  if (aexpr.head == :program)
    # handle AExpression lines
    lines = filter(x -> x !== :(), map(arg -> compile(arg, historydata, aexpr), aexpr.args))

    # construct STATE struct and initialize state::STATE
    statestruct = compilestatestruct(historydata)
    initstatestruct = compileinitstate(historydata)

    # handle init, next, prev, and built-in functions
    initnextfunctions = compileinitnext(historydata)
    prevfunctions = compileprevfuncs(historydata)
    causalfunctions = compilecausal(historydata)

  end
end

eval(builtin)

test_ac(aexpr_, cause_a_, cause_b_) = test_ac(aexpr_, cause_a_, cause_b_, Dict())

function test_ac(aexpr_,  cause_a_, cause_b_, restrictedvalues)
    global step = 0
    get_a_causes = getcausal(aexpr_)

    eval(get_a_causes)
    aumod = eval(compiletojulia(aexpr_))
    global state = Base.invokelatest(aumod.init, nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
    global causes = [cause_a_]
    cause_b = cause_b_
    truecount = 0
    while truecount < 2 && length(causes) > 0  && getstep(cause_b)>=step
      new_causes = []
      for cause_a in causes
        println(cause_a)
        try
          if eval(cause_a)
            result = Base.invokelatest(a_causes, cause_a, restrictedvalues)
            append!(new_causes, result)
          else
            if getstep(cause_a) >= step
              append!(new_causes, [cause_a])
            end
          end
        catch e
          println(e)
          append!(new_causes, [cause_a])
        end

      end
      global causes = new_causes
      global state = Base.invokelatest(aumod.next, state, nothing, nothing, nothing, nothing, nothing)
      global step = step + 1
      if Base.invokelatest(tryb, cause_b) || truecount > 0
        for cause in new_causes
          if acaused(cause, cause_b, restrictedvalues)
            return true
          end
        end
        truecount += 1
      end
      println(causes)
    end

    for cause_a in causes
      if acaused(cause_a, cause_b, restrictedvalues)
        return true
      end
    end
    return false
  end
end
