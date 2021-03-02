# How to run a question of AC

Create your file and start with the following

```jsx
using Test
using CausalDiscovery
using Random
using MLStyle
import Base.Cartesian.lreplace
using Distributions: Categorical

eval(builtin)
```

Define the macro (issues with this explained at the bottom)

```jsx
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
```

Define your aexpr (example below)

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
```

Define cause_a and cause_b (example below)

```jsx
a = :(state.suzieHistory[step] == 1)
b = :(state.brokenHistory[step] == true)
```

Set up your test with the expected outcome (true if you believe a caused b else false) (example below)

```jsx
@test_ac(true, aexpr, a, b)
```

If your hypothesis was correct the test will pass.

## Why isn't this test_ac a function?

I am working on creating a function that can just be run but when attempting to transform the macro I ran into the following errors.

When attempting to define `test_ac` as a macro in another file:

It complains aexpr not defined

When attempting to define `test_ac` as a function in another file

It complains about the world age
If I make it return an expression it complains about aexpr not defined
