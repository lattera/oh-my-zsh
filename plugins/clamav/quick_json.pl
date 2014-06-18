#!/usr/bin/perl

use warnings;
use strict;
use Switch;

my $tablvl = 0;
while (my $fline = <>) {
    if ($fline =~ m/^LibClamAV Error: /) {
        $tablvl = 0;
        my $line = substr $fline, 17;
        my @arr = split /("[^"]*")/, $line;
        #my @arr = split /([^\,]*\,)/, $line;
        for (@arr) {
            if (m/^"/) {
                print $_;
                next;
            }

            # process control characters
            my @control = split /([\{\[\}\]\,][^\{^\[^\}^\]]*)/;
            for (@control) {
                #print "\n" . $_ . "\n";

                switch($_) {
                    case /[\[\{]/ { $tablvl++; print $_ . "\n" . "    "x$tablvl; }
                    case /[\]\}]/ { $tablvl--; print "\n" . "    "x$tablvl . $_ . "\n" . "    "x$tablvl; }
                    case /[\,]/   { print $_ . "\n" . "    "x$tablvl; }
                    else          { print $_; }
                }
            }
        }
    }
}
