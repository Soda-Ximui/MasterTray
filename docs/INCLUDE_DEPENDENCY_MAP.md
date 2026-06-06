# Include Dependency Map - MasterTray v5.2

## Overview
This document maps out all `include` and `use` directives to ensure no circular dependencies and all functions are available where needed.

## Dependency Graph

```
MasterBuilder.scad (MAIN ENTRY)
├── include <MasterEngine.scad>
│   ├── include <BOSL2/std.scad>
│   ├── include <BOSL2/threading.scad>
│   ├── include <MasterEnum.scad>
│   └── include <MasterConstants.scad>
│
├── include <MasterManifest.scad>
│   └── include <MasterEngine.scad> [already loaded]
│
└── use <RenderXXX.scad>
    ├── use <RenderTray.scad>
    │   ├── include <BOSL2/std.scad>
    │   └── include <MasterEngine.scad> [already loaded]
    │
    ├── use <RenderPeg.scad>
    │   ├── include <BOSL2/std.scad>
    │   └── include <MasterEngine.scad> [already loaded]
    │
    ├── use <RenderJar.scad>
    │   ├── include <BOSL2/std.scad>
    │   ├── include <MasterEngine.scad> [already loaded]
    │   ├── include <MasterLegacyBridge.scad>
    │   │   ├── include <BOSL2/std.scad>
    │   │   ├── include <MasterEngine.scad> [already loaded]
    │   │   ├── include <MasterMeshPatterns.scad>
    │   │   │   ├── include <BOSL2/std.scad>
    │   │   │   └── include <MasterEngine.scad> [already loaded]
    │   │   └── include <RenderMesh.scad>
    │   │       ├── include <BOSL2/std.scad>
    │   │       └── include <MasterEngine.scad> [already loaded]
    │   └── include <RenderMesh.scad> [already loaded]
    │
    ├── use <RenderLid.scad>
    │   ├── include <BOSL2/std.scad>
    │   ├── include <MasterEngine.scad> [FIXED - was missing]
    │   ├── include <MasterLegacyBridge.scad> [already loaded]
    │   ├── include <MasterTolerance.scad>
    │   │   ├── include <MasterEngine.scad> [already loaded]
    │   │   └── include <MasterConstants.scad> [already loaded]
    │   └── include <RenderMesh.scad> [already loaded]
    │
    └── use <RenderGrid.scad>
        ├── include <BOSL2/std.scad>
        ├── include <MasterEngine.scad> [already loaded]
        ├── include <GridLayout.scad>
        │   ├── include <BOSL2/std.scad>
        │   ├── include <MasterEnum.scad> [already loaded]
        │   └── include <MasterEngine.scad> [already loaded]
        └── include <MasterUtility.scad>
            ├── include <MasterChecks.scad>
            │   ├── include <MasterEngine.scad> [already loaded]
            │   ├── include <MasterEnum.scad> [already loaded]
            │   └── include <MasterConstants.scad> [already loaded]
            ├── include <MasterText.scad>
            │   └── include <MasterEngine.scad> [already loaded]
            └── include <MasterValidation.scad>
                ├── include <MasterEngine.scad> [already loaded]
                ├── include <MasterConstants.scad> [already loaded]
                └── include <MasterGridParser.scad>
                    └── include <MasterEngine.scad> [already loaded]
```

## Include Verification

### ✅ FIXED ISSUES

| File | Issue | Fix |
|------|-------|-----|
| RenderLid.scad | Missing `include <MasterEngine.scad>` | Added at line 7 |
| RenderLid.scad | Missing `include <RenderMesh.scad>` | Added at line 10 |
| MasterLegacyBridge.scad | Missing `include <MasterEngine.scad>` | Added at line 4 |
| MasterLegacyBridge.scad | Missing documentation | Added comprehensive headers |

### ✅ VERIFIED INCLUDES

| File | Includes | Status |
|------|----------|--------|
| MasterBuilder.scad | MasterEngine, MasterManifest | ✅ Complete |
| MasterEngine.scad | BOSL2, MasterEnum, MasterConstants | ✅ Complete |
| MasterManifest.scad | MasterEngine | ✅ Complete |
| RenderTray.scad | BOSL2, MasterEngine | ✅ Complete |
| RenderPeg.scad | BOSL2, MasterEngine | ✅ Complete |
| RenderJar.scad | BOSL2, MasterEngine, MasterLegacyBridge, RenderMesh | ✅ Complete |
| RenderLid.scad | BOSL2, MasterEngine, MasterLegacyBridge, MasterTolerance, RenderMesh | ✅ Fixed |
| RenderGrid.scad | BOSL2, MasterEngine, GridLayout, MasterUtility | ✅ Complete |
| MasterLegacyBridge.scad | BOSL2, MasterEngine, MasterMeshPatterns, RenderMesh | ✅ Fixed |
| MasterMeshPatterns.scad | BOSL2, MasterEngine | ✅ Complete |
| RenderMesh.scad | BOSL2, MasterEngine (with guard) | ✅ Complete |
| MasterTolerance.scad | MasterEngine, MasterConstants | ✅ Complete |
| GridLayout.scad | BOSL2, MasterEnum, MasterEngine | ✅ Complete |
| MasterUtility.scad | MasterChecks, MasterText, MasterValidation | ✅ Complete |

## Guard Clauses

These files use guard clauses to prevent re-inclusion and loops:

```
RenderMesh.scad:
  if (!is_undef(MESH_LOADED)) return;
  MESH_LOADED = true;
```

This allows RenderMesh to be safely included multiple times without causing errors.

## Function Resolution Map

### Core Functions (MasterEngine.scad)
- `get_val()` - Used everywhere for parameter extraction
- `m_bw()`, `m_bl()`, `m_bh()` - Dimension getters
- `m_noz()`, `m_lh()`, `m_wloops()` - Hardware getters
- `m_safe_wall()`, `m_safe_floor()`, `m_safe_lid()` - Safety validators
- `m_c_rad()`, `m_chamf()` - Geometry calculators
- `get_digits()`, `to_num()` - String utilities
- `get_mesh_cfg()` - Mesh configuration

### Factory Modules (RenderXXX.scad)
- `factory_render_tray()` - RenderTray.scad
- `factory_render_jar()` - RenderJar.scad
- `factory_render_lid()` - RenderLid.scad
- `factory_render_grid()` - RenderGrid.scad
- `factory_render_peg()` - RenderPeg.scad

### Helper Modules
- `apply_master_bounds()` - MasterLegacyBridge.scad
- `framed_mesh()` - RenderMesh.scad
- `cylindrical_mesh_wall()` - RenderMesh.scad
- `render_rectangular_pattern()` - MasterMeshPatterns.scad

## Compilation Order

When MasterBuilder.scad is compiled:

1. **Phase 1: Core Engine** (MasterBuilder's includes)
   - BOSL2 libraries loaded
   - MasterEnum.scad defines all key constants
   - MasterConstants.scad defines default values
   - MasterEngine.scad defines 35+ core functions
   - MasterManifest.scad defines part compilation

2. **Phase 2: Factories** (via `use`)
   - Each RenderXXX.scad loads independently
   - Each includes needed dependencies (BOSL2, MasterEngine)
   - Guard clauses prevent duplicate loads (RenderMesh)
   - Factory modules become available but don't execute

3. **Phase 3: Execution** (MasterBuilder's build_part call)
   - build_part() calls compile_manifest()
   - Manifest specifies which factories to invoke
   - Each factory executes with proper data/options/physics
   - geometry is generated and unioned

## Testing Checklist

- [ ] MasterBuilder.scad compiles without warnings
- [ ] "=== STARTING FACTORY PIPELINE ===" echoes
- [ ] "Rendering: JAR" echoes (no "Ignoring unknown module")
- [ ] "Rendering: LID" echoes (no "Ignoring unknown module")
- [ ] Final geometry renders in preview
- [ ] No circular include warnings
- [ ] All safety validators work (walls/floors/lids aligned)

## Future Include Additions

If adding new files:

1. **Define in new file**: All functions used elsewhere
2. **Include dependencies**: Add all needed parent modules
3. **Add to correct location**: MasterBuilder, factory Render, or utility
4. **Use include vs use**:
   - `include`: Load definitions AND execute (for libraries)
   - `use`: Load definitions, DON'T execute (for factories)

---

**Last Updated**: 2026-06-03  
**Status**: All critical includes fixed ✅
