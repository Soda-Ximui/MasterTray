# Grid Layout String Reference

The `grid_layout` field in the Customizer accepts a **space-separated string** of tokens.
Tokens can appear in any order and are parsed independently.

---

## Quick Examples

```
"3x4"                              3 cols × 4 rows, default wall height
"7x5 S2/2/2/3/75%"                7×5 grid, one span at 75% wall height
"7x5 S2/2/2/3/75% S5/1/1/2/40"   two spans: one %-relative, one absolute (mm)
"R6 C20%"                          6 radial dividers, hub = 20% of jar diameter  (jar only)
"3x4 R6 C20%"                      cartesian OR radial — jar uses radial, box uses cartesian
```

---

## Token Reference

### Cartesian Grid — `NxM`

Divides the interior into **N columns** (left → right) by **M rows** (front → back).

```
"7x5"  →  7 columns, 5 rows  =  35 cells
"1x4"  →  no column dividers, 4 rows  =  4 cells side by side
```

- Columns run along the **Width** axis.
- Rows run along the **Length** axis.
- Omitting cartesian entirely = no dividers.


### Irregular Span — `S<row>/<col>/<row_span>/<col_span>[/<height>]`

Marks a rectangular region of the grid as a **merged, taller-walled area**.

| Field | Meaning |
|-------|---------|
| `row` | Starting row (1 = front) |
| `col` | Starting column (1 = left) |
| `row_span` | How many rows this span covers |
| `col_span` | How many columns this span covers |
| `height` | Optional wall height — absolute mm or `%` of max |

```
S2/2/2/3         row 2, col 2, 2 rows tall, 3 cols wide — default wall height
S2/2/2/3/75%     same region, walls at 75% of permitted max
S2/2/2/3/150%    same region, 150% requested → clamped to permitted max
S5/1/1/2/40      row 5, col 1, 1 row × 2 cols, walls at 40mm absolute
```

**What the span renders:**
The span adds a **hollow border frame** at the specified height around the merged cell
boundary. The border walls are taller than the surrounding default-height dividers,
visually marking the merged area. Interior cross-dividers within the span remain at
default height.

**Height clamping — always enforced:**

| Container | Permitted max height (`GRID_WALL_H`) |
|-----------|--------------------------------------|
| Plain tray / box (Snap, Glide lid) | Interior height minus lid thickness |
| Flip lid box | Hinge axle height — lid must clear dividers to close |
| Threaded jar | Cylinder wall height — below neck taper and thread |
| Open jar | Full interior height |

- `150%` → always clamped to permitted max (effectively the same as omitting the height)
- `75%` → 75% of permitted max — passes through for all container types
- `40` (absolute mm) → used as-is if ≤ permitted max, clamped if taller


### Radial Dividers — `Rn` and `Cn[%]`  *(Jar grids only)*

Defines a **spoke-and-hub** radial divider pattern. Only rendered when the grid is in a
jar context (`IS_JAR_GRID` flag); ignored for trays and boxes.

```
R3           3 spokes = 3 sectors of 120° each
R6           6 spokes = 6 sectors of 60° each
R3 C15%      3 spokes, center hub = 15% of jar interior diameter
R6 C8        6 spokes, center hub = 8mm diameter absolute
```

**Center hub (`C` token):**
- `C20%` — hub diameter = 20% of the jar's interior diameter
- `C8`   — hub diameter = 8mm absolute
- Default (no `C` token) — 6mm solid knob

**Hub rendering:**
- Hub large enough to hollow (inner cavity ≥ 1.5mm after wall thickness) → renders as a **ring**
- Hub too small to hollow → renders as a **solid cylinder**

**Cartesian + Radial combined:**
When a string has both `NxM` and `Rn`, the container type decides which is used:
- Jar context → radial rendered, cartesian ignored
- Box / tray context → cartesian rendered, radial ignored

This lets you write one layout string that works for both jar and box tests.


---

## Combining Tokens

```
"7x5 S2/2/2/3/75% S5/1/1/2/40 R3 C15%"
```

Parsed as:
- `7x5` — 7-column × 5-row base grid
- `S2/2/2/3/75%` — merged region at row 2, col 2, 2 rows × 3 cols, 75% wall height
- `S5/1/1/2/40` — merged region at row 5, col 1, 1 row × 2 cols, 40mm wall height (clamped if too tall)
- `R3 C15%` — if rendered as jar: 3 radial spokes, hub at 15% of interior diameter

---

## Grid Type (Customizer dropdown)

| Setting | Effect |
|---------|--------|
| `Built-in` | Dividers are fused to the container floor during render — one piece |
| `Drop-in` | Standalone printable insert, sized with a small tolerance gap to slide in |
| `None` | No grid rendered |

Drop-in grids optionally add a base plate (`grid_has_base = true`) so the insert
sits on the container floor without resting on divider tips.

---

## Span ASCII Diagram

For `"7x5 S2/2/2/3"` — row 2, col 2, spanning 2 rows × 3 cols:

```
col:   1    2    3    4    5    6    7
     +----+----+----+----+----+----+----+
row1 |    |    |    |    |    |    |    |
     +----+====+====+====+----+----+----+
row2 |    ‖              ‖    |    |    |   ← span starts here
     +    +    span      +----+----+----+
row3 |    ‖              ‖    |    |    |   ← span ends here
     +----+====+====+====+----+----+----+
row4 |    |    |    |    |    |    |    |
     +----+----+----+----+----+----+----+
row5 |    |    |    |    |    |    |    |
     +----+----+----+----+----+----+----+
```

`=` and `‖` show the span border walls (rendered taller than surrounding dividers).
