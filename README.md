# Actual Causality
Questions are posed as did event_a cause event_b where event_a and event_b are in the form `:(var == value)`.

To answer this question the program traces event_a to all of the events that stem from it until event_b occurs.  

An event is considered to stem from the previous event based on a counterfactual definition. event_x stems from event_y if there is some value for the variable in event_y that makes event_x not occur.

This definition is different from the general counterfactual definition since it is looking at each smaller step instead of the problem as a whole.

[Click here for more info about the program functionality](program.md)

[Click here for more info about the step based counterfactual](acauses.md)
