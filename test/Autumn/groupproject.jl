using Test
using CausalDiscovery
using Random
using MLStyle
import Base.Cartesian.lreplace
using Distributions: Categorical

#
project = au"""(program
  (= GRID_SIZE 16)

  (object Grade (: grade Integer) (Cell 0 0 (if (< grade 70) then "red"
                                            else (if (< grade 80) then "orange"
                                            else (if (< grade 90) then "yellow"
                                            else "green")))))
  (: group Grade)
  (= group (initnext (Grade 0 (Position 0 0)) (prev group)))

  (object Student (: intelligence Integer) (: effort Integer) (: desire Integer) (: color String) (Cell 0 0 color))
  (: student1 Student)
  (= student1 (initnext (Student 3 3 85 "pink" (Position 15 2)) (prev student1)))
  (: student2 Student)
  (= student2 (initnext (Student 5 2 94 "purple" (Position 15 5)) (prev student2)))
  (: student3 Student)
  (= student3 (initnext (Student 2 4 81 "blue" (Position 15 8)) (prev student3)))

  (= progress (fn (s1 s2 s3) (+ (+ (* (.. s1 intelligence) (.. s1 effort)) (* (.. s2 intelligence) (.. s2 effort))) (* (.. s3 intelligence) (.. s3 effort)))))

  (on (== (.. state time) 5) (= group (updateObj group "grade" (+ (.. group grade) (progress student1 student2 student3)))))
  )"""


  a = :(state.student1History[0].intelligence == 3)
  b = :(state.groupHistory[5].grade == 27)
  @test(test_ac(project, a, b))

  project = au"""(program
    (= GRID_SIZE 16)

    (object Grade (: grade Integer) (Cell 0 0 (if (< grade 70) then "red"
                                              else (if (< grade 80) then "orange"
                                              else (if (< grade 90) then "yellow"
                                              else "green")))))
    (: group Grade)
    (= group (initnext (Grade 0 (Position 0 0)) (if (== (.. state time) 5) then (updateObj group "grade" (+ (.. group grade) (progress student1 student2 student3))) else (prev group))))

    (object Student (: intelligence Integer) (: effort Integer) (: desire Integer) (: color String) (Cell 0 0 color))
    (: student1 Student)
    (= student1 (initnext (Student 3 3 85 "pink" (Position 15 2))
          (if (& (== (.. state time) 6) (increaseeffort (prev student1) (.. group grade)))
              then (updateObj (prev student1) "effort" (+ (.. (prev student1) effort) 1))
              else (prev student1))))

    (: student2 Student)
    (= student2 (initnext (Student 5 2 94 "purple" (Position 15 5)) (prev student2)))
    (: student3 Student)
    (= student3 (initnext (Student 2 4 81 "blue" (Position 15 8)) (prev student3)))

    (= progress (fn (s1 s2 s3) (+ (+ (* (.. s1 intelligence) (.. s1 effort)) (* (.. s2 intelligence) (.. s2 effort))) (* (.. s3 intelligence) (.. s3 effort)))))


    (on (== (.. state time) 10) (= group (updateObj group "grade" (+ (.. group grade) (progress student1 student2 student3)))))

    (= increaseeffort (fn (student grade) (if (< (* grade 2) (.. student desire)) then true else false)))

    )"""

    a = :(state.student1History[0].intelligence == 3)
    b = :(state.groupHistory[10].grade == 57)
    @test(test_ac(project, a, b))

    a = :(state.student1History[0].intelligence == 3)
    b = :(state.groupHistory[10].grade >= 55)
    @test(test_ac(project, a, b))

    a = :(state.student1History[7].effort == 4)
    b = :(state.groupHistory[10].grade >= 55)
    @test(test_ac(project, a, b))

    a = :(state.student1History[0].effort == 3)
    b = :(state.groupHistory[10].grade >= 20)
    @test(!test_ac(project, a, b))

    #without restrictions is true
    a = :(state.student1History[7].effort == 4)
    b = :(state.groupHistory[10].grade >= 0)
    @test(test_ac(project, a, b, Dict([(:(state.student1History[step].effort), [0, 1, 2, 3, 4, 5])])))

    restricted = Dict([(:(state.student1History[step].effort), [0, 1, 2, 3, 4, 5]),
                        (:(state.groupHistory[step].grade), :([state.groupHistory[step-1].grade:1:(100);]))
                        ])

    #with restrictions is false
    a = :(state.student1History[7].effort == 4)
    b = :(state.groupHistory[10].grade >= 0)
    @test(!test_ac(project, a, b, restricted))

    # [state.student1History[10].effort == 4]
    # grade == 57
    # (effort 0) -> grade >= 25
    a = :(state.student1History[7].effort == 4)
    b = :(state.groupHistory[10].grade >= 20)
    @test(!test_ac(project, a, b, restricted))
