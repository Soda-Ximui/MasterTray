#!/usr/bin/env perl
# export_intents.pl - Classify MasterManifest.scad intents as public/internal
#
# "Public" intents are the ones exposed in the Customizer's Part_To_Build
# dropdown (MasterBuilder.scad) - these are the values build/mapping.yaml's
# `intents:` table maps friendly names onto. "Internal" intents are every
# other `intent == "..."` string in MasterManifest.scad - sub-parts only
# reachable via recursive compile_manifest() calls (e.g. individual lids,
# half-lids, grid inserts).
#
# Also cross-checks that every value in mapping.yaml's `intents:` table is
# a real public intent, so the friendly-name layer can't drift out of sync
# with the Customizer dropdown.
#
# Usage:
#   perl build/scripts/export_intents.pl
#
# Reads:  MasterBuilder.scad, MasterManifest.scad, build/mapping.yaml
# Writes: build/intents.json

use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;
use YAML::Tiny;
use JSON::PP;

my $build_dir = File::Spec->catdir($RealBin, '..');
my $repo_root = File::Spec->catdir($build_dir, '..');

my $builder_file  = File::Spec->catfile($repo_root, 'MasterBuilder.scad');
my $manifest_file = File::Spec->catfile($repo_root, 'MasterManifest.scad');
my $mapping_file  = File::Spec->catfile($build_dir, 'mapping.yaml');
my $out_file      = File::Spec->catfile($build_dir, 'intents.json');

# --- Public intents: Part_To_Build dropdown in MasterBuilder.scad ---
my $builder_text = slurp($builder_file);
$builder_text =~ /Part_To_Build\s*=\s*"[^"]+";\s*\/\/\s*\[(.+)\]/
    or die "ERROR: could not find Part_To_Build dropdown in $builder_file\n";
my @public = ($1 =~ /"([^"]+)"/g);
my %is_public = map { $_ => 1 } @public;

# --- All intents referenced in MasterManifest.scad ---
my $manifest_text = slurp($manifest_file);
my %seen;
my @all = grep { !$seen{$_}++ } ($manifest_text =~ /intent\s*==\s*"([^"]+)"/g);

my @internal = grep { !$is_public{$_} } @all;

# --- Cross-check mapping.yaml's intents: table against the public set ---
my $yaml = YAML::Tiny->read($mapping_file) or die "ERROR: failed to parse $mapping_file: $YAML::Tiny::errstr\n";
my $mapping_intents = $yaml->[0]{intents} || {};

my @mismatches;
for my $friendly (sort keys %$mapping_intents) {
    my $target = $mapping_intents->{$friendly};
    push @mismatches, "mapping.yaml intents.\"$friendly\" -> \"$target\" is not a public intent"
        unless $is_public{$target};
}
for my $pub (@public) {
    push @mismatches, "public intent \"$pub\" has no entry in mapping.yaml's intents: table"
        unless grep { $mapping_intents->{$_} eq $pub } keys %$mapping_intents;
}

my $data = {
    public   => \@public,
    internal => \@internal,
    mapping_mismatches => \@mismatches,
};

my $json = JSON::PP->new->canonical->pretty;
open(my $fh, '>:encoding(UTF-8)', $out_file) or die "ERROR: cannot write $out_file: $!\n";
print $fh $json->encode($data);
close $fh;

print "wrote: $out_file\n";
print "  public intents:   " . scalar(@public) . "\n";
print "  internal intents: " . scalar(@internal) . "\n";
if (@mismatches) {
    print "  WARNINGS:\n";
    print "    - $_\n" for @mismatches;
} else {
    print "  mapping.yaml intents: in sync with Customizer dropdown\n";
}

sub slurp {
    my ($file) = @_;
    die "ERROR: file not found: $file\n" unless -e $file;
    open(my $fh, '<:encoding(UTF-8)', $file) or die "ERROR: cannot read $file: $!\n";
    local $/;
    return <$fh>;
}
