# GOAP Debugging Toolkit – Development Summary  

**Repository:** `GOAPlua` (Lua 5.1)  
**Goal:** Turn the existing GOAP library into a *debug‑friendly* tool that can be invoked from the command line, inspect the planner’s state, and run the planner interactively without editing the original example files.

---  

## 1.  What we wanted to achieve  

| Feature | Why it matters | How we implemented it |
|---------|----------------|-----------------------|
| **One‑liner debugging** (`lua5.1 -e "require('goap.debug.run_example')('example/foo.lua')`) | Developers can run any existing example and instantly drop into a REPL that already contains the world, start state, goal state and actions. | Added `goap/debug/run_example.lua` that loads an example in a sandbox, captures the `Planner` and `Action` objects, and starts the REPL. |
| **Interactive REPL** (`goap> …`) | Allows quick “try‑and‑error” tweaks (add actions, change weights, modify start/goal) without touching source files. | Implemented `goap/debug/Debugger.lua` with a command‑dispatch loop (`cmd_<name>` methods) and a `help` command. |
| **Verbose A\*** (statistics) | Gives insight into search cost (expansions, max open list). | Added `PlannerDebug:run_debug()` that wraps `Goap.astar`, gathers `stats` and returns `plan, stats`. |
| **Goal‑validation guard** | Prevents spurious “cannot be produced” errors caused by wildcard goal keys (`-1`). | Updated `PlannerDebug:validate()` to skip keys whose goal value is `-1`. |
| **Pretty printing of actions** | `dump actions` used to crash because `pl.pretty` has no `table` function. | Replaced `pretty.table` with `pretty.write` (or `pretty.dump`). |
| **Goal restoration** | After a run the planner’s goal could be polluted (e.g., `atContainer`). | `Debugger:set_planner()` stores a deep copy of the original goal; `cmd_run` restores it before each run. |
| **Help command** | The REPL originally reported “unknown command – type ‘help’”. | Added `Debugger:cmd_help()` that forwards to `self:help()`. |
| **Non‑intrusive integration** | Existing library API stays unchanged. | All debug code lives under `goap/debug/` and is mixed‑in only at runtime. |

---  

## 2.  Files added / modified  

| File | Purpose |
|------|---------|
| **`goap/debug/run_example.lua`** | Loads an example script in a sandbox, monkey‑patches `goap.Planner`&`goap.Action` to capture the objects, then starts the REPL. |
| **`goap/debug/Debugger.lua`** | Interactive console. Added: <br>• `cmd_help` wrapper.<br>• `set_planner(planner, actions)` (stores a deep copy of the original goal).<br>• Goal restoration in `cmd_run`. |
| **`goap/debug/PlannerDebug.lua`** | Added `run_debug` (debug‑aware A* with stats). <br>Fixed `validate` to skip wildcard goal entries. <br>Fixed `dump_actions` to use `pretty.write`. |
| **`goap/debug/ActionDebug.lua`** | Unchanged – helper for action inspection. |
| **`goap/debug/RPGDebug.lua`** | Unchanged – dumps the relaxed‑planning‑graph. |
| **`example/scavenge_then_barricade.lua`** | No changes required; the wrapper works with the original script. |

---  

## 3.  How to use it  

### 3.1  Run an example with the debugger  

```bash
lua5.1 -e "require('goap.debug.run_example')('example/scavenge_then_barricade.lua')"
```

*The example runs once, prints the plan, then drops you into the `goap>` REPL.*

### 3.2  REPL commands (quick reference)

| Command | Description |
|---------|-------------|
| `help` | Show the command list. |
| `run [verbose]` | Execute the planner again (verbose prints A* stats). |
| `new_world <key1> <key2> …` | Create a fresh planner (clears everything). |
| `start k=v …` | Set the start state (bool/number). |
| `goal k=v …` | Set the goal state. |
| `add_task <name> <count>` | Load a task factory (`scavenge`, `barricade`, …). |
| `add_action <name>` | Interactive creation of a single custom action. |
| `set_weight <action> <weight>` | Change an action’s cost. |
| `dump actions` | List every action with its pre‑conditions, effects and weight. |
| `dump state` | Show start and goal states. |
| `dump unreach` | List actions whose pre‑conditions are never satisfied from the start. |
| `dump rpg` | Print the relaxed‑planning‑graph (useful for heuristic debugging). |
| `dump goal` | Show which actions can satisfy each concrete goal key. |
| `quit` / `exit` | Leave the REPL. |

### 3.3  Example REPL session

```text
goap> run
=== PLAN (total cost = 61) ===
 1. ensureResources                (g = 1)
 …
18. finish                         (g = 61)

--- Stats ---
expansions : 112
max open   : 23

goap> dump actions
[ensureResources] w=1
  pre: {hasHammer = false}
  eff: {hasHammer = true, hasPlank = true, hasNails = true}
[findWindow3] w=2
  pre: {windowsRemaining = 3, hasTarget = false}
  eff: {hasTarget = true}
…

goap> set_weight ensureResources 5
Weight updated.

goap> run verbose
=== A* finished (0.001s) ===
=== PLAN (total cost = 65) ===
 1. ensureResources                (g = 5)
 …
--- Stats ---
expansions : 124
max open   : 27
```

---  

## 4.  Important technical notes  

| Issue | Resolution |
|-------|------------|
| `Goal key 'atContainer' cannot be produced` | `PlannerDebug:validate` now **skips** goal entries whose value is `-1` (wild‑card). |
| `dump actions` raised *“attempt to call field 'table' (a nil value)”* | Replaced the non‑existent `pretty.table` with `pretty.write`. |
| `run` returned `stats = nil` | After fixing validation, `PlannerDebug:run_debug` correctly returns `(plan, stats)`. |
| `help` command not recognized | Added `Debugger:cmd_help`. |
| Goal gets polluted after a run | `Debugger:set_planner` stores a deep copy of the original goal; `cmd_run` restores it before each execution. |
| Infinite recursion when using `--debug` flag inside an example | `run_example.lua` clears `arg` while loading the script, preventing the script from re‑entering the wrapper. (Optional – you can also place the flag handling at the *bottom* of an example file.) |

---  

## 5.  Result  

All original GOAP examples continue to work **unchanged**.  
With the new debugging toolkit you now have:

* A **single‑line entry point** that loads any example and opens an interactive console.
* Full **inspection** of actions, states, unreachable actions and the relaxed‑planning‑graph.
* Ability to **tweak** start/goal, add/remove actions, change weights, and instantly re‑run the planner.
* Detailed **A\*** statistics (expansions, max open‑list size) for performance analysis.

The repository now contains a self‑contained, non‑intrusive debugging layer that can be used for rapid prototyping, unit‑testing, or teaching GOAP concepts.  

