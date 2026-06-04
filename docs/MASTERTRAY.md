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
