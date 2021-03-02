"Compilation to Julia"
module Causal

using ..AExpressions, ..SExpr, ..CompileUtils, ..CausalUtils
import MacroTools: striplines

export getcausal

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

# macro test_ac(expected_true, aexpr_,  cause_a_, cause_b_)
#     if expected_true
#       cause = Meta.parse("@test true")
#       not_cause = Meta.parse("@test false")
#     else
#       cause = Meta.parse("@test false")
#       not_cause = Meta.parse("@test true")
#     end
#     global step = 0
#     return quote
#       global step = 0
#       get_a_causes = getcausal($aexpr_)
#
#       eval(get_a_causes)
#       aumod = eval(compiletojulia($aexpr_))
#       state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
#       causes = [$cause_a_]
#       cause_b = $cause_b_
#
#       while !tryb(cause_b) && length(causes) > 0
#         new_causes = []
#         for cause_a in causes
#           try
#             if eval(cause_a)
#               result = a_causes(cause_a)
#               append!(new_causes, result)
#             else
#               if getstep(cause_a) > step - 1
#                 append!(new_causes, [cause_a])
#               end
#             end
#           catch e
#             # println(e)
#             append!(new_causes, [cause_a])
#           end
#         end
#         global causes = new_causes
#         global state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
#         global step = step + 1
#       end
#     for cause_a in causes
#       if acaused(cause_a, cause_b)
#         println("A did cause B")
#         println("a path")
#         println(cause_a)
#         println("b path")
#         println(cause_b)
#         println("---------------------------------------------")
#         $cause
#         return
#       end
#     end
#     println("A did not cause B")
#     println("causes")
#     println(causes)
#     println("cause b")
#     println(cause_b)
#     println("---------------------------------------------")
#     $not_cause
#   end
# end
end
