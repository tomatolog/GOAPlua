# GOAPlua Context

## Project Overview
**GOAPlua** is a pure-Lua implementation of **Goal-Oriented Action Planning (GOAP)**. It is designed to be a simple, lightweight library for AI planning in games or simulations. The project is a translation and adaptation of `GOAPy` (Python), offering classes to define actions, planners, and worlds to solve complex goal sequences.

### Key Features
*   **Pure Lua:** No C extensions required (depends only on `penlight`).
*   **Modular Architecture:**
    *   `Action`: Defines sets of actions with preconditions, reactions (effects), and costs.
    *   `Planner`: The core solver that finds a sequence of actions to reach a goal state from a start state using A* search.
    *   `World`: A manager that can evaluate multiple planners to find the best overall strategy (e.g., comparing different entry methods into a building).
*   **Heuristics:** Supports multiple A* heuristics, including a basic "mismatch" count and a more advanced **Relaxed Planning Graph (RPG)** additive heuristic (`rpg_add`).
*   **Task Factories:** Includes reusable "task" modules (in `goap/tasks/`) to quickly generate common action sets like `barricade`, `chop_wood`, or `scavenge`.

## Architecture & Structure
*   **`goap/`**: The core library source code.
    *   `init.lua`: The main entry point. Exports the public API.
    *   `Action.lua`: Class for managing action definitions.
    *   `Planner.lua`: The A* planner implementation.
    *   `World.lua`: Manager for multiple planners.
    *   `relaxed_planning_graph.lua`: Implementation of the RPG heuristic.
    *   `tasks/`: Directory containing factory functions for pre-made action sets.
*   **`specs/`**: Unit tests written for the `busted` testing framework.
*   **`example/`**: Practical usage examples (Lua scripts).
*   `docs/`: Documentation files and specifications.
*   `spec_task_conv.md`: Specification for converting legacy SS tasks to GOAP actions.
*   `pl/`: (Optional) Vendored copy of Penlight for environments without Luarocks.

## Building and Running

### Prerequisites
*   **Lua 5.1+** (or LuaJIT)
*   **Luarocks** (package manager)

### Installation
1.  **Dependencies:** Install `penlight` and `busted`.
    ```bash
    luarocks install penlight
    luarocks install busted
    ```
2.  **Usage:** Simply `require("goap")` in your Lua script. Ensure the library is in your `package.path`.

### Running Tests
The project uses `busted` for unit testing.
```bash
busted specs/*
```

## Development Conventions

### Coding Style
*   **OOP:** Uses `pl.class` from Penlight for object-oriented structures (`Planner`, `Action`, `World`).
*   **Error Handling:** Extensive validation of inputs (e.g., strictly checking for positive numeric weights). Errors are raised with descriptive messages.
*   **State Representation:** World states are tables of string keys to values (often booleans or integers). Unknown states are represented internally as `-1`.
*   **Immutability:** The library frequently uses `deepcopy` to prevent side effects on passed state tables or action definitions.

### Testing
*   **Framework:** `busted` (BDD style: `describe`, `it`, `assert`).
*   **Coverage:** Tests cover success paths, edge cases (no plan found), and error conditions (invalid weights, missing reactions).
*   **Location:** All tests are located in `specs/`.

### Key APIs
*   `goap.Planner(keys...)`: Initialize with all possible state keys.
*   `planner:set_start_state({...})`: Set initial conditions.
*   `planner:set_goal_state({...})`: Set target conditions.
*   `planner:set_action_list(actions)`: Assign the `Action` object.
*   `planner:calculate()`: Returns the plan (list of nodes) or `nil`.
