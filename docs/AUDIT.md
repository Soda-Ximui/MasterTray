# AUDIT LOG: FrankenTray Architecture Updates

## Part 1: Resolving MVC Controller Anti-Pattern
* **Target Files:** `MasterManifest.scad` (Layer 2.8) and `MasterDispatcher.scad` (Layer 2.5)
* **Objective:** Ensure pure separation of concerns. The Manifest must compile intents, and the Dispatcher must purely route without mutating data.

**1. Restoring the Pure Router (Dispatcher)**
* **Problem:** Initial iterations forced the dispatcher to evaluate user parameters (`w != l`) and iteratively spoof array queues, turning the router into a secondary compiler and breaking the strict MVC pipeline. This caused exponential geometry overlaps.
* **Solution:**
  - Completely stripped structural and logic manipulation out of `MasterDispatcher.scad`. 
  - Re-established it as a "dumb" router. Its only dynamic function is to check for the presence of the `IS_JAR_GRID` boolean in a payload. If true, it spoofs the `TYPE` parameter to `JAR` strictly for the scope of the `render_box_grid` call, guaranteeing the cookie-cutter intersection safely executes downstream.

**2. Pushing Logic to the Controller (Manifest)**
* **Problem:** The core system didn't natively know how to duplicate base jar geometry or drop-in grids when the UI `part_width` and `part_length` sliders were asymmetrical. 
* **Solution:** - Embedded the dual-spawning logic directly into `get_raw_queue()`. When intents like `"Threaded Jar"` or `"Open Jar"` are called and `w != l`, the manifest explicitly queues *both* sizes of jars into the base array. 
  - Updated `compile_manifest()` to dynamically build a second drop-in grid queue (`drop_in_2`). It only triggers if the base intent is a Jar and `w != l`.
  - Applied the `IS_JAR_GRID` tag to all drop-in items queued for a jar base, granting the dispatcher the context it needs downstream.
  - Result: The dispatcher receives a perfectly flat, pre-compiled array of objects with zero guesswork required. 

## Part 2: Composite Intent Architectures
* **Target Files:** `MasterManifest.scad` (Layer 2.8) and `MasterBuilder.scad` (Layer 3)
* **Version Bump:** `[v1.5]` -> `[v1.6]`

**1. Introducing Pillbox Assembly Composites**
* **Problem:** Need to spawn comprehensive sets combining multiple 7-day and 1-day pillbox geometries into unified build plates for bulk slice preparation. 
* **Solution:**
  - Integrated three new `intent` cases directly into the Manifest Router using the `make_assembly()` recursive function:
    1. `"Pillbox Set (Double Lid)"` triggers compilation of `"14-Day AM/PM Box"` and `"1-Day AM/PM Box"`.
    2. `"Pillbox Set (Single Lid)"` triggers compilation of `"7-Day Pill Box"` and `"1-Day 2-Compartment (Single Lid)"`.
    3. `"Pillbox Full Set"` recursively delegates to the two new sets above, demonstrating third-level abstraction within the MVC pipeline. 

## Part 3: Resolving Pillbox Internal Grid Rendering Failure
* **Target File:** `MasterManifest.scad` (Layer 2.8)
* **Version Bump:** `[v1.6]` -> `[v1.7]`

**1. Pillbox Inherent Parameter Force**
* **Problem:** Pillbox intents dynamically injected a `GRID_LAYOUT` string into the array payload to format internal dividers (e.g., "7x1"), but failed to inject `[HAS_BUILTIN_GRID, true]`. Because of this omission, `RenderGrid.scad` defaulted to reading the `GRID_TYPE` state from the user UI (which may have been set to "Drop-in" or "None"). Consequently, the box printed empty.
* **Solution:**
  - Explicitly appended `[HAS_BUILTIN_GRID, true]` and `[GRID_TYPE, "Built-in"]` into the `concat` generation arrays for all Pillbox primitives in `get_raw_queue()`.
  - This ensures pillboxes are rendered correctly as continuous solids regardless of what dropdown UI state the user left the Customizer in.

**2. Drop-in Grid Suppression for Fixed Assemblies**
* **Problem:** Because the UI `GRID_TYPE` was left on "Drop-in" while rendering a pillbox, the `compile_manifest()` global array compiler assumed the user wanted an independent drop-in grid matching the UI string, resulting in rogue grids spawning next to empty boxes. 
* **Solution:**
  - Established an `is_pillbox_intent` boolean check in `compile_manifest()`.
  - Updated the `needs_drop_in` logic filter to strictly evaluate to `false` if `is_pillbox_intent` is true. This quarantines fixed-layout assemblies from arbitrary UI cross-contamination. 

## Part 4: Resolving Grid Packing & Manifest Desync
* **Target Files:** `MasterEngine.scad` (Layer 1) and `MasterManifest.scad` (Layer 2.8)
* **Version Bumps:** Engine to `[v4.13]`, Manifest to `[v1.8]`

**1. Matrix Packing Reversion (The Convoy Bug)**
* **Problem:** Rendering highly asymmetrical composite sets (like 300mm wide boxes alongside 40mm lids) caused the `v4.12` matrix layout to generate huge empty gaps. The global `get_manifest_max_dims` function forced all objects into bounding cells sized to the absolute largest array item. Because the massive grid cell exceeded the 250mm plate limit, the engine wrapped every single object onto a new row, resulting in a 1-column layout along the Y-axis.
* **Solution:**
  - Reverted `get_xy()` back to an efficient Next-Fit "Shelf-Packing" algorithm.
  - Layouts are now tightly packed along the X-axis by their individual `w` footprints. 
  - Wraps dynamically calculate Y-axis offsets based only on the tallest item in the immediately preceding row.

**2. Directory Synchronization**
* **Problem:** The uploaded file directory appeared to be missing recent fixes, specifically the forced inheritance of internal grids within pillbox sets.
* **Solution:**
  - Deployed `MasterManifest.scad` `v1.8`. Re-applied the `is_pillbox_intent` safety filter and strict `[HAS_BUILTIN_GRID, true]` parameter injection so pillbox assemblies will render flawlessly regardless of UI grid states.