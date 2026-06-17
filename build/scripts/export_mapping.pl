#!/usr/bin/env perl
# export_mapping.pl - Convert build/mapping.yaml to build/mapping.json
#
# Lets non-Perl tooling (JS/Astro frontend, etc.) consume the friendly-name
# translation table without parsing YAML. YAML::Tiny reads booleans as the
# strings 'true'/'false', so this script walks the tree and converts those
# to real JSON booleans before encoding.
#
# Usage:
#   perl build/scripts/export_mapping.pl
#
# Reads:  build/mapping.yaml
# Writes: build/mapping.json

use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;
use YAML::Tiny;
use JSON::PP;

my $build_dir = File::Spec->catdir($RealBin, '..');
my $in_file   = File::Spec->catfile($build_dir, 'mapping.yaml');
my $out_file  = File::Spec->catfile($build_dir, 'mapping.json');

die "ERROR: mapping file not found: $in_file\n" unless -e $in_file;

my $yaml = YAML::Tiny->read($in_file) or die "ERROR: failed to parse $in_file: $YAML::Tiny::errstr\n";
my $data = $yaml->[0];

fix_booleans($data);

my $json = JSON::PP->new->canonical->pretty;
open(my $fh, '>:encoding(UTF-8)', $out_file) or die "ERROR: cannot write $out_file: $!\n";
print $fh $json->encode($data);
close $fh;

print "wrote: $out_file\n";

# Recursively convert YAML::Tiny's stringified 'true'/'false' into JSON::PP booleans.
sub fix_booleans {
    my ($node) = @_;
    if (ref $node eq 'HASH') {
        for my $key (keys %$node) {
            my $val = $node->{$key};
            if (ref $val) {
                fix_booleans($val);
            } elsif (defined $val && $val eq 'true') {
                $node->{$key} = JSON::PP::true;
            } elsif (defined $val && $val eq 'false') {
                $node->{$key} = JSON::PP::false;
            }
        }
    } elsif (ref $node eq 'ARRAY') {
        for my $i (0 .. $#$node) {
            my $val = $node->[$i];
            if (ref $val) {
                fix_booleans($val);
            } elsif (defined $val && $val eq 'true') {
                $node->[$i] = JSON::PP::true;
            } elsif (defined $val && $val eq 'false') {
                $node->[$i] = JSON::PP::false;
            }
        }
    }
}
