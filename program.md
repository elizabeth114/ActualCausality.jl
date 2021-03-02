# Overview of Program

## actual_causality_test function

This is the main function that determines if cause_a causes cause_b.

```jsx
cause_a = :(sym == value)
cause_b = :(some symbolic boolean expression) 
causes = [cause_a]
while !eval(cause_b) && length(causes) > 0
	new_causes = []
	for cause_a in causes
		if eval(cause_a) 
			append!(new_causes, a_causes(cause_a))
		else if getstep(cause_a) > step - 1
			append!(new_causes, [cause_a])
		end
	end
	causes = new_causes
	state = aumod.next(state, ...)
	step += 1
end

for cause_a in causes 
	if a_causes(cause_a, cause_b) 
		return true
	end
end
return false
```

## a_causes function

```jsx
cause_a = :(sym == value) 
cause_b = :(some symbolic boolean expression) 
function a_causes(cause_a, cause_b, dict)
	#is listed for each object
	if eval(cause_a) && eval(cause_b)
		for field in object_fields(object)
			for val in possible_values(sym) 
				dict[sym] = val
				if !eval(cause_b)
					dict[sym] = value
					append!(causes, :(object.fieldname == field_value)
					break
				end
			end
			dict[sym] = value
	end
	return causes
end
```

The main issue with this function is all of the possible values.  The possible values function can be set so that any variable can only take a subset of values. 

This is expanded to cover the values of each potential object. This expansion loops over each field of an object and if that field changes then that cause is added to the list. 

## Examples

### Basic Billy/Suzie Rock Example

In this example Billy and Suzie both have rocks at different positions.  When a rock is at the same value as the bottle broken becomes true.  The tests evaluate whether Billy or Suzie cause the bottle to break. 

```jsx
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

#Tests that suzie equaling 1 at some time step causes the bottle to break 
a = :(state.suzieHistory[step] == 1)
b = :(state.brokenHistory[step] == true)
@test_ac(true, aexpr, a, b)

#Tests that suzie equaling 1 at time 0 causes the bottle to break at time 5
a = :(state.suzieHistory[0] == 1)
[:(state.suzieHistory[1] == 2)]
...
[:(state.suzieHistory[4] == 5)]
[:(state.brokenHistory[5] == true)]

b = :(state.brokenHistory[5] == true)
@test_ac(true, aexpr, a, b)

#Tests that billy equaling 0 at some time step does not cause the bottle to break 
a = :(state.billyHistory[step] == 0)
b = :(state.brokenHistory[step] == true)
@test_ac(false, aexpr, a, b)

...
[:(state.billyHistory[4] == 4)]

```

### Ball and Barrier Example

In this example a ball is heading towards a goal with a wall in the way.  If the wall was not there the ball would reach the goal.  Another ball hits the first ball causing it to bounce off of a wall and then reach the goal. 

```jsx
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

#Tests that the direction of ball b causes ball a to reach the goal 
a = :(state.ball_bHistory[step].direction == 225)
b = :(intersects(state.ball_aHistory[step], state.goalHistory[step]))
@test_ac(true, barrier, a, b)
```

## Things to consider

Ball A is headed towards a goal. Ball B hits Ball A and Ball A still hits the goal. Did Ball B cause Ball A to hit the goal? The system would say yes. 

A boulder is rolling towards a hiker.  The hiker ducks.  The hiker survives.  Does the boulder cause the hiker to survive? I think 

Think about broader problem. Why do we want to know causes in the first place. Those might influence what we want to be a cause. Stick with the hypothesis that we can separately construct both definitions of causation. 

Understand at more of an abstract level. 

Write a semantics (operation semantics) 

Formal description of what the language is doing 

Write a bunch of rules