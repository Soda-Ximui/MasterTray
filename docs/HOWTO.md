# MasterTray — How-To Guide

From design intent to finished print. Covers the Customizer, command-line export,
debug reports, Perl-generated slicer guides, and variable layer height.

---

## 1. Quick start

1. Open `MasterBuilder.scad` in OpenSCAD (File → Open).
2. Press **F5** to preview (fast, no mesh). Press **F6** for full render.
3. Open the **Customizer** panel (Window → Customizer).
4. Pick an intent from **Build Selection**, set dimensions, press F6.
5. Export: File → Export → Export as STL (or 3MF for Bambu Studio).

---

## 2. Intent reference

| Intent | What it builds |
|--------|---------------|
| `Simple Tray` | Open tray, no lid |
| `Box` | Tray + snap lid |
| `Standalone Box` | Tray + glide (sliding) lid |
| `Flip Box` | Tray + C-clip hinge lid |
| `1-Day AM/PM Box` | Double-flip pillbox, 2 compartments |
| `7-Day Pill Box` | Single-flip pillbox, 7 columns (MON–SUN) |
| `14-Day AM/PM Box` | Double-flip pillbox, 7 columns × AM/PM |
| `Pillbox Full Set` | All pill box types in one platter |
| `Open Jar` | Cylindrical jar, no threads |
| `Threaded Jar` | Jar with threaded neck |
| `Jar with Lid` | Threaded jar + screw lid (dual-spawn W≠L) |
| `Standalone Box Grid` | Drop-in cartesian grid insert |
| `Standalone Jar Grid` | Drop-in radial grid insert for jars |
| `Grid Test` | All grid variants — for testing layout strings |
| `S4 Set` | Desiccant jar + spool jar + wedge box |

---

## 3. Customizer fields

### Dimensions
Set `part_width`, `part_length`, `part_height` in mm.  
`dimension_mode = "Total"` — values are outer dimensions.  
`dimension_mode = "Usable"` — values are interior; outer is computed by adding wall thickness.

### Grid layout string
`grid_layout` drives all internal divider geometry. See **GRID_LAYOUT_GUIDE.md** for syntax.
Leave empty for no grid.

### Debug
| Field | Effect |
|-------|--------|
| `debug_report = true` | Human-readable geometry report → console |
| `debug_payload = true` | Machine-parseable payload → console (for Perl) |

---

## 4. Command-line export

See **CLI_GUIDE.md** for full reference. Quick examples:

**Bash:**
```bash
openscad --hardwarnings \
  -D 'Part_To_Build="7-Day Pill Box"' \
  -D part_width=140 -D part_length=35 -D part_height=25 \
  -D 'Filament_Type="PETG"' \
  -o pillbox_7day.3mf MasterBuilder.scad
```

**PowerShell:**
```powershell
& "C:\Program Files\OpenSCAD\openscad.exe" --hardwarnings `
  "-DPart_To_Build=`"7-Day Pill Box`"" `
  -D part_width=140 -D part_length=35 -D part_height=25 `
  "-DFilament_Type=`"PETG`"" `
  -o pillbox_7day.3mf MasterBuilder.scad
```

---

## 5. Generating a slicer guide with Perl + Template Toolkit

### Prerequisites
```bash
cpanm Template YAML    # or: cpan Template
```

### Step 1 — Capture the payload
```bash
openscad -o /dev/null \
  -D 'Part_To_Build="Flip Box"' \
  -D part_width=140 -D part_length=35 -D part_height=25 \
  -D debug_payload=true \
  MasterBuilder.scad 2>&1 \
  | grep '^ECHO:' \
  | perl -pe 's/^ECHO: "(.+)"$/$1/' \
  | grep -E '^(META|VALUE|AUTO|SPAN|WARN)\|' \
  > build.psv
```

### Step 2 — Run the report generator

Save as `mastertray_report.pl`:

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Template;

# ── Parse payload ────────────────────────────────────────────────────────────
my (%meta, %intent, %slicer, @values, @autos, @spans, @warnings);

open my $fh, '<', $ARGV[0] // 'build.psv' or die $!;
while (<$fh>) {
    chomp;
    # OpenSCAD echoes multi-string concat as  "part1", "part2", "part3"
    # Flatten: strip quotes and commas, join into one string
    s/", "//g; s/^"//; s/"$//;

    my ($tag, $sec, $key, $val, $unit, $src, $formula, $flags)
        = split /\|/, $_, 8;
    $flags //= '';

    if ($tag eq 'META') {
        if    ($sec eq 'REPORT') { $meta{$key}   = $val }
        elsif ($sec eq 'INTENT') { $intent{$key} = $val }
        elsif ($sec eq 'SLICER') { $slicer{$key} = { value=>$val, unit=>$unit,
                                                      src=>$src, note=>$flags } }
    }
    elsif ($tag eq 'VALUE') { push @values, _rec($sec,$key,$val,$unit,$src,$formula,$flags) }
    elsif ($tag eq 'AUTO')  { push @autos,  _rec($sec,$key,$val,$unit,$src,$formula,$flags) }
    elsif ($tag eq 'SPAN')  { push @spans,  _rec($sec,$key,$val,$unit,$src,$formula,$flags) }
    elsif ($tag eq 'WARN')  { push @warnings,_rec($sec,$key,$val,$unit,$src,$formula,$flags) }
}
close $fh;

# ── Build variable-layer zones ───────────────────────────────────────────────
my @vl_zones = _vl_zones(\%meta, \%intent, \%slicer);

# ── Slicer general settings ──────────────────────────────────────────────────
my %general = _general_settings(\%meta, \%intent, \%slicer);

# ── Template ─────────────────────────────────────────────────────────────────
my $tt = Template->new({ INCLUDE_PATH => '.', ENCODING => 'utf8' });
$tt->process('slicer_report.tt2', {
    meta     => \%meta,
    intent   => \%intent,
    slicer   => \%slicer,
    values   => \@values,
    autos    => \@autos,
    spans    => \@spans,
    warnings => \@warnings,
    vl_zones => \@vl_zones,
    general  => \%general,
}) or die $tt->error;

# ── Helpers ───────────────────────────────────────────────────────────────────
sub _rec {
    my ($sec,$key,$val,$unit,$src,$formula,$flags) = @_;
    my %f = map { split /=/, $_, 2 } grep { /=/ } split /;/, $flags;
    return { sec=>$sec, key=>$key, value=>$val, unit=>$unit,
             src=>$src, formula=>$formula, flags=>$flags, flag_map=>\%f };
}

sub _vl_zones {
    my ($meta, $intent, $slicer) = @_;
    my $lh      = $meta->{layer_h}    // 0.28;
    my $z0      = 0;
    my $z_floor = $slicer->{z_floor_end}{value} // 2.0;
    my $z_mech  = $slicer->{z_mech_start}{value} // ($slicer->{z_top}{value} - 4);
    my $z_top   = $slicer->{z_top}{value}   // 20;
    my $lh_f    = $slicer->{lh_floor}{value} // 0.16;
    my $lh_b    = $slicer->{lh_body}{value}  // $lh;
    my $lh_m    = $slicer->{lh_mech}{value}  // 0.16;

    my $mech_label = $intent->{has_flip}    ? 'Hinge + latch zone'     :
                     $intent->{has_glide}   ? 'Groove + ball-catch zone':
                     $intent->{has_threads} ? 'Thread zone'            :
                     'Top closure zone';

    my @zones;
    push @zones, { name=>'Floor',    z_min=>$z0,      z_max=>$z_floor,
                   lh=>$lh_f, reason=>'Maximum layer bond — structural floor' };
    push @zones, { name=>'Body',     z_min=>$z_floor, z_max=>$z_mech,
                   lh=>$lh_b, reason=>'Fast bulk printing' }
        if $z_mech > $z_floor + 0.5;
    push @zones, { name=>$mech_label, z_min=>$z_mech, z_max=>$z_top,
                   lh=>$lh_m, reason=>'Fine layers for mechanism accuracy and fit' };

    # Lid gets its own recommendation (printed separately, face-down)
    if ($intent->{has_lid}) {
        my $sl = $slicer->{z_floor_end}{value} // 2.0;  # sl ≈ sf for most lids
        my $lh_lid = $slicer->{lh_lid_face}{value} // 0.12;
        push @zones, { name=>'Lid — face (printed face-down)',
                       z_min=>0, z_max=>$sl,
                       lh=>$lh_lid,
                       reason=>'Finest layers for visible top surface quality' };
    }
    return @zones;
}

sub _general_settings {
    my ($meta, $intent, $slicer) = @_;
    my $lh  = $meta->{layer_h}    // 0.28;
    my $noz = $meta->{nozzle_d}   // 0.4;    # from VALUE records; re-read below
    my $wl  = $meta->{wall_loops} // 2;
    my $fil = $meta->{material}   // 'PETG';

    # Material-specific base settings
    my %mat = (
        PETG => { temp=>235, bed=>70,  fan=>30,  retract=>0.8, speed_first=>20 },
        PLA  => { temp=>220, bed=>60,  fan=>100, retract=>0.6, speed_first=>20 },
        TPU  => { temp=>230, bed=>45,  fan=>30,  retract=>1.0, speed_first=>15 },
        ABS  => { temp=>250, bed=>100, fan=>10,  retract=>1.0, speed_first=>15 },
    );
    my $m = $mat{$fil} // $mat{PETG};

    return (
        layer_height    => $lh,
        first_layer_h   => 0.20,
        wall_loops      => $wl,
        top_layers       => int(0.8 / $lh + 0.5),   # ~0.8mm top shell
        bottom_layers    => int(0.8 / $lh + 0.5),
        infill_density   => 15,
        infill_pattern   => 'grid',
        supports         => 'none',         # all geometry is support-free
        brim             => $intent->{is_jar} ? 3 : 0,
        nozzle_temp      => $m->{temp},
        bed_temp         => $m->{bed},
        fan_speed        => $m->{fan},
        retract_dist     => $m->{retract},
        first_layer_speed=> $m->{speed_first},
    );
}
```

### Step 3 — TT2 template (`slicer_report.tt2`)

```
# [% meta.intent %] — Slicer Guide
Generated from MasterTray [% meta.builder_ver %]
Material: [% meta.material %] · Fit: [% meta.fit_profile %]
Box: [% meta.w // '' %] × [% meta.l // '' %] × [% meta.h // '' %] mm

---
## General Print Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Nozzle temperature | [% general.nozzle_temp %] °C | [% meta.material %] baseline |
| Bed temperature | [% general.bed_temp %] °C | |
| Layer height | [% general.layer_height %] mm | User-configured |
| First layer height | [% general.first_layer_h %] mm | Improves bed adhesion |
| Wall loops | [% general.wall_loops %] | Must match OpenSCAD Wall Loops |
| Top layers | [% general.top_layers %] | ≈ 0.8 mm shell |
| Bottom layers | [% general.bottom_layers %] | ≈ 0.8 mm shell |
| Infill | [% general.infill_density %]% [% general.infill_pattern %] | |
| Supports | [% general.supports %] | All geometry is support-free |
[% IF general.brim > 0 -%]
| Brim | [% general.brim %] lines | Recommended for jars |
[% END -%]
| Fan speed | [% general.fan_speed %]% | |
| Retraction | [% general.retract_dist %] mm | |
| First layer speed | [% general.first_layer_speed %] mm/s | |

---
## Variable Layer Height

Enable in slicer: **Variable Layer Height** mode.
Apply these zones from the bottom of the model upward.
[% IF intent.has_lid %]
**Note:** The lid is a separate object — apply the Lid zone to the lid file only.
[% END %]

| Zone | Z start | Z end | Layer height | Why |
|------|---------|-------|-------------|-----|
[% FOREACH z IN vl_zones -%]
| [% z.name %] | [% z.z_min %] mm | [% z.z_max %] mm | **[% z.lh %] mm** | [% z.reason %] |
[% END %]

### Bambu Studio — Setting variable layer height

1. Load your `.3mf` or `.stl` in Bambu Studio.
2. Select the model on the build plate.
3. Click **Variable Layer Height** (the paint-roller icon in the top toolbar).
4. In the panel on the right, click **Manual** tab.
5. For each zone above, click **Add range**, enter Z start/end, set layer height.
6. Click **Apply** when all zones are entered.
7. Slice as normal.

### PrusaSlicer — Setting variable layer height

1. Load model, select it.
2. Click **Variable Layer Height** button (layer icon in left toolbar).
3. The height map opens. Click **Reset** to start clean.
4. Use the **Smooth** and **Fine** brushes, or click **Edit ranges** to type values.
5. Apply the Z ranges from the table above.

---
## Auto-Sized Values (no user configuration needed)

These are computed automatically — shown here for reference only.

| Parameter | Value | Formula | Affects |
|-----------|-------|---------|---------|
[% FOREACH item IN autos -%]
[% IF item.src == 'AUTOSIZE' || item.src == 'COMPUTED' -%]
| `[% item.key %]` | [% item.value %] [% item.unit %] | `[% item.formula %]` | [% item.flag_map.AFFECTS || item.flag_map.DRIVES || item.flag_map.NOTE || '' %] |
[% END -%]
[% END %]
[% IF warnings.size > 0 -%]
---
## ⚠ Warnings

[% FOREACH w IN warnings -%]
- **[% w.key %]**: [% w.formula %]
  → Action: [% w.flags.replace('.*\|','') %]
[% END -%]
[% END %]
[% IF spans.size > 0 -%]
---
## Grid Spans

| # | Definition | Position | Size | Height | Status |
|---|-----------|----------|------|--------|--------|
[% FOREACH s IN spans -%]
| [% loop.index + 1 %] | `[% s.value %]` | row [% s.flag_map.row || '?' %] col [% s.flag_map.col || '?' %] | [% s.flag_map.row_span || '?' %]r × [% s.flag_map.col_span || '?' %]c | [% s.flag_map.h_final || '?' %] mm | [% s.src %] |
[% END -%]
[% END %]
```

### Running it

```bash
# 1. Capture payload
openscad -o /dev/null \
  -D 'Part_To_Build="Flip Box"' \
  -D part_width=140 -D part_length=35 -D part_height=25 \
  -D debug_payload=true \
  MasterBuilder.scad 2>&1 \
  | perl -ne 'print "$1\n" if /^ECHO: "(.+)"$/' \
  | grep -E '^(META|VALUE|AUTO|SPAN|WARN)\|' \
  > build.psv

# 2. Generate report
perl mastertray_report.pl build.psv > slicer_guide.md

# 3. Convert to HTML/PDF (optional)
pandoc slicer_guide.md -o slicer_guide.html
pandoc slicer_guide.md -o slicer_guide.pdf
```

---

## 6. Variable layer height — rationale

### Why bother?

FDM part quality is a trade-off between print speed and dimensional accuracy.
For pill organizers, three zones have conflicting needs:

| Zone | Priority | Optimal layer height |
|------|----------|---------------------|
| Floor | Bond strength | 0.12–0.16 mm |
| Walls (bulk) | Print speed | Your normal layer height |
| Hinge / groove / threads | Dimensional accuracy | 0.12–0.16 mm |
| Lid face | Surface finish (visible) | 0.12 mm |

**The hinge zone for a flip box** spans roughly `axle_z - clip_od` to `h`.
The C-clip bore is `hinge_d + 2×cclip_tol` in diameter. At 0.28mm layers this bore
is ~0.14mm oversized per side from layer stepping. At 0.16mm layers the error drops
to ~0.08mm — within the designed tolerance.

**The thread zone for a jar lid** benefits most from fine layers:
thread pitch is typically 2mm; finer layers preserve the helical flank angle.

### How the Perl script derives zones

The payload emits `META|SLICER|z_mech_start` which the script uses as the
boundary between bulk and fine printing:

| Intent type | `z_mech_start` formula |
|-------------|----------------------|
| Flip box | `axle_z - clip_od` |
| Glide box | `groove_z` |
| Threaded jar | `cyl_wall_h` |
| Snap / plain | `h - sl × 3` |

These values change automatically when you change dimensions or nozzle — the
generated slicer guide is always in sync with the model.

---

## 7. LESSONS.md

For architectural decisions, hard-won rules, and the "why" behind the code,
see **LESSONS.md**.

## 8. Grid layout syntax

See **GRID_LAYOUT_GUIDE.md**.

## 9. Full CLI reference

See **CLI_GUIDE.md**.
