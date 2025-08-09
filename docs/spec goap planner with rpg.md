---

**💬 Response:**

# GOAP + Relaxed‑Planning‑Graph (RPG) Specification  
**Version 1.0 – 2025‑08‑09**  
Prepared for: **Game‑AI / Gameplay‑Programming Team**  

---

## 1. Overview  

This document defines a **Goal‑Oriented Action Planning (GOAP)** subsystem that uses a **Relaxed Planning Graph (RPG)** to provide an admissible heuristic for the A* search.  

* The **RPG** is a static, monotone graph built once (or whenever the start state changes).  
* The **GOAP planner** is a conventional forward‑search (A*) that expands world‑states, applies actions, and uses the RPG‑derived heuristic (`h‑max`, `h‑add` or `h‑ff`).  

The result is an optimal (or bounded‑sub‑optimal if a weighted heuristic is used) sequence of actions that respects pre‑conditions, delete‑effects, and numeric resource constraints.

---  

## 2. Functional Requirements  

| ID | Requirement | Priority |
|----|-------------|----------|
| FR‑01 | Represent **facts** (boolean, numeric, and positional) and **conditions** that can be tested against a world state. | High |
| FR‑02 | Represent **actions** with: • Preconditions (list of conditions) • Add‑effects (list of effects) • Optional delete‑effects (must be respected during real planning) • Fixed **base cost** (float) and an optional **dynamic cost** function (`WorldState → float`). | High |
| FR‑03 | Build a **Relaxed Planning Graph** from a given start state and a static action set, ignoring delete‑effects. | High |
| FR‑04 | From the RPG compute at least one of the following admissible heuristics: • `h_max` (max‑level) • `h_add` (sum‑of‑levels) • `h_ff` (cost of a relaxed plan). | High |
| FR‑05 | Run an **A\*** search over world‑states that: • Uses the RPG heuristic (`h`) and exact accumulated cost (`g`). • Returns a **real executable plan** (ordered list of concrete actions). | High |
| FR‑06 | Allow **dynamic replanning**: when the current world state diverges from the plan, restart the search using the same RPG (or rebuild it if the start state changed). | Medium |
| FR‑07 | Provide an **API** that can be called from gameplay code: `Plan(startState, goal, out List<Action> plan)`. | High |
| FR‑08 | Log useful diagnostics (graph size, heuristic values, nodes expanded, time taken). | Medium |
| FR‑09 | Detect **unsolvable goals** (heuristic returns ∞) and report a specific exception. | High |
| FR‑10 | Provide **unit‑testable** public interfaces and deterministic behaviour for the same input. | High |

---  

## 3. Non‑Functional Requirements  

| ID | Requirement | Target |
|----|-------------|--------|
| NFR‑01 | **Performance** – Planning for a typical mid‑size world (≈ 30 facts, ≤ 25 actions) must finish ≤ 5 ms on a modern desktop CPU (single thread). | ≤ 5 ms |
| NFR‑02 | **Memory** – RPG layers must not exceed 2 MiB for the same scenario. | ≤ 2 MiB |
| NFR‑03 | **Thread‑safety** – All public methods must be safe to call from the main thread only; internal data structures may be reused across frames but must not be accessed concurrently. | Single‑threaded |
| NFR‑04 | **Extensibility** – Adding a new fact type (e.g., “temperature”) or a new cost function must not require changes to the core planner. | Plug‑in design |
| NFR‑05 | **Portability** – Code shall be written in standard C# 8.0 (or C++ 17) without engine‑specific dependencies, except for a minimal `Vector3` / `Position` struct. | Engine‑agnostic |
| NFR‑06 | **Determinism** – Given the same start state, goal and action set the planner must always return the same plan (no random tie‑breakers). | Deterministic |

---  

## 4. Architecture  

```
+-------------------+          +-----------------------+
|   Gameplay Code  |          |   Planner Client API  |
| (request plan)   | <------> |  GOAPPlanner.Plan()   |
+-------------------+          +-----------------------+
                                   |
                                   v
                         +---------------------+
                         |  GOAPPlanner (A*)   |
                         |  - Open/Closed list|
                         |  - g, f calculation|
                         +----------+----------+
                                    |
               +--------------------+-------------------+
               |                                        |
               v                                        v
   +---------------------+                 +---------------------+
   |  HeuristicProvider  |                 |  ActionExecutor     |
   |  (uses RPG)        |                 |  (apply action)     |
   +----------+----------+                 +----------+----------+
              |                                   |
              v                                   v
   +---------------------+               +---------------------+
   |  RelaxedPlanningGraph|<------------|  ActionRepository   |
   |  (layers, min‑cost) |   build on  |  (static actions)   |
   +---------------------+   demand    +---------------------+
```

* **ActionRepository** – immutable collection of all actions for the current planning episode.  
* **RelaxedPlanningGraph** – built once per start state; holds fact‑layers (`L0…Ln`) and action‑layers (`A0…An‑1`).  
* **HeuristicProvider** – queries the RPG to compute `h(state)`. Provides three selectable strategies (`Max`, `Add`, `FF`).  
* **GOAPPlanner** – A* implementation that calls `HeuristicProvider.Estimate(state, goal)`.  

---  

## 5. Data Model  

### 5.1. Core Types  

| Type | Description | Important fields / properties |
|------|-------------|-------------------------------|
| `Fact` | Immutable representation of a single piece of world information. | `FactType Type` (Bool / Numeric / Position)  `string Name`  `bool BoolValue`  `int NumericValue`  `Vector3 PositionValue` |
| `Condition` | Test applied to a `Fact` (used in pre‑conditions &amp; goal). | Same shape as `Fact` but may contain a **comparison operator** (`==`, `>=`, `<=`). |
| `Effect` | Add‑effect (or delete‑effect) produced by an action. | Same fields as `Fact` plus `bool IsAdd` (true = add, false = delete). |
| `Action` (abstract) | Base class for all concrete actions. | `IReadOnlyList<Condition> Preconditions`  `IReadOnlyList<Effect> AddEffects`  `IReadOnlyList<Effect> DeleteEffects` (optional)  `float BaseCost`  `float Cost(WorldState state)` (virtual, default returns `BaseCost`). |
| `WorldState` | Set of facts representing the current world. Immutable – `Apply(Action)` returns a new `WorldState`. | `HashSet<Fact> Facts` (fast lookup)  helper methods `Satisfies(Condition)`, `Clone()`. |
| `Goal` | Collection of `Condition`s that must all be satisfied. | `IReadOnlyList<Condition> Conditions` |
| `RPG` | The relaxed planning graph. | `List<HashSet<Fact>> FactLayers`  `List<List<Action>> ActionLayers`  `int FirstLevel(Condition c)` |
| `HeuristicStrategy` (enum) | `Max`, `Add`, `FF`. |
| `HeuristicProvider` | Holds a reference to an `RPG` and a `Dictionary<string,float> MinFactCost`. | Method `float Estimate(WorldState s, Goal g)`. |
| `GOAPPlanner` | Public entry point. | Method `bool TryPlan(WorldState start, Goal goal, out List<Action> plan)`. |

### 5.2. Serialization / Persistence  

All types are **plain‑old‑data** and can be serialized with JSON or binary for debugging. No runtime state (open list, closed list) is persisted across frames.

---  

## 6. Algorithms  

### 6.1. BuildRelaxedPlanningGraph(start, actions)

```
FactLayers[0] = start.Facts
level = 0
repeat
    applicable = { a ∈ actions | a.Preconditions ⊆ FactLayers[level] }
    if applicable empty → break
    ActionLayers[level] = applicable
    nextFacts = FactLayers[level] ∪ { e.Fact for a∈applicable, e∈a.AddEffects }
    FactLayers.append(nextFacts)
    level++
until false
```

*Delete‑effects are ignored.*  
Complexity: **O(L·A·P)** where `L` = number of layers, `A` = number of actions, `P` = avg. pre‑condition count. In practice `L ≤ 15` for typical GOAP domains.

### 6.2. ComputeMinFactCost(actions)

```
minCost = {}
for each action a
    for each addEffect e in a.AddEffects
        perFact = (e.Type == Numeric) ? a.BaseCost / e.Amount : a.BaseCost
        if !minCost.ContainsKey(e.Name) || perFact < minCost[e.Name]
            minCost[e.Name] = perFact
return minCost
```

*Result is used by the heuristic to convert “layers → real cost”.*

### 6.3. Heuristic Estimation  

| Strategy | Formula (cost‑based) |
|----------|----------------------|
| `Max`    | `h = max_{c∈unsatisfied} level(c) * minCost[c.Name]` |
| `Add`    | `h = Σ_{c∈unsatisfied} level(c) * minCost[c.Name]` |
| `FF`    | 1. Extract a **relaxed plan** (backward walk from goal through the RPG). 2. Sum the **real base costs** of the actions in that relaxed plan. |

All strategies are **admissible** because delete‑effects are ignored, so the relaxed cost ≤ true optimal cost.

### 6.4. A* Search (GOAPPlanner)

```
open = priority queue ordered by f = g + h
closed = hash set of visited WorldState (hash based on Fact set)

push(start, g=0, f=heuristic(start))

while open not empty
    node = pop(open)
    if goal.IsSatisfiedBy(node.state) → reconstruct plan
    closed.add(node.state)

    for each action a in ActionRepository
        if !a.IsApplicable(node.state) continue
        succ = a.Apply(node.state)
        if closed.contains(succ) continue

        tentativeG = node.g + a.Cost(node.state)
        h = heuristic.Estimate(succ, goal)
        if succ not in open OR tentativeG < recordedG(succ):
            record(succ, parent=node, action=a, g=tentativeG, f=tentativeG+h)
            push(open, succ)
return failure
```

*Determinism*: tie‑breakers in the priority queue are resolved by a **stable ordering** (e.g., alphabetical action name).

---  

## 7. Error‑Handling Strategy  

| Error Condition | Detection | Response | Exception Type |
|-----------------|-----------|----------|----------------|
| **Invalid action definition** (null pre‑condition, missing effect) | Constructor validation | Throw `ArgumentException` at load time | `InvalidActionException` |
| **Goal impossible** (heuristic returns `∞`) | `HeuristicProvider.Estimate` returns `float.PositiveInfinity` | Abort planning, return `false` and set `plan = null` | `GoalUnreachableException` |
| **WorldState inconsistent** (duplicate fact with different values) | `WorldState` constructor / `Apply` | Log error, discard duplicate, keep first occurrence | `WorldStateCorruptionException` |
| **Open list overflow** (exceeds configured limit) | After each insert, check count | Abort search, return failure, optionally fallback to Dijkstra (h=0) | `PlannerResourceException` |
| **Runtime exception inside custom cost function** | `try/catch` around `action.Cost(state)` | Treat cost as `BaseCost`, log warning | `ActionCostException` |
| **Re‑planning while a plan is still executing** | Planner client supplies a new start state while previous plan not finished | Cancel current search, rebuild RPG if start changed, start new plan | N/A (handled by client) |

All public methods return **bool** (`true` = success) plus `out` parameters; exceptions are only thrown for programmer errors (invalid data) or unrecoverable internal failures.

---  

## 8. API Specification  

### 8.1. Public Interfaces  

```csharp
// ------------------------------------------------------------
// 1. Fact / Condition / Effect
// ------------------------------------------------------------
public enum FactType { Bool, Numeric, Position }

public readonly struct Fact
{
    public FactType Type { get; }
    public string Name { get; }
    public bool BoolValue { get; }
    public int NumericValue { get; }
    public Vector3 PositionValue { get; }
    // Equality / GetHashCode based on (Type, Name, value)
}

public readonly struct Condition
{
    public FactType Type { get; }
    public string Name { get; }
    public ComparisonOperator Op { get; }   // Eq, Ge, Le, Gt, Lt
    public bool BoolValue { get; }
    public int NumericValue { get; }
    public Vector3 PositionValue { get; }
    public bool Matches(Fact f);            // true if f satisfies this condition
}

public readonly struct Effect
{
    public Fact Fact { get; }
    public bool IsAdd { get; }               // true = add, false = delete
}

// ------------------------------------------------------------
// 2. Action base class
// ------------------------------------------------------------
public abstract class Action
{
    public abstract IReadOnlyList<Condition> Preconditions { get; }
    public abstract IReadOnlyList<Effect> AddEffects { get; }
    public virtual IReadOnlyList<Effect> DeleteEffects => Array.Empty<Effect>();
    public virtual float BaseCost { get; } = 1f;
    public virtual float Cost(WorldState state) => BaseCost;

    public bool IsApplicable(WorldState s) =>
        Preconditions.All(c => s.Satisfies(c));

    public WorldState Apply(WorldState s)
    {
        var ns = s.Clone();
        foreach (var e in AddEffects)    ns.AddFact(e.Fact);
        foreach (var e in DeleteEffects) ns.RemoveFact(e.Fact);
        return ns;
    }
}

// ------------------------------------------------------------
// 3. WorldState
// ------------------------------------------------------------
public sealed class WorldState
{
    public IReadOnlyCollection<Fact> Facts { get; }
    public bool Satisfies(Condition c);
    public WorldState Clone();               // deep copy of the fact set
    internal void AddFact(Fact f);
    internal void RemoveFact(Fact f);
}

// ------------------------------------------------------------
// 4. Goal
// ------------------------------------------------------------
public sealed class Goal
{
    public IReadOnlyList<Condition> Conditions { get; }
    public bool IsSatisfiedBy(WorldState s) =>
        Conditions.All(c => s.Satisfies(c));
}

// ------------------------------------------------------------
// 5. RelaxedPlanningGraph
// ------------------------------------------------------------
public sealed class RelaxedPlanningGraph
{
    public IReadOnlyList<IReadOnlyCollection<Fact>> FactLayers { get; }
    public IReadOnlyList<IReadOnlyCollection<Action>> ActionLayers { get; }

    // Returns the first layer index where condition c becomes true,
    // or int.MaxValue if it never appears.
    public int FirstLevel(Condition c);
}

// ------------------------------------------------------------
// 6. HeuristicProvider
// ------------------------------------------------------------
public enum HeuristicStrategy { Max, Add, FF }

public sealed class HeuristicProvider
{
    public HeuristicProvider(RelaxedPlanningGraph rpg,
                             IReadOnlyDictionary<string,float> minFactCost,
                             HeuristicStrategy strategy = HeuristicStrategy.Add);
    public float Estimate(WorldState state, Goal goal);
}

// ------------------------------------------------------------
// 7. GOAPPlanner
// ------------------------------------------------------------
public sealed class GOAPPlanner
{
    public GOAPPlanner(IReadOnlyList<Action> actions,
                       HeuristicStrategy strategy = HeuristicStrategy.Add,
                       int maxOpenListSize = 50000);
    // Returns true if a plan was found.  On failure 'plan' is null.
    public bool TryPlan(WorldState start, Goal goal,
                       out List<Action> plan,
                       out PlanningStatistics stats);
}

// ------------------------------------------------------------
// 8. Statistics (optional, for profiling)
// ------------------------------------------------------------
public struct PlanningStatistics
{
    public int NodesExpanded;
    public int NodesGenerated;
    public TimeSpan PlanningTime;
    public int GraphLayers;      // number of RPG layers
    public int GraphActions;     // total actions in RPG
}
```

### 8.2. Usage Example  

```csharp
// 1. Build static action list (once at level load)
var actions = new List<Action>
{
    new MoveToAction(oreNodePos),
    new CollectMaterialAction(&amp;quot;Ore&amp;quot;, 10),
    new MoveToAction(forestPos),
    new CollectMaterialAction(&amp;quot;Wood&amp;quot;, 5),
    new BuildAxeAction()
};

// 2. Create planner
var planner = new GOAPPlanner(actions, HeuristicStrategy.Add);

// 3. Define start state and goal
var start = new WorldStateBuilder()
                 .WithPosition(startPos)
                 .WithFact(new Fact(FactType.Bool, &amp;quot;HasAxe&amp;quot;, false))
                 .Build();

var goal = new Goal(new[]
{
    new Condition(FactType.Bool, &amp;quot;HasAxe&amp;quot;, ComparisonOperator.Eq, true)
});

// 4. Request a plan
if (planner.TryPlan(start, goal, out var plan, out var stats))
{
    // plan is a List<Action> ready to be queued for execution
}
else
{
    // handle unreachable goal
}
```

---  

## 9. Data‑Handling Details  

| Component | Persistence | Thread‑Safety | Notes |
|-----------|-------------|----------------|-------|
| `ActionRepository` | In‑memory, loaded at level start. | Read‑only after construction. | Can be shared across multiple planner instances. |
| `RelaxedPlanningGraph` | Built on‑the‑fly, cached per start state. | Immutable after construction. | Can be stored in a dictionary keyed by a hash of the start state for reuse. |
| `WorldState` | Transient – created per node expansion. | Not shared; each thread gets its own copy. | Implement `IEquatable<WorldState>` for fast closed‑list lookup (hash = XOR of fact hashes). |
| `Open list` | In‑memory priority queue. | Only accessed by the planner thread. | Use a binary heap with a stable tie‑breaker (action name). |
| `HeuristicProvider` | Stateless after construction. | Thread‑safe if used read‑only. | Holds reference to the immutable RPG and the `minFactCost` map. |

---  

## 10. Testing Plan  

### 10.1. Unit Tests  

| Test Suite | Target | Example Cases |
|------------|--------|----------------|
| **Fact/Condition** | Equality, `Matches` logic | Bool true/false, numeric ≥, ≤, position equality |
| **WorldState** | Add/Remove, `Satisfies` | Insert a fact, check condition, clone immutability |
| **Action** | `IsApplicable`, `Apply` | Action with multiple pre‑conditions, delete‑effects |
| **RPG Builder** | Layer generation, `FirstLevel` | Small domain where expected layers are known (e.g., 3‑layer graph). |
| **MinFactCost** | Correct per‑fact cost | Actions with different amounts (10 ore for cost 2 → per‑unit 0.2). |
| **HeuristicProvider** | `Max`, `Add`, `FF` values | Compare against hand‑computed numbers. |
| **GOAPPlanner** | Successful plan, failure detection | *Reachable* goal (build axe), *unreachable* goal (need 100 wood). |
| **Planner Re‑planning** | Detect start‑state change → rebuild RPG | Change agent position after first expansion. |

All unit tests must run in **≤ 10 ms** each on the reference hardware.

### 10.2. Integration Tests  

1. **Full pipeline** – load a JSON definition of actions + world, request a plan, verify that the returned plan is executable (apply each action sequentially and end state satisfies the goal).  
2. **Stress test** – 100 random start/goal pairs on a medium‑size domain (≈ 30 facts, 25 actions). Record max planning time; must be ≤ 5 ms.  
3. **Determinism test** – run the same start/goal 100 times; all returned plans must be identical (same ordering, same actions).  

### 10.3. Performance Benchmarks  

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| **Planning latency** | ≤ 5 ms (average) | Stopwatch around `TryPlan`. |
| **Memory usage (RPG)** | ≤ 2 MiB | .NET memory profiler, count bytes of fact layers. |
| **Nodes expanded** | ≤ 200 for typical goal | Record `stats.NodesExpanded`. |
| **Open‑list size** | ≤ maxOpenListSize (default 50 k) | Ensure no overflow exception. |

All benchmarks must be part of the CI pipeline (e.g., using `dotnet test --filter Category=Performance`).

---  

## 11. Deployment &amp; Integration Checklist  

| Step | Description | Done? |
|------|-------------|-------|
| 1 | Add `Action` subclasses for all gameplay actions (MoveTo, Collect, Build, etc.). | |
| 2 | Populate `ActionRepository` (static JSON or code‑generated). | |
| 3 | Wire the `GOAPPlanner` into the AI component (e.g., `AgentPlanner`). | |
| 4 | Implement fallback to simple Dijkstra (`HeuristicStrategy = Max` with all costs = 0) for debugging. | |
| 5 | Add logging hooks (`PlannerLogger`) that emit `PlanningStatistics`. | |
| 6 | Write unit &amp; integration tests (see §10). | |
| 7 | Run performance benchmark on target platforms (PC, console, mobile). | |
| 8 | Document public API in the code base (XML comments). | |
| 9 | Review thread‑safety and determinism with QA. | |
|10 | Merge to `main` branch, tag release `goap‑v1.0`. | |

---  

## 12. Future Extensions (Not part of v1.0)

| Feature | Reason | Impact |
|---------|--------|--------|
| **Temporal actions** (duration, overlapping) | Needed for more realistic combat. | Requires Time‑expanded state, new heuristic. |
| **Probabilistic effects** | For stochastic resource gathering. | Heuristic becomes expected‑cost; need Monte‑Carlo or PDDL‑style extensions. |
| **Hierarchical GOAP** (high‑level goals → sub‑goals) | Improves scalability for huge worlds. | Adds goal decomposition layer before RPG. |
| **Multi‑agent cooperative planning** | Group tactics. | Requires joint state space, conflict resolution. |
| **Dynamic action costs** (e.g., stamina‑dependent move speed) | More expressive AI. | Heuristic must be recomputed when cost function changes. |

---  

## 13. Glossary  

* **GOAP** – Goal‑Oriented Action Planning, a planning technique for game AI.  
* **RPG** – Relaxed Planning Graph, a monotone planning graph ignoring delete‑effects.  
* **Heuristic** – Estimate of remaining cost (`h`) used by A*.  
* **`h_max`** – Max‑level heuristic (max layer index of any unsatisfied goal).  
* **`h_add`** – Sum‑of‑levels heuristic (sum of layer indices).  
* **`h_ff`** – Cost of a relaxed plan extracted from the RPG (Fast‑Forward heuristic).  

---  

### End of Specification  


---

# Part 2: Analysis of Other Specification Points

Analysis and scoring of the *other* requirements from the spec, rated on how necessary they are for improving your **current Lua codebase**.

| Spec Point | Analysis | Necessity Score (0-100) |
| :--- | :--- | :--- |
| **FR-01: Formal Fact Types** (Bool, Numeric, Position) | Your system already handles booleans and numerics implicitly in tables. Formalizing them into `Fact` objects would make the system more robust and type-safe, preventing errors like comparing a number to a boolean. It's a major refactoring but a significant quality-of-life improvement. | **75/100** |
| **FR-02: Explicit Add/Delete Effects & Dynamic Costs** | This is a massive improvement. **Dynamic Costs** (`Cost(WorldState)`) are almost essential for a Zomboid-like game (e.g., walking costs more if injured). **Explicit Add/Delete Effects** would simplify the planner logic, as it wouldn't have to infer them from a `reaction` table. | **90/100** |
| **FR-06: Dynamic Replanning** | Your current system has no formal support for this. In a dynamic game, plans *will* become invalid. The agent needs to detect this (e.g., a required item is gone) and trigger a re-plan. This is a crucial feature for a real game agent. | **95/100** |
| **FR-08: Diagnostics / Statistics** | You have basic timing. The spec's formal `PlanningStatistics` struct is a clean way to bundle metrics like nodes expanded, RPG size, etc. Very useful for debugging and profiling, but not critical for core functionality. | **60/100** |
| **FR-09: Unsolvable Goal Exception** | Your `astar` returns an empty table `{}`. The RPG heuristic returning `math.huge` makes this check more explicit and robust. Throwing a specific error/exception is a style choice; returning `nil` or an empty table is perfectly idiomatic in Lua. The core improvement (detecting impossibility) is a side effect of the RPG. | **50/100** |
| **NFR-04: Extensibility (Plug-in design)** | The current structure is already quite modular. Formalizing it further with abstract base classes and interfaces (as the C# spec implies) is good practice but might be over-engineering for a Lua project unless the team and complexity grow significantly. | **40/100** |
| **Section 5: Full Data Model** | This describes the C# implementation of the above points (`Fact`, `Condition`, `Effect` structs/classes). Adopting this would mean a near-total rewrite of `Action.lua` and how states are represented. It's the "right" way for a large, typed project but a huge undertaking. | **80/100** |
| **Section 6.2: MinFactCost** | The `h_add` I outlined above uses "number of layers" as cost. The spec correctly notes that a better heuristic uses the *actual action costs*. E.g., if `getWood` costs 5 and `getOre` costs 2, the heuristic should reflect that. This makes the heuristic much more informed. This is a highly recommended improvement to the RPG. | **85/100** |
| **Section 7: Error-Handling Strategy** | The spec proposes a detailed C#-style exception hierarchy. Lua's error handling is different (`error()` for fatal, `return nil, "msg"` for recoverable). Sticking to Lua idioms is better than forcing a C# pattern. | **20/100** |

**Summary of Analysis:**

The most valuable and impactful features from the spec to consider for your Lua planner are:
1.  **Dynamic Replanning (Score: 95):** Your agent will be blind without this.
2.  **Dynamic Action Costs (Score: 90):** Essential for making AI behavior feel responsive to the world state (fatigue, injury, encumbrance).
3.  **Cost-Based RPG Heuristic (Score: 85):** Significantly improves planner performance by providing a more accurate heuristic.
4.  **Formalized Data Model (Score: 75-80):** A big investment, but it would pay dividends in robustness and clarity as your game's complexity grows.