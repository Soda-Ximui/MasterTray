# MasterTray — OpenSCAD Command-Line Guide

Export STL, run debug reports, and batch-build parts without opening the GUI.

---

## OpenSCAD executable

| Platform | Path |
|----------|------|
| Windows | `"C:\Program Files\OpenSCAD\openscad.exe"` |
| macOS | `/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD` |
| Linux | `openscad` (if in PATH) or `/usr/bin/openscad` |

---

## Basic export — set intent and dimensions

```bash
openscad -o output.stl \
  -D 'Part_To_Build="7-Day Pill Box"' \
  -D 'part_width=140' \
  -D 'part_length=35' \
  -D 'part_height=25' \
  MasterBuilder.scad
```

`-D 'VAR=value'` overrides any Customizer variable before rendering.  
String values require **inner quotes**: `-D 'Part_To_Build="Flip Box"'`  
Numeric values need no quotes: `-D 'part_width=100'`

On **Windows PowerShell**, escape the inner quotes:

```powershell
& "C:\Program Files\OpenSCAD\openscad.exe" -o output.stl `
  "-DPart_To_Build=`"7-Day Pill Box`"" `
  -D part_width=140 `
  -D part_length=35 `
  -D part_height=25 `
  MasterBuilder.scad
```

---

## Common Customizer variables

### Build selection
| Variable | Example | Notes |
|----------|---------|-------|
| `Part_To_Build` | `"7-Day Pill Box"` | Must match the dropdown label exactly |
| `jar_shape` | `"Circle"` / `"Hexa"` | Jar polygon shape |

### Dimensions
| Variable | Example | Notes |
|----------|---------|-------|
| `part_width` | `140` | mm |
| `part_length` | `35` | mm |
| `part_height` | `25` | mm |
| `dimension_mode` | `"Total"` / `"Usable"` | Total = outer, Usable = inner |

### Printer / slicer
| Variable | Example | Notes |
|----------|---------|-------|
| `Nozzle_Diameter` | `0.4` | `0.2 / 0.4 / 0.6 / 0.8` |
| `Layer_Height` | `0.28` | `0.12 / 0.16 / 0.20 / 0.24 / 0.28` |
| `Wall_Loops` | `2` | integer |

### Material & fit
| Variable | Example | Notes |
|----------|---------|-------|
| `Filament_Type` | `"PETG"` | `"PLA"` / `"PETG"` / `"TPU"` / `"ABS"` |
| `Mechanical_Fit` | `"Standard"` | `"Tighter"` / `"Tight"` / `"Standard"` / `"Loose"` / `"Looser"` |

### Grid
| Variable | Example | Notes |
|----------|---------|-------|
| `grid_type` | `"Built-in"` | `"Built-in"` / `"Drop-in"` / `"None"` |
| `grid_layout` | `"7x5 R3 C15%"` | See GRID_LAYOUT_GUIDE.md |
| `grid_has_base` | `false` | Drop-in base plate |

### Debug
| Variable | Example | Notes |
|----------|---------|-------|
| `debug_report` | `true` | Human-readable report to console |
| `debug_payload` | `true` | Machine-parseable payload for Perl |

---

## Export formats

| Extension | Format | Use |
|-----------|--------|-----|
| `.stl` | STL (ASCII) | Standard slicer input |
| `.3mf` | 3MF | Preferred for Bambu Studio / PrusaSlicer |
| `.csg` | CSG | Geometry check without full render (fast) |
| `.png` | PNG image | Preview thumbnail |

Force a specific format with `--export-format`:

```bash
openscad --export-format 3mf -o output.3mf \
  -D 'Part_To_Build="Simple Tray"' MasterBuilder.scad
```

---

## Strict warning mode (recommended for scripting)

`--hardwarnings` promotes all warnings to errors and sets exit code 1 on failure.
Use this in CI or batch scripts to catch geometry problems:

```bash
openscad --hardwarnings -o output.stl \
  -D 'Part_To_Build="Flip Box"' MasterBuilder.scad
echo "Exit: $?"
```

---

## Extracting a debug report via shell

### Bash — human-readable report only
```bash
openscad -o /dev/null \
  -D 'Part_To_Build="Standalone Box"' \
  -D debug_report=true \
  MasterBuilder.scad 2>&1 | grep '^ECHO:' | sed 's/^ECHO: "//; s/"$//'
```

### Bash — extract machine payload (strip ECHO wrapper)
```bash
openscad -o /dev/null \
  -D 'Part_To_Build="Standalone Box"' \
  -D debug_payload=true \
  MasterBuilder.scad 2>&1 \
  | grep '^ECHO:' \
  | sed 's/^ECHO: "\(.*\)"$/\1/' \
  | grep -E '^(META|VALUE|AUTO|SPAN|WARN)\|' \
  > build_report.psv
```

`build_report.psv` is a pipe-separated-values file, one record per line.

### Windows PowerShell
```powershell
$lines = & "C:\Program Files\OpenSCAD\openscad.exe" `
    -o NUL `
    "-DPart_To_Build=`"Standalone Box`"" `
    -D debug_payload=true `
    MasterBuilder.scad 2>&1

$records = $lines |
    Where-Object { $_ -match '^ECHO: "(.+)"$' } |
    ForEach-Object { $Matches[1] } |
    Where-Object { $_ -match '^(META|VALUE|AUTO|SPAN|WARN)\|' }

$records | Out-File build_report.psv -Encoding utf8
```

---

## Perl parsing skeleton

```perl
#!/usr/bin/env perl
use strict;
use warnings;

# Run OpenSCAD and capture payload
my @lines = `openscad -o /dev/null -D 'Part_To_Build="$ARGV[0]"' \\
             -D debug_payload=true MasterBuilder.scad 2>&1`;

my %data;   # section => [ {tag, key, value, unit, src, formula, flags}, ... ]

for my $line (@lines) {
    chomp $line;
    next unless $line =~ /^ECHO: "(.+)"$/;
    my $rec = $1;
    my ($tag, $sec, $key, $val, $unit, $src, $formula, $flags)
        = split /\|/, $rec, 8;
    next unless $tag =~ /^(META|VALUE|AUTO|SPAN|WARN)$/;

    push @{ $data{$sec} }, {
        tag     => $tag,
        key     => $key,
        value   => $val,
        unit    => $unit,
        src     => $src,
        formula => $formula,
        flags   => $flags // '',
    };
}

# Hand off to Template Toolkit
use Template;
my $tt = Template->new({ INCLUDE_PATH => './templates' });
$tt->process('report.tt2', { data => \%data })
    or die $tt->error();
```

---

## Template Toolkit example (`templates/report.tt2`)

```
# MasterTray Build Report

## Auto-Sized Values (no user action needed)

| Parameter | Value | Formula | Affects |
|-----------|-------|---------|---------|
[% FOREACH item IN data.GLIDE -%]
[% IF item.src == 'AUTOSIZE' || item.src == 'COMPUTED' -%]
| [% item.key %] | [% item.value %] [% item.unit %] | `[% item.formula %]` | [% item.flags.replace('AFFECTS=','').replace(';',' ') %] |
[% END -%]
[% END %]

## Warnings

[% FOREACH sec IN data.keys -%]
[% FOREACH item IN data.$sec -%]
[% IF item.tag == 'WARN' -%]
- **[% item.key %]**: [% item.formula %] → [% item.flags %]
[% END -%]
[% END -%]
[% END %]
```

---

## Batch-export all pill box intents

```bash
#!/usr/bin/env bash
OPENSCAD="openscad"
SCAD="MasterBuilder.scad"
W=140  L=35  H=25

INTENTS=(
  "1-Day AM/PM Box"
  "7-Day Pill Box"
  "14-Day AM/PM Box"
  "Pillbox Full Set"
)

for intent in "${INTENTS[@]}"; do
  safe=$(echo "$intent" | tr ' /' '_-')
  echo "Exporting: $intent → ${safe}.stl"
  "$OPENSCAD" --hardwarnings \
    -D "Part_To_Build=\"$intent\"" \
    -D "part_width=$W" \
    -D "part_length=$L" \
    -D "part_height=$H" \
    -D 'Filament_Type="PETG"' \
    -o "${safe}.stl" "$SCAD"
done
```

---

## Tips

- Use `.csg` output for fast geometry checks without full mesh computation — much faster than `.stl` for validation.
- `Grid Test` intent is useful for batch-checking all grid variants in one render.
- Pipe stdout through `grep ECHO` to see only `echo()` debug output without the progress messages.
- For Bambu Studio, prefer `.3mf` — it preserves colour assignments and slicer profile hints.
