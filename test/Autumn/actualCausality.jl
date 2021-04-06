using Test
using CausalDiscovery
using Random
using MLStyle
import Base.Cartesian.lreplace
using Distributions: Categorical

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
# ------------------------------Change to function------------------------------

# ------------------------------Suzie Test---------------------------------------
# cause((suzie == 1), (broken == true))

# a = :(state.suzieHistory[step] == 1)
# b = :(state.brokenHistory[step] == true)
# @test(test_ac(aexpr, a, b))

# a = :(state.suzieHistory[0] == 1)
# b = :(state.brokenHistory[5] == true)
# @test(test_ac(aexpr, a, b, Dict(:(state.suzieHistory) => [0, 1, 2, 3, 4, 5])))

# a = :(state.suzieHistory[2] == 1)
# b = :(state.brokenHistory[step] == true)
# @test(!test_ac(aexpr, a, b))
#
# # # -------------------------------Billy Test---------------------------------------
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[0] == 0)
# b = :(state.brokenHistory[5] == true)
# @test(!test_ac(aexpr, a, b))
#
# # # cause((billy == 0), (broken == true))
# # a = :(state.billyHistory[0] == 1)
# # b = :(state.brokenHistory[step] == true)
# # @test(!test_ac(aexpr, a, b))
#
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[1] == 1)
# b = :(state.brokenHistory[5] == true)
# @test(!test_ac(aexpr, a, b))
#
# # # ------------------------------Suzie Test---------------------------------------
# #cause((suzie == 1), (broken == true))
# a = :(state.suzieHistory[0] == 1)
# b = :(state.brokenHistory[5] == true)
# @test(test_ac(aexpr2, a, b))
#
# # -------------------------------Billy Test---------------------------------------
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[0] == 0)
# b = :(state.brokenHistory[5] == true)
# @test(!test_ac(aexpr2, a, b))
#
# # # -----------------------------Advanced Suzie Test No Rock-----------------------
a = :(state.suzieHistory[0].timeTillThrow == 3)
b = :(state.suzieThrewHistory[4] == true)
@test(test_ac(aexpr3, a, b))
#
# a = :(state.suzieHistory[1].timeTillThrow == 2)
# b = :(state.suzieThrewHistory[4] == true)
# @test(test_ac(aexpr3, a, b))
#
# a = :(state.suzieHistory[2].timeTillThrow == 3)
# b = :(state.suzieThrewHistory[3] == true)
# @test(!test_ac(aexpr3, a, b))
#
# # -----------------------------Advanced Billy Test No Rock-----------------------
# a = :(state.suzieHistory[0].timeTillThrow == 4)
# b = :(state.suzieThrewHistory[3] == true)
# @test(!test_ac(aexpr3, a, b))
#
# # a = :(state.suzieHistory[0].timeTillThrow == 4)
# # b = :(state.suzieThrewHistory[step] == true)
# # @test(!test_ac(aexpr3, a, b))
#
# # -------------------------------Advanced Rock Test---------------------------------------
#
# # a = :(state.suzieRockHistory[step].origin == state.suzieRockHistory[step].origin)
# # b = :(state.brokenHistory[step] == true)
# # @test_ac(true, aexpr4, a, b)
#
# # -------------------------------Advanced Suzie Test---------------------------------------
# # Autumn program has a bug.  After the first on clause the program stops updating.
# # a = :(state.suzieHistory[step].timeTillThrow == 3)
# # b = :(state.brokenHistory[step] == true)
# # @test_ac(true, aexpr5, a, b)
#
# # #------------------------------Current Assumptions-------------------------------
# # # cause and event are both in the form x == y
# #
