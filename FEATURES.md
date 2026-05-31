Version 3.1, I injected the render_internal_grid(data) module directly into the two lowest-level "chassis" functions:

core_tray_chassis: This is the geometric foundation for all square/rectangular objects.

render_jar: This is the geometric foundation for all cylindrical objects.

Because of this inheritance, the Built-in Grid option automatically cascaded to all of these intents without us having to write extra code for them:

The Trays: Simple Tray, Stackable Tray.

The Boxes: Standard Box, Standalone Box, Flip Box, Double Flip Box.

The Jars: Open Jar, Threaded Jar.

If you set the UI to Grid Type = "Built-in" and select "Threaded Jar" with GRID_LAYOUT = "C10 R4", it will instantly print a threaded jar with a 10mm central column and 4 radial dividers physically fused to the inner walls. If you change the intent to "Simple Tray" and GRID_LAYOUT = "3x3", it prints a solid tray with a permanent tic-tac-toe grid fused inside.