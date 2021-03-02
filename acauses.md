# Approaches for a_causes function

# Problems to consider for all approaches

Does cause_a directly cause cause_b

```jsx
cause_a = :(x == 1) 

//1
cause_b = :(x > 0 || x <= 0) 
//-> false since the value of x doesn't affect  

//2
cause_b = :(x > 1 || x < 1) 
//-> false since this statement is false

//3
cause_b = :(x > 0 || x < 0) 
//-> true since this value is true but not for all values of x

//4
cause_b = :(x > 1 || y == 0) 
//-> false since x is not > 1 (independent of the value of y)

//5
cause_b = :(x > 0 || y == 0) 
//-> true (or at least partially true?)
cause_c = :(y == 0)
cause_a doesnt lead cause_b 
cause_c doesnt lead cause_b

//6 
cause_b = :(y == 0)
//-> false since x is not involved in the expression 
```

# Approach 1: Counterfactuals

Each symbol should have a range of possible values. 

These values could be assigned in the code by the user or they could be based on the type that the value is assigned. 

For example if the symbol is currently a boolean value then the range of values is {true, false}. 

If the symbol is currently an integer then the range of values is {Min Int, ... Max Int} 

## Pseudo-code

```jsx
cause_a = :(sym == value) 
cause_b = :(some symbolic boolean expression) 
function a_causes(cause_a, cause_b, dict)
	if eval(cause_a) && eval(cause_b)
		for val in possible_values(sym) 
			dict[sym] = val
			if !eval(cause_b)
				dict[sym] = value
				return true
			end
		end
		dict[sym] = value
		return false
	end
	return false
end
```

## Problems

```jsx
cause_a = :(x == 1) 

//1
cause_b = :(x > 0 || x <= 0) 
//-> false no other value will change this 

//2
cause_b = :(x > 1 || x < 1) 
//-> false since this statement is false

//3
cause_b = :(x > 0 || x < 0) 
//-> true since setting x == 0 will make the evaluation of cause_b false

//4
cause_b = :(x > 1 || y == 0) 
//-> false since either cause_b is false (if y != 0) or if cause_b is true 
// changing the value of x will not make cause_b false

//5
cause_b = :(x > 0 || y == 0) 
//-> true if y != 0 false if y == 0 

//6 
cause_b = :(y == 0)
//-> false since either cause_b is false (if y != 0) or if cause_b is true 
// changing the value of x will not make cause_b false
```

These results are consistent with what is outlined above except for case number 5.  This case is dependent on the value of y which is not the desired behavior.

Other problems include the time it may take to iterate through all of the possible values for each symbol.

Continuous value infinite possibilities 

Higher dimensional 

# Approach 2: Try-Catch

## Pseudo-code

```jsx
cause_a = :(sym == value) 
cause_b = :(some symbolic boolean expression) 
function a_causes(cause_a, cause_b, dict)
	if eval(cause_a) && eval(cause_b)
		delete(dict[sym])
		try 
			if eval(cause_b)
				dict[sym] = value
				return false
			end
		catch e
			continue
		end
		dict[sym] = value 
		return true
	end
	return false
end	
```

## Problems

```jsx
cause_a = :(x == 1) 

//1
cause_b = :(x > 0 || x <= 0) 
//-> true since x is related 

//2
cause_b = :(x > 1 || x < 1) 
//-> false since this statement is false

//3
cause_b = :(x > 0 || x < 0) 
//-> true since x is related

//4
cause_b = :(x > 1 || y == 0) 
//-> true if y == 0 else false 
// (since cause_b is true if y == 0 and x is present in cause_b)

//5
cause_b = :(x > 0 || y == 0) 
//-> true since x is related (independent of the value of y) 

//6 
cause_b = :(y == 0)
// -> false since x is not involved
```

This approach gets some things right but is unable to evaluate if the symbol it is concerned about is what is causing the expression to be true.  However, it may be useful as a first pass since any time this method decides something is not the cause it is correct. 

# Other thoughts

cause_b is false or cause_a implies cause_b and not ((not cause_a) implies cause_b)

split about 

reduce the always true values 

split up any ors/ands down to the simplest of nodes and then build back up (can short circuit) 

however determining the always true seems hard (back to the full cycle) 

## Things to consider

disjunctive case 

doesn't work when trying to ask about some event with a multi dimensional value 

Not just x == 1 (some conjunction) (come up with an example) 

Multiple people throwing 

All threw at a particular time the cause 

Window throw rock and for each strength reduces by 1 when it gets below a threshold then it smashes did all of the people throwing cause the window to smash 

Is one particular person throwing the rock the window smashing 

could be all the kids or the last kid 

[https://www.cs.cornell.edu/home/halpern/papers/causalitybook-ch1-3.html](https://www.cs.cornell.edu/home/halpern/papers/causalitybook-ch1-3.html)

Need an interpreter: execute step by step (next week) 

[https://escholarship.org/content/qt1496k860/qt1496k860.pdf](https://escholarship.org/content/qt1496k860/qt1496k860.pdf)

[http://web.mit.edu/tger/www/papers/How, whether, why Causal judgments as counterfactual contrasts, Gerstenberg et al., 2015.pdf](http://web.mit.edu/tger/www/papers/How,%20whether,%20why%20Causal%20judgments%20as%20counterfactual%20contrasts,%20Gerstenberg%20et%20al.,%202015.pdf)

construct experiments ^^