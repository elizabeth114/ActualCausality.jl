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

#If i leave it as a macro it complains aexpr not defined
#If i make it a function it complains about the world age
#If i make it return an expression it complains about aexpr not defined
eval(builtin)

function test_ac(aexpr_,  cause_a_, cause_b_)

    global step = 0
    get_a_causes = getcausal(aexpr_)

    eval(get_a_causes)
    aumod = eval(compiletojulia(aexpr_))
    global state = Base.invokelatest(aumod.init, nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
    global causes = [cause_a_]
    cause_b = cause_b_

    while !Base.invokelatest(tryb, cause_b) && length(causes) > 0
      new_causes = []
      for cause_a in causes
        try
          if eval(cause_a)
            result = Base.invokelatest(a_causes, cause_a)
            append!(new_causes, result)
          else
            if getstep(cause_a) > step - 1
              append!(new_causes, [cause_a])
            end
          end
        catch e
          # println(e)
          append!(new_causes, [cause_a])
        end
      end
      global causes = new_causes
      global state = Base.invokelatest(aumod.next, state, nothing, nothing, nothing, nothing, nothing)
      global step = step + 1
    end
    for cause_a in causes
      if acaused(cause_a, cause_b)
        return true
      end
    end
    return false
  end
end
