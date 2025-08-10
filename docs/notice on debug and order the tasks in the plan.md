## Why the planner chose *barricade‑first*  

GOAP does **not** know anything about “story‑logic”.  
It only knows

* the **cost** (weight) of each action, and  
* the **pre‑conditions / effects** you supplied.

When the planner searches for the cheapest path from the start state to the goal it will **always pick the cheapest sequence** that satisfies the goal, even if that sequence feels “backwards” to you.

In the data you gave:

| Action group | Typical weight |
|--------------|----------------|
| `ensureResources` | **1** |
| `findWindow / walkToWindow / equipTools` | **2–3** |
| `barricadeWindow` | **5** |
| `findUnlootedBuilding` | **15** |
| `moveToBuilding` | **5** |
| `enterBuildingViaDoor` | **2** |
| `findContainer / walkToContainer / lootContainer` | **3‑4** |
| `finish` | **1** |

The total cost of **doing all barricading actions first** is

```
1 (ensureResources) + 2*3 (find+walk) + 1 (equip) + 5*3 (barricade) = 29
```

whereas entering the building and looting first would add the expensive *building‑search* actions (15 + 5 + 2 = 22) **before** we ever touch the cheap barricade actions.  
Consequently the planner prefers the cheaper “barricade‑first” ordering and ends up with a total cost of **61** (29 + 22 + 10 = 61).

> **Bottom line:** the plan is perfectly valid; it is simply the cheapest one according to the weights you gave.

---

## Quick checklist for future task‑ordering issues

| Situation | Fix |
|-----------|-----|
| **Action A must happen before B** | Make **B** require a state that only **A** can produce (e.g. `isInside = true`). |
| **Planner picks a “cheaper but wrong” order** | Increase the weight of the “wrong‑order” actions, or add a guard state as above. |
| **You need a “once‑only” flag** | Add a new Boolean key (e.g. `hasEntered = true`) that is set by the entry action and required by later actions. |
| **Multiple independent task groups** | Keep their action names unique, otherwise the later `merge` will silently overwrite earlier definitions. |

---

## 2️⃣ Minimal reproducible world (only the actions that are really needed)

Below is a stripped‑down version that **only contains the actions that are needed to satisfy the goal** (without the `taskComplete` flag).  
Run it as‑is; you should see a multi‑step plan printed to the console.

---

## 3️⃣ Incremental debugging – adding actions back one‑by‑one

If you want to see why a particular action (or group of actions) breaks the plan, use the following checklist:

| Step | What to do | Expected outcome |
|------|------------|------------------|
| **A** | Start from the *minimal* script above (it works). | A plan is printed. |
| **B** | Add **one more scavenge container** (`ScavengeTask.create_actions(2)`). | The planner now has to loot two containers; you should see two `findContainer`, `walkToContainer`, `lootContainer` triples at the end of the plan. |
| **C** | Add a **new barricade window** (`BarricadeTask.create_actions(4)`). | You’ll get an extra `findWindow4 / walkToWindow / barricadeWindow4` block before the loot part. |
| **D** | Re‑introduce the **`taskComplete` flag** in the goal **and** add a tiny finishing action: | ```lua<br>actions:add_condition('finish', {containersToLoot=0, windowsRemaining=0})<br>actions:add_reaction ('finish', {taskComplete=true})<br>actions:set_weight('finish', 1)```<br>Now the original goal works again. |
| **E** | Change the entry method to `&amp;quot;window&amp;quot;` in the start state. | The planner will automatically pick the `enterBuildingViaWindow` action (cost 5) instead of the door version (cost 2). |
| **F** | Remove `ensureResources` from the barricade task (comment it out). | The planner will fail because it cannot ever get `hasHammer`, `hasPlank`, `hasNails` = true, which are required by `equipTools`. You’ll see *“No viable plan”* again – a good sanity check. |

**Tip:** after each change run the script and **compare the printed plan**. If the plan disappears, the most recent change introduced a missing pre‑condition or an unsatisfied goal key.

---

## 5️⃣ Quick checklist for future GOAP debugging

| # | Check | How to verify |
|---|-------|----------------|
| 1 | **All keys used in start/goal are declared in the Planner constructor** | The constructor will raise an error if you miss one. |
| 2 | **Every goal key can be produced by at least one reaction** | Search `add_reaction` calls for the key; if none, either remove the key from the goal or add a “finish” action. |
| 3 | **No action overwrites another’s condition/reaction unintentionally** | When merging two `Action` objects, make sure action names are unique. (In your case they are.) |
| 4 | **Pre‑conditions are reachable** – start state must satisfy at least one action’s condition. | Run the planner with `world:set_heuristic(&amp;quot;zero&amp;quot;)` – if it still returns no plan, the start state is dead‑ended. |
| 5 | **Heuristic does not prune the only valid path** – use `&amp;quot;zero&amp;quot;` (Dijkstra) to double‑check. | If `&amp;quot;zero&amp;quot;` finds a plan but `&amp;quot;rpg_add&amp;quot;` does not, the heuristic implementation may be buggy for this domain. |
| 6 | **Cost values are > 0** – a weight of 0 or negative can break A\*. | `set_weight` asserts `weight > 0`. |

---
