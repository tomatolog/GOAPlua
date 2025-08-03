# GOAP Planner TODO

This checklist tracks implementation tasks derived from spec.md. Mark items as done when completed.

Algorithmic and Correctness Improvements
[ ] A1: Add heuristic mode flag (0/Dijkstra vs. domain-aware).
[ ] A2: Implement no-op action skip in neighbor generation.
[ ] A3: Introduce `state_key(state)` and refactor open/closed to use it.
[ ] A4: Define reaction semantics for `-1`; disallow or document as no-op.
[ ] A5: Modularize `Goap.lua` to return a module table; update callers.
[ ] A6: Add planner validation to ensure all actions have explicit positive weights.
[ ] A7: Sort action names for deterministic iteration and add tie-breaking `(f, g, name)`.
[ ] A8: Early exit in `astar` if start meets goal.
[ ] A9: Validate presence of reactions for all actions.

Performance and Scalability
[ ] P1: Implement a binary heap priority queue for the open list with decrease-key.
[ ] P2: Reduce state copying; reconstruct states at the end using parent pointers.
[ ] P3: Add optional `max_expansions` and `time_budget_ms` parameters to `astar`.
[ ] P4: Add optional heuristic memoization keyed by `state_key`.

API and Usability
[ ] U1: Extend Action API: `remove_condition`, `remove_reaction`, `has`, `list`.
[ ] U2: Add `Action:validate(known_keys, opts)` and `Planner:validate()`.
[ ] U3: Support alternative goal forms: predicate and OR-goals.
[ ] U4: Change `Planner:calculate()` return structure to include `steps`, `cost`, `expanded`, `found`, `reason`.
[ ] U5: Add `on_event` callback hook for tracing.

Robustness Fixes and Small Polish
[ ] R1: Fix open/closed list removal and re-open behavior on better `g`.
[ ] R2: Make `World:get_plan` deterministic; sort debug output.
[ ] R3: Decide behavior for missing weights (validation or error) and implement.
[ ] R4: Add `deepEqual` utility and use where needed.
[ ] R5: Standardize error messages with module/function context.
[ ] R6: Add `CHANGELOG.md` and versioning constant.

Notes and Migration Steps
- After A5 (modular Goap), update all imports:
  - `local Goap = require("Goap")`
  - Replace global calls with `Goap.distance_to_state`, `Goap.conditions_are_met`, `Goap.astar`.
- After U4 (enhanced return structure), update `World:get_plan` and any consumer code to read `result.steps` and `result.cost`.
- Validation order:
  1) `Planner:set_start_state`/`set_goal_state` basic key checks (existing behavior).
  2) `Planner:set_action_list(actions)`.
  3) `Planner:validate()` before `calculate()`.
- Backward compatibility:
  - Keep a compatibility mode for `Planner:calculate()` to return just the steps until consumers migrate (flag or version bump).
