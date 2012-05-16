#!/usr/bin/perl -w

##!/data/pipeline/code/production/bin/x86_64-linux/perl -w

#EXAMPLE to Run: "perl ./getResultsPathInfo.pl 2010-11-09"

use strict;
use LWP;

if( @ARGV % 1) {
print "usage: $0 fromDate \n";
exit;
}

my $ncbiURL ="http://lims-1.hgsc.bcm.tmc.edu/ngenlims/getResultsPathInfo.jsp?";
my $paraStr = "fromDate=" . $ARGV[0];

$ncbiURL="$ncbiURL$paraStr";
#print "$ncbiURL\n";

my $ua = LWP::UserAgent->new;
my $response=$ua->get($ncbiURL);

if(not $response->is_success ) {print "Error: Cannot connect\n"; exit(0);}

my $textStr= $response->content;
$textStr=~ s/\s+$//;
print "$textStr\n";
