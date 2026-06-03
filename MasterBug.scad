// ==============================================================================
// FILE: MasterBug.scad [v1.1]
// ARCHITECTURE: Layer 1.5.1 (Telemetry & Flight Recorder)
// PURPOSE: Centralized logging for FrankenTray state and vector maths
// ==============================================================================

include <MasterEngine.scad>

module log_franken_state(cfg, g_str) {
    if (cfg != undef) {
        rays = cfg[0];
        hub_d = cfg[1];
        offset = cfg[2];
        ribs = cfg[3];
        
        echo(" ");
        echo("=== 🐛 FRANKENTRAY FLIGHT RECORDER ===");
        echo(str("Raw_Input: '", g_str, "'"));
        echo(str("Base Config: Rays: ", rays, " | Hub Dia: ", hub_d));
        echo(str("Global Anchor Offset: [", offset[0], ", ", offset[1], "]"));
        echo("--- RIB TOPOLOGY ARRAY ---");
        if (len(ribs) > 0) {
            for (i = [0 : len(ribs)-1]) {
                echo(str("  Rib ", i+1, ": Trajectory [", ribs[i][0], "] --> Behavior [", ribs[i][1], "]"));
            }
        } else {
            echo("  (No vector ribs compiled)");
        }
        echo("======================================");
        echo(" ");
    }
}