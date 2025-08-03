# GOAP Planner Specification

This document specifies planned improvements, features, and behaviors for the GOAP planner, grouped by category. Each item includes intent, rationale, and acceptance criteria.

1. Algorithmic and Correctness Improvements

1.1 Heuristic Admissibility and Consistency
- Intent: Ensure A* remains optimal when action costs vary or actions affect multiple goal-relevant keys.
- Rationale: Current heuristic counts mismatched keys; it may be inadmissible if a single action can fix multiple keys or when weights vary widely.
- Options:
  A) Conservative heuristic: use 0 (Dijkstra) for correctness.
  B) Domain-aware heuristic: estimate the minimum number of actions required (e.g., mismatches divided by max number of mismatches fixed by any single action).
- Acceptance:
  - A configuration flag allows choosing heuristic strategy.
  - For tests with varied weights and multi-effect actions, A* returns optimal plans.

1.2 Skip No-op Actions
- Intent: Prevent expansions where an action’s reaction does not change the state.
- Rationale: No-ops waste search effort and can cause loops.
- Acceptance:
  - Neighbor generation skips actions whose reaction would produce an identical successor state.
  - Unit tests include an action that does not change any key; it is never expanded.

1.3 Deduplicate by State with Hashing
- Intent: Improve correctness and speed by tracking visited/open states using a canonical key.
- Rationale: Current `node_in_list` is O(n) and relies on flat table equality; it’s slower and less robust.
- Acceptance:
  - A function `state_key(state)` produces a stable string key (sorted keys).
  - Open and closed sets are maps keyed by `state_key`.
  - If a better `g` is found for a state key, the node is updated or re-opened.
  - Tests show fewer expansions and correct plan reconstruction.

1.4 Reaction Semantics and Wildcards
- Intent: Clarify `-1` usage and disallow ambiguous semantics in reactions.
- Rationale: `-1` currently acts as “ignore” in reactions; make this explicit, or disallow `-1` in reactions.
- Acceptance:
  - Conditions: `-1` means “don’t care”.
  - Reactions: either disallow `-1` (validation error) or explicitly document as “no change”.
  - Tests verify validation rejects invalid reaction values if disallowed.

1.5 Modularize Goap API (No Globals)
- Intent: Avoid global functions and name collisions; improve testability.
- Rationale: `Goap.lua` defines globals. Return a module table and use `require("Goap")`.
- Acceptance:
  - `Goap.lua` returns `{ distance_to_state, conditions_are_met, astar, ... }`.
  - Callers updated to `local Goap = require("Goap")`, then `Goap.astar(...)`.
  - Tests import functions from the module table.

1.6 Validate Weights for All Actions
- Intent: Make sure each action has an explicit and positive weight.
- Rationale: Implicit default masks mistakes and leads to inconsistent costs.
- Acceptance:
  - Planner validation step errors if any action lacks a positive numeric weight.
  - Tests cover error cases and success with explicitly set weights.

1.7 Deterministic Iteration Order
- Intent: Guarantee reproducible plans when multiple paths have equal cost/heuristic.
- Rationale: Iterating maps is non-deterministic.
- Acceptance:
  - Action iteration is done over a sorted array of action names.
  - Tie-breaking uses `(f, g, name)` to ensure deterministic selection.
  - Tests verify consistent plan sequence across multiple runs.

1.8 Early Exit if Start Meets Goal
- Intent: Fast return when start already satisfies goal.
- Rationale: Saves unnecessary computation.
- Acceptance:
  - If `conditions_are_met(start, goal)` then `astar` returns an empty plan.
  - Tests cover this scenario.

1.9 Guard Missing Reactions
- Intent: Ensure each action has both condition and reaction tables.
- Rationale: Missing reaction leads to runtime errors in neighbor generation.
- Acceptance:
  - Validation step rejects actions without reactions.
  - Tests verify error messaging.

2. Performance and Scalability

2.1 Priority Queue for Open List
- Intent: Reduce selection of the best node from O(n) to O(log n).
- Rationale: Choosing min-f from a map is slow for large graphs.
- Acceptance:
  - Implement a binary heap keyed by `(f, g, name)` with decrease-key support.
  - Track heap index per `state_key` for efficient updates.
  - Benchmarks show reduced runtime on larger problem instances.

2.2 Minimize Table Copies
- Intent: Reduce memory churn during search.
- Rationale: Copying entire states and nodes is expensive.
- Acceptance:
  - Successor state is a shallow copy of parent state only for changed keys (or an immutable state representation).
  - Node carries parent pointer and the action taken; full states reconstructed only when returning a plan.
  - Tests confirm functional equivalence.

2.3 Limit Expansions / Time Budget
- Intent: Prevent runaway searches on unsolvable or huge spaces.
- Acceptance:
  - Optional parameters: `max_expansions`, `time_budget_ms`.
  - `astar` stops and returns failure/partial best info on limit breach.
  - Tests cover both limits.

2.4 Heuristic Caching
- Intent: Avoid recomputing `distance_to_state` for repeated states.
- Acceptance:
  - Optional memoization keyed by `state_key`.
  - Benchmarks show fewer heuristic calls on repeated states.

3. API and Usability

3.1 Action Management Enhancements
- Intent: Improve ergonomics around action lists.
- Acceptance:
  - Methods: `Action:remove_condition(name)`, `Action:remove_reaction(name)`, `Action:has(name)`, `Action:list()` returns sorted action names.
  - Tests verify behaviors and idempotency.

3.2 Action and Planner Validation API
- Intent: Provide clear validation errors before planning.
- Acceptance:
  - `Action:validate(known_keys, opts)` checks:
    - Conditions/reactions only reference known keys.
    - Reactions present for every action.
    - No `-1` in reactions (if disallowed).
    - Weight present and positive.
  - `Planner:validate()` checks:
    - Start/goal keys are known.
    - Action list passes validation against `Planner.values`.
  - Tests verify validation failures and success.

3.3 Flexible Goal Specification
- Intent: Support richer goals: state mask, predicate, OR-goals.
- Acceptance:
  - Planner accepts goals as:
    - state table mask (current behavior),
    - `function(state) -> bool`,
    - array of alternative goal masks (logical OR).
  - `distance_to_state` adapts or uses fallback heuristic (0) when goal is a predicate.
  - Tests cover all goal forms.

3.4 Enhanced Return Structure
- Intent: Provide richer planning results for consumers.
- Acceptance:
  - `Planner:calculate()` returns:
    - `steps`: array of `{ name, state, g, h, f }`,
    - `cost`: total path cost,
    - `expanded`: number of expansions,
    - `found`: boolean,
    - Optional: `reason` on failure (e.g., limit reached).
  - `World:get_plan()` returns `{ cost = min_cost, plans = { ... }, counts = { ... } }` or similar summary.
  - Tests validate the new structure.

3.5 Deterministic Debug/Trace Hooks
- Intent: Allow introspection without printing directly.
- Acceptance:
  - Optional callback: `on_event(event, data)` for node expansion, selection, and goal found.
  - No default printing from library code.
  - Tests inject a spy callback and verify call order.

4. Robustness Fixes and Small Polish

4.1 Fix Open/Closed List Updates
- Intent: Correctly remove/update nodes when a better path is found.
- Acceptance:
  - Replace `table.remove(_olist, next_node)` with proper map removal by id or state key.
  - Reopen nodes from closed if a better `g` is discovered.
  - Tests for re-opening improved paths pass.

4.2 Deterministic Minimal Plan Selection in World
- Intent: Ensure the lowest-cost plans are returned reliably.
- Acceptance:
  - World collects plans by cost, finds minimum deterministically, returns its bucket.
  - Debug output sorted by cost and plan index.
  - Tests verify determinism.

4.3 Safe Nil Weights
- Intent: Avoid runtime errors or undefined behavior when a weight is missing.
- Acceptance:
  - During neighbor generation, either:
    - Enforce validation error beforehand, or
    - Treat missing weight as a fatal error with a clear message.
  - Tests cover this.

4.4 Deep Equality Utility
- Intent: Make a general utility for deep equality (future-proof).
- Acceptance:
  - Provide `deepEqual(a, b)` for nested tables.
  - Replace ad-hoc compare logic where appropriate.
  - Tests verify deep equality for primitives and nested tables.

4.5 Consistent Error Messages
- Intent: Improve developer experience.
- Acceptance:
  - All errors include module and function context, e.g., `[Planner.validate] Invalid state key: foo`.
  - Tests check for expected error messages.

4.6 Versioning and Changelog
- Intent: Track changes for consumers.
- Acceptance:
  - Add a `CHANGELOG.md` with Keep a Changelog format.
  - Semantic versioning in a `VERSION` file or exported constant.
