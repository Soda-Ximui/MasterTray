#!/usr/bin/env perl
# validSTL.pl — validate STL files for non-manifold geometry and open boundaries.
#
# Usage:
#   perl validSTL.pl <file.stl>        # single file
#   perl validSTL.pl <directory>       # all STLs in directory tree
#   perl validSTL.pl                   # defaults to current directory
#
# Exit code: 0 if all pass, 1 if any file has non-manifold edges.
# No non-standard modules required.

use strict;
use warnings;
use File::Find;
use POSIX qw();
use Scalar::Util qw(looks_like_number);

# ── ANSI colours ──────────────────────────────────────────────────────────────
my $TTY = -t STDOUT;
sub green  { $TTY ? "\033[32m$_[0]\033[0m" : $_[0] }
sub yellow { $TTY ? "\033[33m$_[0]\033[0m" : $_[0] }
sub red    { $TTY ? "\033[31m$_[0]\033[0m" : $_[0] }
sub cyan   { $TTY ? "\033[36m$_[0]\033[0m" : $_[0] }
sub bold   { $TTY ? "\033[1m$_[0]\033[0m"  : $_[0] }

# ── File discovery ────────────────────────────────────────────────────────────
sub find_stls {
    my ($path) = @_;
    return ($path) if -f $path && $path =~ /\.stl$/i;
    my @found;
    File::Find::find(sub {
        push @found, $File::Find::name if /\.stl$/i && -f $_;
    }, $path);
    return sort @found;
}

# ── STL format detection ──────────────────────────────────────────────────────
# Reliable: binary STL size = 84 + N*50. ASCII starts with "solid" but so do
# some binary files, so use size arithmetic as ground truth.
sub is_binary_stl {
    my ($file) = @_;
    my $size = -s $file;
    return 0 unless $size >= 84;
    open my $fh, '<:raw', $file or return 0;
    read $fh, my $buf, 84;
    close $fh;
    my $n = unpack('V', substr($buf, 80, 4));
    return ($size == 84 + $n * 50) ? $n : 0;
}

# ── Binary STL parser ─────────────────────────────────────────────────────────
sub parse_binary {
    my ($file, $n_tris) = @_;
    open my $fh, '<:raw', $file or die "Cannot open $file: $!";
    read $fh, my $hdr, 84;   # skip header + count
    my @tris;
    for (1 .. $n_tris) {
        read $fh, my $buf, 50 or last;
        # 12 little-endian floats (normal + 3 vertices), 2-byte attribute (skip)
        my @f = unpack('e12', $buf);
        push @tris, [ [@f[3..5]], [@f[6..8]], [@f[9..11]] ];
    }
    close $fh;
    return \@tris;
}

# ── ASCII STL parser ──────────────────────────────────────────────────────────
sub parse_ascii {
    my ($file) = @_;
    open my $fh, '<', $file or die "Cannot open $file: $!";
    my (@tris, @verts);
    while (<$fh>) {
        if (/^\s*vertex\s+([\d.eE+\-]+)\s+([\d.eE+\-]+)\s+([\d.eE+\-]+)/i) {
            push @verts, [$1+0, $2+0, $3+0];
            if (@verts == 3) {
                push @tris, [@verts];
                @verts = ();
            }
        }
    }
    close $fh;
    return \@tris;
}

# ── Edge-face analysis ────────────────────────────────────────────────────────
# Deduplicate vertices (rounded to 5dp) then count face references per edge.
sub analyze_tris {
    my ($tris) = @_;
    my (%vi, @v_list);

    # Build vertex index (deduplicate by rounded key)
    my sub vkey { sprintf("%.5g,%.5g,%.5g", @{$_[0]}) }

    my @faces;
    for my $tri (@$tris) {
        my @idx;
        for my $v (@$tri) {
            my $k = vkey($v);
            unless (exists $vi{$k}) { $vi{$k} = scalar @v_list; push @v_list, $v }
            push @idx, $vi{$k};
        }
        push @faces, \@idx;
    }

    # Edge → face-reference count
    my %ec;
    for my $f (@faces) {
        my ($a, $b, $c) = @$f;
        for my $e ([$a < $b ? ($a,$b) : ($b,$a)],
                   [$b < $c ? ($b,$c) : ($c,$b)],
                   [$a < $c ? ($a,$c) : ($c,$a)]) {
            $ec{"$e->[0],$e->[1]"}++;
        }
    }

    my $nm  = scalar grep { $_ > 2 } values %ec;
    my $bnd = scalar grep { $_ == 1 } values %ec;

    return {
        faces => scalar @faces,
        verts => scalar @v_list,
        nm    => $nm,
        bnd   => $bnd,
    };
}

# ── Analyze a single file ─────────────────────────────────────────────────────
sub analyze_file {
    my ($file) = @_;
    my $n = is_binary_stl($file);
    my $tris = $n ? parse_binary($file, $n) : parse_ascii($file);
    return analyze_tris($tris);
}

# ── Status label ──────────────────────────────────────────────────────────────
sub status_label {
    my ($r) = @_;
    return (red("FAIL"), "non-manifold edges")           if $r->{nm}  > 0;
    return (yellow("OPEN"), "open boundary (not watertight)") if $r->{bnd} > 0;
    return (green("OK"), "");
}

# ── Main ──────────────────────────────────────────────────────────────────────
my $target = $ARGV[0] // '.';
my @files  = find_stls($target);

unless (@files) {
    print "No STL files found in: $target\n";
    exit 0;
}

my $abs = do { require Cwd; Cwd::abs_path($target) };
print bold("\nvalidSTL — " . scalar(@files) . " file(s) in $abs\n") . "\n";

my %counts = (ok => 0, open => 0, fail => 0, err => 0);

# Width of longest relative path for alignment
my $W = 0;
for my $f (@files) {
    (my $rel = $f) =~ s{^\Q$target\E[\\/]?}{};
    $W = length($rel) if length($rel) > $W;
}

for my $file (@files) {
    (my $rel = $file) =~ s{^\Q$target\E[\\/]?}{};
    printf "  %s  ", cyan(sprintf("%-${W}s", $rel));
    my ($r, $err);
    eval { $r = analyze_file($file) };
    $err = $@ if $@;

    if ($err) {
        $err =~ s/\s+/ /g; $err =~ s/ at .+//;
        print red("ERROR: $err") . "\n";
        $counts{err}++;
        next;
    }

    my ($label, $note) = status_label($r);
    printf "faces=%6d  verts=%6d  nm=%4d  bnd=%4d  %s%s\n",
        $r->{faces}, $r->{verts}, $r->{nm}, $r->{bnd},
        $label, ($note ? "  [$note]" : "");

    if    ($r->{nm}  > 0) { $counts{fail}++ }
    elsif ($r->{bnd} > 0) { $counts{open}++ }
    else                  { $counts{ok}++   }
}

# ── Summary ───────────────────────────────────────────────────────────────────
my $total = scalar @files;
print "\n" . "=" x 72 . "\n";
my @parts = (green("$counts{ok} OK"), yellow("$counts{open} OPEN"), red("$counts{fail} FAIL"));
push @parts, red("$counts{err} ERROR") if $counts{err};
print "  $total file(s):  " . join("  |  ", @parts) . "\n";

if    ($counts{fail} > 0) { print red("\n  Non-manifold edges detected — check before slicing.\n") }
elsif ($counts{open} > 0) { print yellow("\n  Open boundaries detected — slicer may auto-repair.\n") }
else                      { print green("\n  All files are watertight manifolds.\n") }

exit($counts{fail} > 0 ? 1 : 0);
