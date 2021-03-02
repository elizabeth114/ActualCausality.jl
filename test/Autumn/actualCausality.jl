using Test
using CausalDiscovery
using Random
using MLStyle
import Base.Cartesian.lreplace
using Distributions: Categorical

eval(builtin)

aexpr = au"""(program
  (= GRID_SIZE 16)

  (: broken Bool)
  (= broken (initnext false (prev broken)))

  (: suzie Int)
  (= suzie (initnext 1 (+ (prev suzie) 1)))

  (: billy Int)
  (= billy (initnext 0 (+ (prev billy) 1)))

  (: bottle Int)
  (= bottle (initnext 5 (prev bottle)))

  (on (== billy bottle) (= broken true))

  (on (== suzie bottle) (= broken true))

  )"""

  aexpr2 = au"""(program
    (= GRID_SIZE 16)

    (: broken Bool)
    (= broken (initnext false (prev broken)))

    (: suzie Int)
    (= suzie (initnext 1 (+ (prev suzie) 1)))

    (: billy Int)
    (= billy (initnext 0 (+ (prev billy) 1)))

    (: bottle Int)
    (= bottle (initnext 5 (prev bottle)))

    (on (== billy bottle) (= broken true))

    (on (== (- suzie bottle) 0) (= broken true))

    )"""

aexpr3 = au"""(program
  (= GRID_SIZE 16)

  (object Suzie (: timeTillThrow Integer) (Cell 0 0 "blue"))
  (object Billy (: timeTillThrow Integer) (Cell 0 0 "red"))

  (: suzieThrew Bool)
  (= suzieThrew (initnext false (prev suzieThrew)))

  (: suzie Suzie)
  (= suzie (initnext (Suzie 3 (Position 0 0))
    (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1))))

  (: billy Billy)
  (= billy (initnext (Billy 4 (Position 0 15))
    (updateObj (prev billy) "timeTillThrow" (- (.. (prev billy) timeTillThrow) 1))))

  (on (== (.. suzie timeTillThrow) 0) (= suzieThrew true))
  (on (== (.. billy timeTillThrow) 0) (= billyThrew true))

  )"""

  aexpr4 = au"""(program
    (= GRID_SIZE 16)

    (: broken Bool)
    (= broken (initnext false (prev broken)))

    (object Rock (: moving Bool) (Cell 0 0 "blue"))


    (object Bottle (: broken Bool) (list (Cell 0 0 (if broken then "yellow" else "white"))
                                          (Cell 0 1 (if broken then "white" else "yellow"))
                                          (Cell 0 2 (if broken then "gray" else "yellow"))
                                          (Cell 0 3 (if broken then "white" else "yellow"))
                                          (Cell 0 4 (if broken then "yellow" else "white"))))

    (object BottleSpot (Cell 0 0 "white"))

    (: suzieRock Rock)
    (= suzieRock (initnext (Rock true (Position 0 7))
      (if (.. suzieRock moving) then (move (prev suzieRock) (unitVector (prev suzieRock) bottleSpot)) else (prev suzieRock))))


    (: bottleSpot BottleSpot)
    (= bottleSpot (initnext (BottleSpot (Position 15 7)) (prev bottleSpot)))

    (on (intersects bottleSpot suzieRock) (= broken true))

  )"""

  aexpr5 = au"""(program
  (= GRID_SIZE 16)

  (: broken Bool)
  (= broken (initnext false (prev broken)))

  (object Suzie (: timeTillThrow Integer) (Cell 0 0 "blue"))

  (object BottleSpot (Cell 0 0 "white"))
  (object Rock (: moving Bool) (Cell 0 0 "black"))

  (: suzie Suzie)
  (= suzie (initnext (Suzie 3 (Position 0 0))
    (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1))))

  (: bottleSpot BottleSpot)
  (= bottleSpot (initnext (BottleSpot (Position 15 7)) (prev bottleSpot)))

  (: suzieRock Rock)
  (= suzieRock (initnext (Rock false (Position 0 7))
    (if (.. (prev suzieRock) moving)
     then (move suzieRock (unitVector (prev suzieRock) bottleSpot))
     else (prev suzieRock))))

  (on (== (.. (prev suzie) timeTillThrow) 0)
      (let ((= suzieRock (updateObj (prev suzieRock) "moving" true))
            (= suzie (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1)))
           )))
  (on (intersects (prev bottleSpot) (prev suzieRock)) (= broken true))
)"""

restrictedvalues = Dict(:(state.suzieHistory) => [0, 1, 2, 3, 4, 5, 6])

# ------------------------------Change to function------------------------------
macro test_ac(expected_true, aexpr_,  cause_a_, cause_b_)
    if expected_true
      cause = Meta.parse("@test true")
      not_cause = Meta.parse("@test false")
    else
      cause = Meta.parse("@test false")
      not_cause = Meta.parse("@test true")
    end
    global step = 0
    return quote
      global step = 0
      get_a_causes = getcausal($aexpr_)

      eval(get_a_causes)
      aumod = eval(compiletojulia($aexpr_))
      state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
      causes = [$cause_a_]
      cause_b = $cause_b_

      while !tryb(cause_b) && length(causes) > 0
        new_causes = []
        for cause_a in causes
          try
            if eval(cause_a)
              result = a_causes(cause_a)
              append!(new_causes, result)
            else
              if getstep(cause_a) > step - 1
                append!(new_causes, [cause_a])
              end
            end
          catch e
            append!(new_causes, [cause_a])
          end
        end
        global causes = new_causes
        global state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
        global step = step + 1
      end
    for cause_a in causes
      if acaused(cause_a, cause_b)
        println("A did cause B")
        println("a path")
        println(cause_a)
        println("b path")
        println(cause_b)
        println("---------------------------------------------")
        $cause
        return
      end
    end
    println("A did not cause B")
    println("causes")
    println(causes)
    println("cause b")
    println(cause_b)
    println("---------------------------------------------")
    $not_cause
  end
end
# ------------------------------Suzie Test---------------------------------------
# cause((suzie == 1), (broken == true))
a = :(state.suzieHistory[step] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(true, aexpr, a, b)

a = :(state.suzieHistory[0] == 1)
b = :(state.brokenHistory[5] == true)
@test_ac(true, aexpr, a, b)

a = :(state.suzieHistory[2] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr, a, b)
#
# # -------------------------------Billy Test---------------------------------------
# cause((billy == 0), (broken == true))
a = :(state.billyHistory[step] == 0)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr, a, b)

# cause((billy == 0), (broken == true))
a = :(state.billyHistory[0] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr, a, b)

# cause((billy == 0), (broken == true))
a = :(state.billyHistory[1] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr, a, b)

# # ------------------------------Suzie Test---------------------------------------
#cause((suzie == 1), (broken == true))
a = :(state.suzieHistory[step] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(true, aexpr2, a, b)

# -------------------------------Billy Test---------------------------------------
# cause((billy == 0), (broken == true))
a = :(state.billyHistory[step] == 0)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr2, a, b)

# # -----------------------------Advanced Suzie Test No Rock-----------------------
a = :(state.suzieHistory[step].timeTillThrow == 3)
b = :(state.suzieThrewHistory[step] == true)
@test_ac(true, aexpr3, a, b)

a = :(state.suzieHistory[step].timeTillThrow == 2)
b = :(state.suzieThrewHistory[step] == true)
@test_ac(true, aexpr3, a, b)

a = :(state.suzieHistory[2].timeTillThrow == 3)
b = :(state.suzieThrewHistory[step] == true)
@test_ac(false, aexpr3, a, b)

# -----------------------------Advanced Billy Test No Rock-----------------------
a = :(state.suzieHistory[step].timeTillThrow == 4)
b = :(state.suzieThrewHistory[step] == true)
@test_ac(false, aexpr3, a, b)

a = :(state.suzieHistory[0].timeTillThrow == 4)
b = :(state.suzieThrewHistory[step] == true)
@test_ac(false, aexpr3, a, b)

# -------------------------------Advanced Rock Test---------------------------------------

# a = :(state.suzieRockHistory[step].origin == state.suzieRockHistory[step].origin)
# b = :(state.brokenHistory[step] == true)
# @test_ac(true, aexpr4, a, b)

# -------------------------------Advanced Suzie Test---------------------------------------
# Autumn program has a bug.  After the first on clause the program stops updating.
# a = :(state.suzieHistory[step].timeTillThrow == 3)
# b = :(state.brokenHistory[step] == true)
# @test_ac(true, aexpr5, a, b)

# #------------------------------Current Assumptions-------------------------------
# # cause and event are both in the form x == y
#
chain = au"""(program
  (= GRID_SIZE 16)

  (: reachgoal Bool)
  (= reachgoal (initnext false (prev reachgoal)))

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 10)) (prev goal)))

  (object Ball (: direction Integer) (: color String) (Cell 0 0 color))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 361 "blue" (Position 6 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 270 "purple" (Position 14 10)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))

  (on (intersects goal ball_a) (= reachgoal true))
  (on (clicked goal) (= goal (prev goal)))
)
"""
a = :(state.ball_bHistory[step].direction == 270)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, chain, a, b)

chain3 = au"""(program
  (= GRID_SIZE 16)

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 10)) (prev goal)))

  (object Ball (: direction Integer) (: color String) (Cell 0 0 color))

  (on (clicked goal) (= goal (prev goal)))

  (= testFunc (fn (var_a var_b) (+ var_a var_b)))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 361 "blue" (Position 6 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 361 "red" (Position 10 10)) (if (intersects ball_b ball_c) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_c)))) else (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b))))))))

  (: ball_c Ball)
  (= ball_c (initnext (Ball 270 "purple" (Position 14 10)) (if (intersects (prev ball_b) ball_c) then (nextBall (updateObj (prev ball_c) "direction" 361)) else (nextBall (updateObj (prev ball_c) "direction" (wallintersect (prev ball_c)))))))

  (on (intersects ball_a goal) (= ball_a (updateObj ball_a "direction" 361)))
)"""

a = :(state.ball_bHistory[step].direction == 270)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, chain3, a, b)

a = :(state.ball_cHistory[step].direction == 270)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, chain3, a, b)

println(testFunc(2, 3))

barrier = au"""(program
  (= GRID_SIZE 16)

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 10)) (prev goal)))

  (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
  (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

  (: wall Wall)
  (= wall (initnext (Wall true (Position 4 9)) (prev wall)))

  (on (clicked wall) (= wall (updateObj wall "visible" (! (.. wall visible)))))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 270 "blue" (Position 15 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 225 "red" (Position 15 5)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
)"""

a = :(state.ball_bHistory[step].direction == 225)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, barrier, a, b)

#counterfactual close actual hit
ccah = au"""(program
  (= GRID_SIZE 16)

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 7)) (prev goal)))
  (: goal2 Goal)
  (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

  (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
  (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

  (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 225 "blue" (Position 8 1)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 315 "red" (Position 8 15)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
)"""

a = :(state.ball_bHistory[step].direction == 315)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, ccah, a, b)

chah = au"""(program
  (= GRID_SIZE 16)

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 7)) (prev goal)))
  (: goal2 Goal)
  (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

  (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
  (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

  (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 361 "blue" (Position 12 7)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 270 "red" (Position 15 7)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
)"""

a = :(state.ball_bHistory[step].direction == 270)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, chah, a, b)

#counterfactual miss actual hit
cmah = au"""(program
  (= GRID_SIZE 16)

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 7)) (prev goal)))
  (: goal2 Goal)
  (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

  (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
  (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

  (on (intersects goal ball_a) (= ball_a (updateObj ball_a "direction" 361)))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 270 "blue" (Position 15 5)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 315 "red" (Position 15 8)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
)"""

a = :(state.ball_bHistory[step].direction == 315)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, cmah, a, b)

#counterfactual hit actual miss
cham_nored = au"""(program
  (= GRID_SIZE 16)

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 7)) (prev goal)))
  (: goal2 Goal)
  (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))

  (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
  (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

  (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 270 "blue" (Position 15 7)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 361 "red" (Position 15 0)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
)
"""

a = :(state.ball_aHistory[step].direction == 270)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, cham_nored, a, b)

a = :(state.ball_aHistory[step].direction == 270)
b = :(intersects(state.ball_aHistory[15], state.goalHistory[15]))
@test_ac(true, cham_nored, a, b)



#Now it removes the variable and if it errors or becomes false then it determines that it is related
#Need to think about or statements/and statements where it is always true
#(but for the a < 100 or a >99 wouldnt a not existing prevent this from being true and would therefore be the cause?)
#Need to handle more syntax things like the sub fields

#changes from always true to maybe true
#find some p that makes it false
#execute abstractly
#abstraction problem
#abstract interpretation take program redefine operations to work with values (replace numbers with intervals)


#changed model where change what we currently have
#suppose that suzie throws and if its close then it breaks
#except for some tiny location think about it and solve it
#add to the question
#prove that there are no counter examples

#tracking objects within the list is hard
#something wrong with position tracking
#i think involved with the equality
