#!/usr/bin/env perl
# ──────────────────────────────────────────────────────────────────────────────
# build.pl — MasterTray build queue runner
# Tested on Strawberry Perl 5.42 / Windows 11
#
# Usage:
#   perl build.pl queue.yaml
#   perl build.pl queue.yaml --dry-run                # show commands only
#   perl build.pl queue.yaml --only "Box"             # single intent by name
#   perl build.pl queue.yaml --out ./MySTL            # override output dir
#   perl build.pl queue.yaml --output-dir D:\Prints   # same, long form
#   perl build.pl queue.yaml --verbose
#
# Output dir precedence:  --out / --output-dir CLI  >  output.dir in YAML  >  STL/
#
# Queue file format: see queue.example.yaml
#
# Required modules — missing ones are installed automatically via cpanm/cpan:
#   YAML::Tiny, JSON::PP, File::Temp  — bundled with Strawberry Perl
#   IPC::Open3, File::Path, Cwd etc.  — Perl core
#   Template (Template Toolkit)        — auto-installed if absent
# ──────────────────────────────────────────────────────────────────────────────
use strict;
use warnings;
use 5.014;

use YAML::Tiny    qw(LoadFile);
use IPC::Open3    qw(open3);
use Symbol        qw(gensym);
use File::Path    qw(make_path);
use File::Basename qw(dirname basename);
use Cwd           qw(abs_path getcwd);
use Getopt::Long  qw(GetOptions);
use POSIX         qw(strftime);
use JSON::PP      qw(encode_json);       # core since Perl 5.14, in Strawberry
use File::Temp    qw(tempfile tempdir);

# ── Auto-install missing modules ──────────────────────────────────────────────
# Uses cpanm (preferred) or cpan, both bundled with Strawberry Perl.
BEGIN {
    my @needed = qw(YAML::Tiny Template JSON::PP File::Temp);
    my @missing = grep { !eval "require $_; 1" } @needed;
    if (@missing) {
        print "Installing missing modules: @missing\n";
        my $installer = do {
            my $cpanm = `where cpanm 2>nul`; chomp $cpanm;
            $cpanm =~ /\S/ ? 'cpanm' : 'cpan -i';
        };
        for my $mod (@missing) {
            print "  > $installer $mod\n";
            system("$installer $mod") == 0
                or warn "  [WARN] Install may have failed for $mod — continuing\n";
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# DATA CONSTANTS — declared before the main loop so they are initialised
# when build_flags() is called.  (my-variable initialisation runs top-to-bottom
# at runtime; sub bodies are hoisted but their closures over these variables
# see whatever value the variable has at call time, not compile time.)
# ══════════════════════════════════════════════════════════════════════════════

# OpenSCAD variables whose values must be quoted as strings: VAR="value"
my %STR_VARS = map { $_ => 1 } qw(
    Part_To_Build Filament_Type Mechanical_Fit mesh_pattern
    dimension_mode jar_shape grid_layout modify_wall target_wall
    Glide_Direction Glide_Snap plaque_target clip_type
);

# Map: queue YAML key  →  OpenSCAD Customizer variable name
# Valid intents (Part_To_Build): Box | Pillbox Full Set | Lid | Simple Tray |
#   Jar | Threaded Jar | S4 Jar | Spool Jar | S4 Wedge | S4 Set |
#   Plaque | Grid | Grid Test | Lid Testing
my %FIELD_MAP = (
    # Core
    intent              => 'Part_To_Build',
    width               => 'part_width',
    length              => 'part_length',
    height              => 'part_height',
    dimension_mode      => 'dimension_mode',      # Total | Usable
    # Printer
    material            => 'Filament_Type',        # PLA | PETG | TPU | ABS
    fit_profile         => 'Mechanical_Fit',       # Tighter|Tight|Standard|Loose|Looser
    nozzle              => 'Nozzle_Diameter',
    layer_height        => 'Layer_Height',
    wall_loops          => 'Wall_Loops',
    # Mesh aesthetics
    mesh_pattern        => 'mesh_pattern',         # Honeycomb|Teardrop|Slotted|Circle|Square|Diamond|None
    mesh_hole_size      => 'mesh_hole_size',
    mesh_hole_spacing   => 'mesh_hole_spacing',
    strut_wall          => 'strut_wall_perc',
    strut_floor         => 'strut_floor_perc',
    strut_lid           => 'strut_lid_perc',
    # Thickness overrides
    wall_thickness      => 'wall_thickness',
    floor_thickness     => 'floor_thickness',
    lid_thickness       => 'lid_thickness',
    divider_thickness   => 'divider_thickness',
    # Box lid type selectors (Box intent — each generates a box+lid pair)
    snap_external       => 'Snap_External',        # true|false
    snap_internal       => 'Snap_Internal',
    glide_external      => 'Glide_External',
    glide_internal      => 'Glide_Internal',
    flip_single         => 'Flip_Single',
    flip_double         => 'Flip_Double',
    glide_direction     => 'Glide_Direction',      # H | V
    glide_snap          => 'Glide_Snap',           # Ball | Tab
    # Jar
    jar_shape           => 'jar_shape',            # Circle|Quad|Hexa|Octa|Dodeca
    jar_with_lid        => 'Jar_Lid',              # true = threaded lid
    # Simple Tray stackable variants
    nesting             => 'Nesting',
    peg                 => 'Peg',
    # Grid
    grid_layout         => 'grid_layout',
    # Plaque
    plaque_target       => 'plaque_target',        # Wall | Lid | Lid_Peg
    clip_type           => 'clip_type',            # Vertical | Horizontal
    plaque_w            => 'plaque_w',
    plaque_h            => 'plaque_h',
    clip_h              => 'clip_h',
    # Wall modifications
    modify_wall         => 'modify_wall',          # None|Dropped|50%|25%
    target_wall         => 'target_wall',          # All Walls|Front|Back|Left|Right
    # Geometry overrides
    chamfer_size        => 'chamfer_size',
    corner_radius       => 'corner_radius',
);

# Template is now installed (or was already). Load it.
my $have_tt = eval { require Template; Template->import(); 1 };

# ── CLI flags ─────────────────────────────────────────────────────────────────
# --output-dir / --out : override the output directory from queue YAML.
#   Relative paths are resolved from the current working directory.
#   Takes priority over output.dir in the YAML file.
my ($dry_run, $only_intent, $verbose, $cli_out_dir);
GetOptions(
    'dry-run'      => \$dry_run,
    'only=s'       => \$only_intent,
    'verbose'      => \$verbose,
    'output-dir=s' => \$cli_out_dir,
    'out=s'        => \$cli_out_dir,    # short alias
) or die "Usage: $0 queue.yaml [--dry-run] [--only 'intent'] [--output-dir DIR]\n";

my $queue_file = shift @ARGV
    or die "Usage: $0 queue.yaml [--dry-run] [--only 'intent']\n";
$queue_file = abs_path($queue_file);
die "Queue file not found: $queue_file\n" unless -f $queue_file;

# ── Load queue ────────────────────────────────────────────────────────────────
my $q        = LoadFile($queue_file);
my $tools    = $q->{tools}    // {};
my $out_cfg  = $q->{output}   // {};
my $defaults = $q->{defaults} // {};
my $builds   = $q->{builds}   // [];

my $base      = dirname($queue_file);
my $openscad  = $tools->{openscad}    // 'openscad';
my $scad_file = _resolve($tools->{scad_file} // 'MasterBuilder.scad', $base);

# Output dir precedence: --output-dir CLI  >  output.dir in YAML  >  STL/
my $out_dir = defined $cli_out_dir
    ? _resolve($cli_out_dir, getcwd())          # CLI arg: relative to CWD
    : _resolve($out_cfg->{dir} // 'STL', $base); # YAML / default: relative to queue file
my $format    = $out_cfg->{format}           // 'stl';
my $do_report = $out_cfg->{generate_report}  // 1;
my $do_slicer = $out_cfg->{generate_slicer}  // 1;
my $save_psv  = _yaml_bool($out_cfg->{save_payload},  0);

die "MasterBuilder.scad not found: $scad_file\n" unless -f $scad_file;
make_path($out_dir) unless -d $out_dir;

die "Check for name collision with file. Unable to create output directory: $out_dir\n" unless -d $out_dir;

# ── Template engine ───────────────────────────────────────────────────────────
my $tt;
if ($have_tt) {
    $tt = Template->new({
        INTERPOLATE => 0,
        EVAL_PERL   => 0,
        ENCODING    => 'UTF-8',
    }) or die Template->error;
}

# ── Run each build ────────────────────────────────────────────────────────────
my ($pass, $fail) = (0, 0);
my $timestamp = strftime('%Y-%m-%d %H:%M', localtime);

for my $spec (@$builds) {
    my %b = (%$defaults, %$spec);   # defaults < build (build wins)
    next if defined $only_intent && $b{intent} ne $only_intent;

    my $name = build_name(\%b);
    printf "\n[BUILD] %s\n", $name;
    printf "        %s  %s×%s×%s mm  %s  nozzle=%s  lh=%s\n",
        $b{intent}//'?', $b{width}//'?', $b{length}//'?', $b{height}//'?',
        $b{material}//'?', $b{nozzle}//'?', $b{layer_height}//'?';

    my $out_base   = "$out_dir/$name";
    my $model_out  = "$out_base.$format";
    my $report_out = "$out_base - Report.md";
    my $slicer_out = "$out_base - Slicer.md";
    my $psv_out    = "$out_base.psv";

    # ── 1. Write JSON parameter file (avoids Windows -D quoting entirely) ────
    my $params_file = $dry_run ? '' : write_params_file(\%b);

    # ── 2. Export model ───────────────────────────────────────────────────────
    my $ok = run_openscad($openscad, $scad_file, $model_out, $params_file,
                          $dry_run, $verbose);
    unlink $params_file if $params_file && !$dry_run;
    unless ($ok || $dry_run) {
        warn "  [FAIL] OpenSCAD export returned error\n";
        $fail++;
        next;
    }
    print "  [OK]   $model_out\n" unless $dry_run;
    print "  [DRY]  would write: $model_out\n" if $dry_run;

    # ── 3. Capture debug payload ──────────────────────────────────────────────
    my $p2_file = $dry_run ? '' : write_params_file(\%b);
    my $payload_text = $dry_run ? ''
        : capture_payload($openscad, $scad_file, $p2_file, $verbose);
    unlink $p2_file if $p2_file && !$dry_run;
    my %payload = parse_payload($payload_text);

    if ($save_psv && !$dry_run) {
        _write_file($psv_out, $payload_text);
        print "  [OK]   $psv_out\n";
    }

    # ── 3. Derive slicer data from payload ────────────────────────────────────
    my @vl_zones = vl_zones(\%payload);
    my %gen      = general_settings(\%b, \%payload);

    my %tmpl_vars = (
        name      => $name,
        spec      => \%b,
        format    => $format,
        payload   => \%payload,
        vl_zones  => \@vl_zones,
        general   => \%gen,
        generated => $timestamp,
    );

    # ── 4. Reports ────────────────────────────────────────────────────────────
    if ($do_report && !$dry_run) {
        if ($tt) {
            render($tt, _tmpl_report(), \%tmpl_vars, $report_out);
            print "  [OK]   $report_out\n";
        } else {
            warn "  [SKIP] Report (Template not installed)\n";
        }
    }
    if ($do_slicer && !$dry_run) {
        if ($tt) {
            render($tt, _tmpl_slicer(), \%tmpl_vars, $slicer_out);
            print "  [OK]   $slicer_out\n";
        } else {
            warn "  [SKIP] Slicer guide (Template not installed)\n";
        }
    }
    $pass++;
}

printf "\n── Summary: %d built, %d failed ──\n", $pass, $fail;
exit($fail ? 1 : 0);

# ══════════════════════════════════════════════════════════════════════════════
# FILENAME GENERATION
# ══════════════════════════════════════════════════════════════════════════════

# "Jar with Lid - 40 x 120 x 50 - PETG 0.6 0.28 Teardrop 1.8 1.6 20 x 25 x 10"
sub build_name {
    my ($b) = @_;

    my $dims   = join(' x ', map { _n($_) } @{$b}{qw(width length height)});
    my $mat    = $b->{material}          // 'PETG';
    my $noz    = _n($b->{nozzle}         // 0.4);
    my $lh     = _n($b->{layer_height}   // 0.28);
    my $pat    = $b->{mesh_pattern}      // 'Teardrop';
    my $hole   = _n($b->{mesh_hole_size} // 0);
    my $div_t  = _n($b->{divider_thickness} // 1.2);
    my $struts = join(' x ',
        map { _n($b->{$_} // 100) } qw(strut_wall strut_floor strut_lid));

    my $name = "$b->{intent} - $dims - $mat $noz $lh $pat $hole $div_t $struts";

    # Append non-default discriminators
    my $fit = $b->{fit_profile} // 'Standard';
    $name .= " $fit"                unless $fit eq 'Standard';
    my $jar = $b->{jar_shape}   // 'Circle';
    $name .= " $jar"                unless $jar eq 'Circle';
    my $gl  = $b->{grid_layout} // '';
    $name .= " [$gl]"               if $gl =~ /\S/;

    # Strip chars illegal on Windows/macOS: < > : " / \ | ? *
    $name =~ s{[<>:"/\\|?*\x00-\x1f]}{}g;
    $name =~ s/\s{2,}/ /g;
    $name =~ s/^\s+|\s+$//g;
    return $name;
}

# Format number cleanly: strip trailing zeros  (0.4000 → 0.4, 2.0000 → 2)
sub _n {
    my ($v) = @_;
    return 0 unless defined $v && $v ne '';
    my $s = sprintf('%.4f', $v + 0);
    $s =~ s/\.?0+$//;
    return $s;
}

# ══════════════════════════════════════════════════════════════════════════════
# OPENSCAD PARAMETER FILE
# OpenSCAD's -p file.json -P preset avoids Windows command-line quoting
# entirely: JSON handles string values with spaces and special characters
# reliably through the OS file API, bypassing CreateProcess/shell escaping.
# ══════════════════════════════════════════════════════════════════════════════
sub write_params_file {
    my ($b) = @_;
    my %params;
    for my $qkey (sort keys %FIELD_MAP) {
        next unless exists $b->{$qkey} && defined $b->{$qkey};
        my $var = $FIELD_MAP{$qkey};
        my $val = $b->{$qkey};
        if ($STR_VARS{$var}) {
            $params{$var} = "$val";               # JSON string
        } elsif (lc($val) eq 'true') {
            $params{$var} = JSON::PP::true;        # JSON boolean
        } elsif (lc($val) eq 'false') {
            $params{$var} = JSON::PP::false;
        } elsif ($val =~ /^-?[\d.]+$/) {
            $params{$var} = $val + 0;             # JSON number
        } else {
            $params{$var} = "$val";
        }
    }
    my $json = encode_json({
        fileFormatVersion => "1",
        parameterSets     => { build => \%params },
    });
    my ($fh, $fname) = tempfile('mastertray_XXXXXX', SUFFIX => '.json',
                                TMPDIR => 1, UNLINK => 0);
    print $fh $json;
    close $fh;
    return $fname;
}

# ══════════════════════════════════════════════════════════════════════════════
# OPENSCAD EXECUTION
# system(@array) bypasses the shell on Windows — each element → one argument.
# IPC::Open3 used for payload capture (handles stderr on Win32).
# ══════════════════════════════════════════════════════════════════════════════

sub run_openscad {
    my ($bin, $scad, $out, $params_file, $dry, $verbose) = @_;
    my @cmd = ($bin, '--hardwarnings',
               '-p', $params_file, '-P', 'build',
               '-o', $out, $scad);
    _show_cmd(\@cmd) if $verbose || $dry;
    return 1 if $dry;
    my $rc = system(@cmd);
    warn "  [WARN] OpenSCAD exit code: " . ($rc >> 8) . "\n" if $rc != 0;
    return $rc == 0;
}

sub capture_payload {
    my ($bin, $scad, $params_file, $verbose) = @_;
    # Write both stdout and stderr to a temp file via the shell (2>&1).
    # This is reliable on Windows: IPC::Open3 pipe reads can silently return
    # nothing when the child finishes before we drain both handles.
    # All complex string args live in the JSON params file — remaining args
    # (paths, flags) contain no embedded quotes, so "..." quoting suffices.
    # Temp file for capturing OpenSCAD output
    # File::Temp is core; use explicit TEMPLATE + DIR to avoid TMPDIR quirks
    require File::Temp;
    my $tmpdir  = File::Temp::tempdir(CLEANUP => 0);
    my $outfile = "$tmpdir/mastertray_payload_$$.log";
    # Create the file so the path is valid before we redirect into it
    open my $pre, '>', $outfile or do { warn "  [WARN] Cannot create payload tmp: $!\n"; return '' };
    close $pre;

    # Use a .csg temp file — OpenSCAD requires a known extension to infer format.
    # NUL/dev/null has no extension and is rejected. CSG is fast (no mesh).
    my $csg_out = "$tmpdir/mastertray_payload_$$.csg";
    my @args = ('--hardwarnings',
                '-p', $params_file, '-P', 'build',
                '-D', 'debug_payload=true',
                '-o', $csg_out, $scad);

    # $s avoids conflict with Perl's sort-global $a/$b
    my $q   = sub { my $s = shift; $s =~ /\s/ ? qq("$s") : $s };
    my $cmd = join(' ', $q->($bin), map { $q->($_) } @args)
              . ' > ' . $q->($outfile) . ' 2>&1';
    print "  PAYLOAD CMD: $cmd\n" if $verbose;
    system($cmd);

    open my $fh, '<', $outfile or do { unlink $outfile; unlink $csg_out; return '' };
    my $text = do { local $/; <$fh> };
    close $fh;
    unlink $outfile;
    unlink $csg_out;
    return $text // '';
}

# ══════════════════════════════════════════════════════════════════════════════
# PAYLOAD PARSING
# ══════════════════════════════════════════════════════════════════════════════

sub parse_payload {
    my ($text) = @_;
    my (%meta, %intent_flags, %slicer, @values, @autos, @spans, @warns);

    for my $line (split /\r?\n/, $text) {
        # Strip ECHO wrapper: ECHO: "field1", "field2" → field1field2
        next unless $line =~ /^ECHO: "(.+)"$/;
        (my $rec = $1) =~ s/", "//g;   # flatten OpenSCAD concat segments

        my ($tag, $sec, $key, $val, $unit, $src, $formula, $flags)
            = split /\|/, $rec, 8;
        next unless defined $tag;
        $flags //= '';

        my %flag_map = map { split /=/, $_, 2 } grep { /=/ } split /;/, $flags;
        my $r = {
            tag      => $tag,
            sec      => $sec      // '',
            key      => $key      // '',
            value    => $val      // '',
            unit     => $unit     // '',
            src      => $src      // '',
            formula  => $formula  // '',
            flags    => $flags,
            flag_map => \%flag_map,
        };

        if    ($tag eq 'META' && ($sec//'') eq 'REPORT') { $meta{$key}         = $val }
        elsif ($tag eq 'META' && ($sec//'') eq 'INTENT') { $intent_flags{$key} = $val }
        elsif ($tag eq 'META' && ($sec//'') eq 'SLICER') { $slicer{$key}       = $r   }
        elsif ($tag eq 'VALUE')                           { push @values,  $r          }
        elsif ($tag eq 'AUTO')                            { push @autos,   $r          }
        elsif ($tag eq 'SPAN')                            { push @spans,   $r          }
        elsif ($tag eq 'WARN')                            { push @warns,   $r          }
    }

    return (
        meta         => \%meta,
        intent_flags => \%intent_flags,
        slicer       => \%slicer,
        values       => \@values,
        autos        => \@autos,
        spans        => \@spans,
        warnings     => \@warns,
    );
}

# ══════════════════════════════════════════════════════════════════════════════
# SLICER DATA DERIVATION
# ══════════════════════════════════════════════════════════════════════════════

sub vl_zones {
    my ($p) = @_;
    my $sl  = $p->{slicer}       // {};
    my $inf = $p->{intent_flags} // {};

    my $z_floor = _sv($sl, 'z_floor_end',  2.0);
    my $z_mech  = _sv($sl, 'z_mech_start', 10.0);
    my $z_top   = _sv($sl, 'z_top',        20.0);
    my $lh_f    = _sv($sl, 'lh_floor',     0.16);
    my $lh_b    = _sv($sl, 'lh_body',      0.28);
    my $lh_m    = _sv($sl, 'lh_mech',      0.16);
    my $lh_lid  = _sv($sl, 'lh_lid_face',  0.12);

    my $mech_name = $inf->{has_flip}    ? 'Hinge + latch zone'
                  : $inf->{has_glide}   ? 'Groove + ball-catch zone'
                  : $inf->{has_threads} ? 'Thread zone'
                  :                       'Top closure zone';
    my @zones = (
        { name=>'Floor (bottom)',  z_min=>0,       z_max=>$z_floor,
          lh=>$lh_f, reason=>'Maximum layer bonding — structural floor' },
    );
    push @zones,
        { name=>'Body (bulk)', z_min=>$z_floor, z_max=>$z_mech,
          lh=>$lh_b, reason=>'Fast printing — bulk walls' }
        if $z_mech > $z_floor + 1.0;

    push @zones,
        { name=>$mech_name,    z_min=>$z_mech,  z_max=>$z_top,
          lh=>$lh_m, reason=>'Fine layers — mechanism accuracy and fit' };

    if ($inf->{has_lid}) {
        push @zones,
            { name=>'Lid face  (lid part only, printed face-down)',
              z_min=>0, z_max=>$z_floor,
              lh=>$lh_lid, reason=>'Finest layers — visible top surface' };
    }
    return @zones;
}

sub general_settings {
    my ($spec, $p) = @_;
    my $lh  = $spec->{layer_height} // 0.28;
    my $wl  = $spec->{wall_loops}   // 2;
    my $fil = $spec->{material}     // 'PETG';
    my $inf = $p->{intent_flags}    // {};

    my %mat = (
        PETG => { temp=>235, bed=>70,  fan=>30,  retract=>0.8, speed_wall=>60,  speed_first=>20 },
        PLA  => { temp=>220, bed=>60,  fan=>100, retract=>0.6, speed_wall=>80,  speed_first=>20 },
        TPU  => { temp=>230, bed=>45,  fan=>30,  retract=>1.0, speed_wall=>30,  speed_first=>15 },
        ABS  => { temp=>250, bed=>100, fan=>10,  retract=>1.0, speed_wall=>60,  speed_first=>15 },
    );
    my $m = $mat{$fil} // $mat{PETG};
    my $top = int(0.8 / $lh + 0.5);

    return (
        layer_height     => $lh,
        first_layer_h    => 0.20,
        wall_loops        => $wl,
        top_layers         => $top,
        bottom_layers      => $top,
        infill_density     => 15,
        infill_pattern     => 'grid',
        supports           => 'none',
        brim               => ($inf->{is_jar} ? 3 : 0),
        nozzle_temp        => $m->{temp},
        bed_temp           => $m->{bed},
        fan_speed          => $m->{fan},
        retract_dist       => $m->{retract},
        speed_wall         => $m->{speed_wall},
        first_layer_speed  => $m->{speed_first},
    );
}

# ══════════════════════════════════════════════════════════════════════════════
# TEMPLATE RENDERING
# ══════════════════════════════════════════════════════════════════════════════

sub render {
    my ($tt, $tmpl, $vars, $outfile) = @_;
    my $out = '';
    $tt->process(\$tmpl, $vars, \$out) or die "Template error: " . $tt->error . "\n";
    _write_file($outfile, $out);
}

# ══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ══════════════════════════════════════════════════════════════════════════════

# Resolve a path relative to a base directory
sub _resolve {
    my ($path, $base) = @_;
    return $path if $path =~ m{^([A-Za-z]:[\\/]|/|\\\\)};  # already absolute
    return "$base/$path";
}

# Extract .value from a slicer record hash, with fallback
sub _sv {
    my ($sl, $key, $default) = @_;
    return (($sl->{$key} // {})->{value} // $default) + 0;
}

# YAML::Tiny returns bare "false"/"true" as strings; treat them as booleans.
sub _yaml_bool { my ($v, $def) = @_; return $def unless defined $v;
                 return 0 if lc($v) eq 'false' || $v eq '0';
                 return 1 if lc($v) eq 'true'  || $v eq '1';
                 return $v ? 1 : 0; }

sub _write_file {
    my ($path, $content) = @_;
    open my $fh, '>:encoding(UTF-8)', $path
        or die "Cannot write $path: $!\n";
    print $fh $content;
    close $fh;
}

sub _show_cmd {
    my ($cmd) = @_;
    # Quote elements containing spaces for display only
    my $str = join(' ', map { /\s/ ? qq("$_") : $_ } @$cmd);
    print "  CMD: $str\n";
}

# ══════════════════════════════════════════════════════════════════════════════
# BUILT-IN TT2 TEMPLATES
# ══════════════════════════════════════════════════════════════════════════════

sub _tmpl_report { return <<'TMPL_END'
# [% spec.intent %] — Build Parameter Report

**File:** `[% name %].[% format %]`
**Generated:** [% generated %]
**Material:** [% spec.material %] | **Fit:** [% spec.fit_profile || 'Standard' %]
**Dimensions:** [% spec.width %] × [% spec.length %] × [% spec.height %] mm ([% spec.dimension_mode || 'Total' %])

---
## Printer / Physics

| Parameter | Value | Source |
|-----------|-------|--------|
[% FOREACH item IN payload.values -%]
[% IF item.sec == 'PHYSICS' -%]
| `[% item.key %]` | [% item.value %] [% item.unit %] | [% item.formula %] |
[% END -%]
[% END %]
---
## Auto-Sized Values

> These are computed automatically. No user action needed.

| Parameter | Value | Formula | Drives / Affects |
|-----------|-------|---------|-----------------|
[% FOREACH item IN payload.autos -%]
| `[% item.key %]` | **[% item.value %]** [% item.unit %] | `[% item.formula %]` | [% item.flag_map.DRIVES || item.flag_map.AFFECTS || item.flag_map.NOTE || '' %] |
[% END %]
[% IF payload.spans.size > 0 -%]
---
## Grid Spans

| # | Span | Row | Col | Size | Height | Status |
|---|------|-----|-----|------|--------|--------|
[% FOREACH s IN payload.spans -%]
| [% loop.index + 1 %] | `[% s.value %]` | [% s.flag_map.row || '?' %] | [% s.flag_map.col || '?' %] | [% s.flag_map.row_span || '?' %]r × [% s.flag_map.col_span || '?' %]c | [% s.flag_map.h_final || '?' %] mm | [% s.src %] |
[% END -%]
[% END %]
[% IF payload.warnings.size > 0 -%]
---
## ⚠ Warnings

[% FOREACH w IN payload.warnings -%]
- **[% w.key %]**: [% w.formula %]
  → [% w.flags %]

[% END -%]
[% END %]
TMPL_END
}

sub _tmpl_slicer { return <<'TMPL_END'
# [% spec.intent %] — Slicer Settings

**Model:** `[% name %].[% format %]`
**Generated:** [% generated %] | [% spec.material %] on [% spec.nozzle %] mm nozzle

---
## General Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Nozzle temperature | [% general.nozzle_temp %] °C | [% spec.material %] baseline |
| Bed temperature | [% general.bed_temp %] °C | |
| Nozzle diameter | [% spec.nozzle %] mm | Must match OpenSCAD Nozzle Diameter |
| Layer height | [% general.layer_height %] mm | Base — overridden by zones below |
| First layer height | [% general.first_layer_h %] mm | Fixed for bed adhesion |
| Wall loops | [% general.wall_loops %] | **Must match OpenSCAD Wall Loops slider** |
| Top / bottom layers | [% general.top_layers %] | ≈ 0.8 mm shell |
| Infill | [% general.infill_density %]% [% general.infill_pattern %] | |
| Supports | **[% general.supports %]** | All geometry is support-free by design |
[% IF general.brim > 0 -%]
| Brim | [% general.brim %] lines | Recommended for cylindrical base |
[% END -%]
| Fan speed | [% general.fan_speed %]% | |
| Retraction | [% general.retract_dist %] mm | |
| Wall print speed | [% general.speed_wall %] mm/s | |
| First layer speed | [% general.first_layer_speed %] mm/s | |

---
## Variable Layer Height

Apply zones **from the bottom up**. Each zone overrides the base layer height.
[% IF payload.intent_flags.has_lid -%]

> **Lid note:** The *Lid face* row applies to the **lid part only** (printed face-down as a separate object).
[% END %]

| Zone | Z start | Z end | Layer height | Rationale |
|------|---------|-------|-------------|-----------|
[% FOREACH z IN vl_zones -%]
| **[% z.name %]** | [% z.z_min %] mm | [% z.z_max %] mm | **[% z.lh %] mm** | [% z.reason %] |
[% END %]

### Bambu Studio — how to set variable layer height

1. Drag `[% name %].[% format %]` onto the build plate.
2. Select the model, then click **Variable Layer Height** (paint-roller icon, top bar).
3. Open the **Manual** tab in the right panel.
4. Click **Add range** for each row in the table above; enter Z start, Z end, layer height.
5. Click **Confirm** → **Slice now**.

### PrusaSlicer — how to set variable layer height

1. Load the model, click **Variable Layer Height** (layer icon, left toolbar).
2. Click **Reset** to clear the auto-generated map.
3. Click **Edit ranges** and enter each row from the table above.
4. Click **Close** and slice normally.

---
## Mesh Settings

| Surface | Hole size | Strut density | Pattern |
|---------|-----------|---------------|---------|
| Walls   | [% spec.mesh_hole_size || '0 (auto)' %] mm | [% spec.strut_wall  || 100 %]% | [% spec.mesh_pattern || 'Teardrop' %] |
| Floor   | [% spec.mesh_hole_size || '0 (auto)' %] mm | [% spec.strut_floor || 100 %]% | [% spec.mesh_pattern || 'Teardrop' %] |
| Lid     | [% spec.mesh_hole_size || '0 (auto)' %] mm | [% spec.strut_lid   || 100 %]% | [% spec.mesh_pattern || 'Teardrop' %] |

Divider thickness: **[% spec.divider_thickness || 1.2 %] mm**

TMPL_END
}

__END__
TMPL_END
