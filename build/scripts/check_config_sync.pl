#!/usr/bin/env perl
# check_config_sync.pl - Verify build/configs/*.yaml match MasterBuilder.scad defaults
#
# build/configs/{printer,mesh,advanced}.yaml are example --config override files for
# mastertray.py. They aren't load-bearing defaults (MasterBuilder.scad's own Customizer
# defaults always apply when --config isn't passed), but build reports diff against
# them, so they need to track MasterBuilder.scad's @CONFIG_SECTION values.
#
# This script parses the `Var = value;` assignments inside each
# @CONFIG_SECTION_START/END block in MasterBuilder.scad, maps Customizer variable
# names to friendly keys via build/mapping.yaml's config.* tables, and compares the
# resulting defaults against build/configs/*.yaml. Any drift is reported.
#
# Usage:
#   perl build/scripts/check_config_sync.pl
#
# Reads:  MasterBuilder.scad, build/mapping.yaml, build/configs/{printer,mesh,advanced}.yaml
# Exits:  0 if in sync, 1 if any drift found

use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;
use YAML::Tiny;

my $build_dir   = File::Spec->catdir($RealBin, '..');
my $repo_root   = File::Spec->catdir($build_dir, '..');
my $scad_file   = File::Spec->catfile($repo_root, 'MasterBuilder.scad');
my $mapping_file = File::Spec->catfile($build_dir, 'mapping.yaml');
my $configs_dir  = File::Spec->catdir($build_dir, 'configs');

my @groups = qw(printer mesh advanced);

my $scad_text = slurp($scad_file);

# --- Parse @CONFIG_SECTION blocks: {group}{Customizer_Var} = normalized default ---
my %scad_defaults;
for my $group (@groups) {
    $scad_text =~ /\@CONFIG_SECTION_START:\s*\Q$group\E(.*?)\@CONFIG_SECTION_END:\s*\Q$group\E/s
        or die "ERROR: could not find \@CONFIG_SECTION_START/END: $group in $scad_file\n";
    my $block = $1;
    for my $line (split /\n/, $block) {
        next if $line =~ m{^\s*//} || $line =~ m{^\s*/\*} || $line =~ /^\s*$/;
        if ($line =~ /^\s*(\w+)\s*=\s*(.+?);/) {
            my ($var, $raw) = ($1, $2);
            $scad_defaults{$group}{$var} = normalize_scad($raw);
        }
    }
}

# --- Load mapping.yaml's config.* tables: {group}{friendly} = Customizer_Var ---
my $mapping_yaml = YAML::Tiny->read($mapping_file)
    or die "ERROR: failed to parse $mapping_file: $YAML::Tiny::errstr\n";
my $config_map = $mapping_yaml->[0]{config} || {};

# --- Load build/configs/*.yaml: {group}{friendly} = normalized value ---
my %config_values;
for my $group (@groups) {
    my $file = File::Spec->catfile($configs_dir, "$group.yaml");
    my $yaml = YAML::Tiny->read($file)
        or die "ERROR: failed to parse $file: $YAML::Tiny::errstr\n";
    my $data = $yaml->[0] || {};
    $config_values{$group}{$_} = normalize_yaml($data->{$_}) for keys %$data;
}

my @issues;

for my $group (@groups) {
    my $friendly_to_var = $config_map->{$group} || {};
    my %var_to_friendly = reverse %$friendly_to_var;

    # SCAD default exists -> mapping.yaml entry -> build/configs/<group>.yaml entry, all in sync?
    for my $var (sort keys %{ $scad_defaults{$group} }) {
        my $friendly = $var_to_friendly{$var};
        if (!defined $friendly) {
            push @issues, "MasterBuilder.scad \@CONFIG_SECTION:$group has '$var' "
                . "with no mapping.yaml config.$group entry";
            next;
        }
        my $scad_val = $scad_defaults{$group}{$var};
        if (!exists $config_values{$group}{$friendly}) {
            push @issues, "build/configs/$group.yaml is missing '$friendly' "
                . "(MasterBuilder.scad $var = $scad_val)";
            next;
        }
        my $config_val = $config_values{$group}{$friendly};
        if ($scad_val ne $config_val) {
            push @issues, "build/configs/$group.yaml: $friendly = $config_val "
                . "but MasterBuilder.scad $var = $scad_val";
        }
    }

    # build/configs/<group>.yaml entry with no corresponding mapping.yaml/SCAD default?
    for my $friendly (sort keys %{ $config_values{$group} }) {
        my $var = $friendly_to_var->{$friendly};
        if (!defined $var) {
            push @issues, "build/configs/$group.yaml has '$friendly' "
                . "with no mapping.yaml config.$group entry";
        } elsif (!exists $scad_defaults{$group}{$var}) {
            push @issues, "build/configs/$group.yaml has '$friendly' ($var) "
                . "with no default in MasterBuilder.scad \@CONFIG_SECTION:$group";
        }
    }
}

if (@issues) {
    print "build/configs/*.yaml DRIFT vs MasterBuilder.scad defaults:\n";
    print "  - $_\n" for @issues;
    exit 1;
}

print "build/configs/*.yaml: in sync with MasterBuilder.scad \@CONFIG_SECTION defaults\n";
exit 0;

sub slurp {
    my ($file) = @_;
    die "ERROR: file not found: $file\n" unless -e $file;
    open(my $fh, '<:encoding(UTF-8)', $file) or die "ERROR: cannot read $file: $!\n";
    local $/;
    return <$fh>;
}

# Normalize a raw MasterBuilder.scad RHS (before the trailing ';') to a comparable string.
sub normalize_scad {
    my ($raw) = @_;
    $raw =~ s/^\s+|\s+$//g;
    if ($raw =~ /^"(.*)"$/) {
        return $1;
    }
    if ($raw eq 'true' || $raw eq 'false') {
        return $raw;
    }
    if ($raw =~ /^-?\d+(\.\d+)?$/) {
        return "" . (0 + $raw);
    }
    return $raw;
}

# Normalize a YAML::Tiny scalar value to a comparable string.
sub normalize_yaml {
    my ($val) = @_;
    return '' unless defined $val;
    if ($val eq 'true' || $val eq 'false') {
        return $val;
    }
    if ($val =~ /^-?\d+(\.\d+)?$/) {
        return "" . (0 + $val);
    }
    return $val;
}
