---
title: MasterTray — Documentation
author: MasterTray Project
date: 2026
---

# MasterTray Documentation

Parametric 3D-printable storage system — pill organizers, jars, trays, and
modular grids — built on OpenSCAD with a strict MVC architecture and a Perl
build pipeline.

---

## Quick Start

New here? Read these in order:

1. **[How-To Guide](html/HOWTO.html)** — Customizer walkthrough, CLI export,
   Perl build queue, and slicer guide generation
2. **[Grid Layout String Reference](html/GRID_LAYOUT_GUIDE.html)** — full
   syntax for `7x5 S2/2/2/3/75% R3 C15%`
3. **[CLI Reference](html/CLI_GUIDE.html)** — every `-D` flag, batch scripts,
   and the Perl report pipeline

---

## Architecture Diagram

![MasterTray include architecture — 5 layers from MasterBuilder down to support modules](img/architecture.svg)

*Each layer can only include files from its own layer or below.
Dashed orange = compiler link (Manifest → MasterBuilder).
Purple dotted = transitive engine dependency.*

---

## Codebase File Set

### Layer 4 — User Interface

| File | Role |
|------|------|
| `MasterBuilder.scad` | **Primary entry point.** Customizer UI, `ui_payload` assembly, `build_part` dispatcher. Use this file — not `MasterBuild2`. |

### Layer 3 — Factories (Renderers)

Each factory is a "dumb renderer": it only receives a clean data array and executes geometric math.

| File | Renders |
|------|---------|
| `RenderTray.scad` | `factory_render_tray` — hollow chassis, mesh walls/floor, wall mods, stackable (Peg / Builtin / Snap) |
| `RenderBox.scad` | `factory_render_box` — all LID_TYPE variants inline: Snap, Glide, Flip_Single, Flip_Double |
| `RenderLid.scad` | `factory_render_lid` — Snap, Glide (H/V, Ball/Tab), Flip_Single (C-clip hinge + diamond latch), Screw |
| `RenderJar.scad` | `factory_render_jar` — cylindrical body, mesh walls/floor, optional threaded neck, built-in grid |
| `RenderGrid.scad` | `factory_render_grid` — drop-in and built-in cartesian + radial grids; `render_internal_grid` |
| `RenderPeg.scad` | `factory_render_peg` — standalone peg rods for Peg-stack trays |
| `RenderPlaque.scad` | `factory_render_plaque` — text label plate (Embedded / Standalone styles) |
| `RenderRib.scad` | `factory_render_ribs` — FrankenTray vector rib dividers *(Primitive 5, not yet started)* |
| `RenderMesh.scad` | `framed_mesh`, `cylindrical_mesh_wall` — mesh hole patterns for all surfaces |
| `MasterDebug.scad` | `dump_build_options` (human report), `dump_build_payload` (PSV for Perl pipeline) |
| `GridLayout.scad` | `get_grid_config`, `parse_cartesian`, `parse_radial`, `parse_spans` — layout string parser |

### Layer 2 — Compiler

| File | Role |
|------|------|
| `MasterManifest.scad` | `compile_manifest(intent, data)` — single source of truth for what gets built; all intent routing |
| `MasterProcessor.scad` | Data transformation pipeline — processes raw ui_payload before manifest routing |

### Layer 1 — Engine / Constants

| File | Role |
|------|------|
| `MasterEngine.scad` | Physics getters (`m_safe_wall`, `m_safe_floor`, `m_bh` …), geometry constraints (`glide_ball_d`, `flip_latch_z` …), `get_xy` platter packer, `apply_master_bounds` |
| `MasterEnum.scad` | All string key constants (`WIDTH`, `GRID_LAYOUT`, `HAS_BUILTIN_GRID` …). Never use raw strings in comparisons. |
| `MasterTolerance.scad` | Material tolerance tables (`ROOM_GLIDE_PETG`, `ENG_CLASP_PLA` …), `breathing_room()`, `engagement_depth()` |
| `MasterConstants.scad` | Numeric design constants (layer height presets, nozzle sizes) |

### Support Modules

| File | Used by |
|------|---------|
| `MasterMeshPatterns.scad` | `RenderMesh` — hole pattern geometry (Teardrop, Honeycomb, Slotted …) |
| `MasterText.scad` | `RenderPlaque`, `MasterUtility` — text extrusion helpers |
| `MasterUtility.scad` | `RenderRib` — general geometry utilities for rib rendering |
| `MasterValidation.scad` | `MasterUtility` — grid layout string validation functions |

### Deprecated (moved to `deprecated/`)

| File | Reason |
|------|--------|
| `MasterBuild2.scad` | Old builder — superseded by `MasterBuilder.scad`. Not included by anything. |
| `TEST_VALIDATION_SUITE.scad` | Standalone test file — not part of the production include graph. |

---

## User Guides

| Document | What it covers |
|----------|---------------|
| [How-To Guide](html/HOWTO.html) | End-to-end workflow: Customizer → STL → slicer |
| [CLI Reference](html/CLI_GUIDE.html) | OpenSCAD CLI flags, batch export, Perl pipeline |
| [Grid Layout Reference](html/GRID_LAYOUT_GUIDE.html) | `NxM`, spans, radial, height clamping |

---

## Design & Architecture

| Document | What it covers |
|----------|---------------|
| [Lessons Learned](html/LESSONS.html) | Hard-won rules — read before touching code |
| [Architecture](html/ARCHITECTURE.html) | System design, MVC layers, data flow |
| [Product Features](html/PRODUCT.html) | Full feature catalogue by primitive |
| [Future Ideas](html/FUTURE.html) | Deferred features — wall slots, drop-in flip dividers |
| [Features](html/FEATURES.html) | Feature checklist |

---

## Refactoring History

| Document | What it covers |
|----------|---------------|
| [Complete Refactoring Summary](html/COMPLETE_REFACTORING_SUMMARY.html) | Full account of the architecture revamp |
| [Codebase Changes](html/CODEBASE_CHANGES_SUMMARY.html) | File-by-file change log |
| [Phase 2 Refinement](html/PHASE_2_REFINEMENT.html) | Second-pass cleanup notes |
| [Refactoring Notes](html/REFACTORING_NOTES.html) | Working notes from the refactor |
| [MasterBuilder Fixes](html/MASTERBUILDER_FIXES.html) | Bug fixes to the dispatcher |
| [Git Consolidation](html/GIT_CONSOLIDATION_SUMMARY.html) | Branch strategy and squash decisions |
| [Include Dependency Map](html/INCLUDE_DEPENDENCY_MAP.html) | `.scad` include graph |
| [All Tasks Complete](html/ALL_TASKS_COMPLETE.html) | Original task list — fully resolved |
| [Flip Lid Analysis](html/FLIP_LID_ANALYSIS_FIX.html) | Hinge geometry deep-dive and fix |

---

## Project Meta

| Document | What it covers |
|----------|---------------|
| [Agents](html/AGENTS.html) | AI agent usage notes |
| [Learning](html/LEARNING.html) | Development learning log |
| [Audit](html/AUDIT.html) | Code audit findings |
| [GitHub Setup Guide](html/GITHUB_SETUP_GUIDE.html) | Repo and CI setup |
| [Claude Review](html/Claude Review.html) | Code review session notes |
