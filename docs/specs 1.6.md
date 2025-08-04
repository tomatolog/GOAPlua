Below are focused changes to enforce explicit, positive weights for every action and fail fast if any are missing or invalid.

What changes
- Add a validation step in Planner before calling Goap.astar.
- Validation checks:
  - Each action key present in `action_list.conditions` must have a weight entry in `action_list.weights`.
  - Each weight must be a number > 0 (no zeros, no negatives, no non-numbers).
- Keep API unchanged; error messages are descriptive.

Patch

File: `Planner.lua` (only the relevant additions shown; rest unchanged)

```lua
local class = require('pl.class')
local deepcopy = require('pl.tablex').deepcopy
local Goap = require("Goap")

local Planner = class()
local function  update(t1,t2)
    for k,v in pairs(t2) do
        t1[k] = v
    end
end

function  Planner:_init(...)
    self.start_state = nil
    self.goal_state = nil
    self.values = {}
    for _,v in pairs({...}) do
        self.values[v] = -1
    end
    self.action_list = nil
    self.heuristic_strategy = "mismatch"
    self.heuristic_params = nil
end

function Planner:set_heuristic(strategy, params)
    self.heuristic_strategy = strategy or "mismatch"
    self.heuristic_params = params
end

function Planner:state(kwargs)
    local _new_state = deepcopy(self.values)
    update(_new_state,kwargs)
    return _new_state
end

function Planner:set_start_state(kwargs)
    for k,_ in pairs(kwargs) do
        if self.values[k] == nil then
            error("Invalid states for world start state: "..k)
        end
    end
    self.start_state = self:state(kwargs)
end

function  Planner:set_goal_state(kwargs)
    for k,_ in pairs(kwargs) do
        if self.values[k] == nil then
            error("Invalid states for world goal state: "..k)
        end
    end
    self.goal_state = self:state(kwargs)
end

function Planner:set_action_list(action_list)
    self.action_list = action_list
end

-- New: validate that each action has an explicit, positive numeric weight
local function validate_weights(action_list)
    if not action_list or not action_list.conditions then
        error("No actions provided to planner")
    end
    local weights = action_list.weights or {}
    for action_name, _ in pairs(action_list.conditions) do
        local w = weights[action_name]
        if w == nil then
            error("Missing weight for action '"..tostring(action_name).."'")
        end
        if type(w) ~= "number" or w <= 0 or w ~= w then -- includes NaN check
            error("Invalid weight for action '"..tostring(action_name).."': expected positive number, got "..tostring(w))
        end
    end
end

function Planner:calculate()
     -- Validate weights before planning
     validate_weights(self.action_list)

     return Goap.astar(
         self.start_state,
         self.goal_state,
         deepcopy(self.action_list.conditions),
         deepcopy(self.action_list.reactions),
         deepcopy(self.action_list.weights),
         self.heuristic_strategy,
         self.heuristic_params
     )
end

return Planner
```

Testing guidance
- Success case: In your example, you already set some weights explicitly. Ensure all actions have weights. For actions without `set_weight`, add them, for example:
  - `actions:set_weight('cook', 1)`, `actions:set_weight('eat', 1)`, etc.
- Failure cases to add in specs:
  - Missing weight for an action present in `conditions` should error with “Missing weight for action '...'”.
  - Weight 0, negative, non-number (e.g., string), or NaN should error with “Invalid weight for action '...': expected positive number, got ...”.

Optional conveniences
- If you want to keep a development mode where unspecified weights default to 1, you can add a flag on `Planner` like `allow_default_weight = false`, and only enforce strict validation when it’s false. The current spec asks for strict validation, so the code above enforces it unconditionally.