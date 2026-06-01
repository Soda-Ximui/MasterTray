// ==============================================================================
// FILE: MasterChecks.scad [v4.1]
// ARCHITECTURE: Layer 1.1 (Legacy Compatibility Wrapper)
// DEPRECATED: Use MasterSafety.scad directly
// ==============================================================================

// [V4.1] This file now delegates to MasterSafety.scad for backwards compatibility.
// All safety logic has been moved to MasterSafety with expanded documentation.
// This wrapper ensures existing code that includes MasterChecks continues to work.

include <MasterSafety.scad>

// Legacy function exports (these are now defined in MasterSafety.scad)
// No implementation here—just re-exporting for backwards compatibility
// (OpenSCAD's include mechanism makes all functions from MasterSafety available)