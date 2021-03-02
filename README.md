# Actual Causality
Questions are posed as did event_a cause event_b where event_a and event_b are in the form `:(var == value)`.

To answer this question the program traces event_a to all of the events that stem from it until event_b occurs.  

An event is considered to stem from the previous event based on a counterfactual definition. event_x stems from event_y if there is some value for the variable in event_y that makes event_x not occur.

This definition is different from the general counterfactual definition since it is looking at each smaller step instead of the problem as a whole.

[Click here for more info about the program functionality](https://www.notion.so/Overview-of-Program-9beaa4ffb23042cfbd8903c2f228aff3)

[Click here for more info about the step based counterfactual](https://www.notion.so/Approaches-for-a_causes-function-6e5e4e60d1ae405d8797474599c47182)
