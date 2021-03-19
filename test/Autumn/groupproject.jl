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
