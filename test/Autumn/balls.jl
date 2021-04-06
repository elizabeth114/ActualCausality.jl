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
# a = :(state.ball_bHistory[0].direction == 270)
# b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
# @test(test_ac(chain, a, b))

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

# a = :(state.ball_bHistory[5].direction == 270)
# b = :(intersects(state.ball_aHistory[14], state.goalHistory[14]))
# @test(test_ac(chain3, a, b))
#
a = :(state.ball_cHistory[0].direction == 270)
b = :(intersects(state.ball_aHistory[14], state.goalHistory[14]))
@test(test_ac(chain3, a, b))
#
# barrier = au"""(program
#   (= GRID_SIZE 16)
#
#   (object Goal (Cell 0 0 "green"))
#   (: goal Goal)
#   (= goal (initnext (Goal (Position 0 10)) (prev goal)))
#
#   (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
#   (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))
#
#   (: wall Wall)
#   (= wall (initnext (Wall true (Position 4 9)) (prev wall)))
#
#   (on (clicked wall) (= wall (updateObj wall "visible" (! (.. wall visible)))))
#
#   (: ball_a Ball)
#   (= ball_a (initnext (Ball 270 "blue" (Position 15 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))
#
#   (: ball_b Ball)
#   (= ball_b (initnext (Ball 225 "red" (Position 15 5)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
# )"""
#
# a = :(state.ball_bHistory[step].direction == 225)
# b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
# @test(test_ac(barrier, a, b))
#
# #counterfactual close actual hit
# ccah = au"""(program
#   (= GRID_SIZE 16)
#
#   (object Goal (Cell 0 0 "green"))
#   (: goal Goal)
#   (= goal (initnext (Goal (Position 0 7)) (prev goal)))
#   (: goal2 Goal)
#   (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))
#
#   (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
#   (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))
#
#   (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))
#
#   (: ball_a Ball)
#   (= ball_a (initnext (Ball 225 "blue" (Position 8 1)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))
#
#   (: ball_b Ball)
#   (= ball_b (initnext (Ball 315 "red" (Position 8 15)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
# )"""
#
# a = :(state.ball_bHistory[step].direction == 315)
# b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
# @test(test_ac(ccah, a, b))
#
# chah = au"""(program
#   (= GRID_SIZE 16)
#
#   (object Goal (Cell 0 0 "green"))
#   (: goal Goal)
#   (= goal (initnext (Goal (Position 0 7)) (prev goal)))
#   (: goal2 Goal)
#   (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))
#
#   (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
#   (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))
#
#   (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))
#
#   (: ball_a Ball)
#   (= ball_a (initnext (Ball 361 "blue" (Position 12 7)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))
#
#   (: ball_b Ball)
#   (= ball_b (initnext (Ball 270 "red" (Position 15 7)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" (ballcollision (prev ball_b) (prev ball_a)))) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
# )"""
#
# a = :(state.ball_bHistory[step].direction == 270)
# b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
# @test(test_ac(chah, a, b))
#
# #counterfactual miss actual hit
# cmah = au"""(program
#   (= GRID_SIZE 16)
#
#   (object Goal (Cell 0 0 "green"))
#   (: goal Goal)
#   (= goal (initnext (Goal (Position 0 7)) (prev goal)))
#   (: goal2 Goal)
#   (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))
#
#   (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
#   (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))
#
#   (on (intersects goal ball_a) (= ball_a (updateObj ball_a "direction" 361)))
#
#   (: ball_a Ball)
#   (= ball_a (initnext (Ball 270 "blue" (Position 15 5)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))
#
#   (: ball_b Ball)
#   (= ball_b (initnext (Ball 315 "red" (Position 15 8)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
# )"""
#
# a = :(state.ball_bHistory[step].direction == 315)
# b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
# @test(test_ac(cmah, a, b))
#
# #counterfactual hit actual miss
# cham_nored = au"""(program
#   (= GRID_SIZE 16)
#
#   (object Goal (Cell 0 0 "green"))
#   (: goal Goal)
#   (= goal (initnext (Goal (Position 0 7)) (prev goal)))
#   (: goal2 Goal)
#   (= goal2 (initnext (Goal (Position 0 8)) (prev goal2)))
#
#   (object Ball (: direction Integer) (: color String) (Cell 0 0 color))
#   (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))
#
#   (on (== 0 (.. (.. ball_a origin) x)) (= ball_a (updateObj ball_a "direction" 361)))
#
#   (: ball_a Ball)
#   (= ball_a (initnext (Ball 270 "blue" (Position 15 7)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))
#
#   (: ball_b Ball)
#   (= ball_b (initnext (Ball 361 "red" (Position 15 0)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
# )
# """
#
# a = :(state.ball_aHistory[step].direction == 270)
# b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
# @test(test_ac(cham_nored, a, b))
#
# a = :(state.ball_aHistory[step].direction == 270)
# b = :(intersects(state.ball_aHistory[15], state.goalHistory[15]))
# @test(test_ac(cham_nored, a, b))
#
#
#
# #Now it removes the variable and if it errors or becomes false then it determines that it is related
# #Need to think about or statements/and statements where it is always true
# #(but for the a < 100 or a >99 wouldnt a not existing prevent this from being true and would therefore be the cause?)
# #Need to handle more syntax things like the sub fields
#
# #changes from always true to maybe true
# #find some p that makes it false
# #execute abstractly
# #abstraction problem
# #abstract interpretation take program redefine operations to work with values (replace numbers with intervals)
#
#
# #changed model where change what we currently have
# #suppose that suzie throws and if its close then it breaks
# #except for some tiny location think about it and solve it
# #add to the question
# #prove that there are no counter examples
#
# #tracking objects within the list is hard
# #something wrong with position tracking
# #i think involved with the equality
