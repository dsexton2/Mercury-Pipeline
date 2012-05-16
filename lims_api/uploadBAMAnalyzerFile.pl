#!/usr/bin/perl -w

# EXAMPLE to Run: "perl ./setIlluminaBwaMapStats.pl laneBarcode fileName "
#
use strict;
use LWP;

if( @ARGV !=2 ) {
print "usage: $0 barcode file_name\n";
exit;
}

my $data_file= $ARGV[1];
unless ($data_file =~ /^.+\.\w+$/) {
     print "Please give a  file";
     exit;
}

open(DAT, $data_file) || die("Could not open file!");
my @raw_data=<DAT>;
close(DAT);

my $file_content = "";
foreach my $line (@raw_data)
{
  $file_content .= $line;
}

my $ua = new LWP::UserAgent;
my $uploadhtmlURL = "http://lims-1.hgsc.bcm.tmc.edu/ngenlims/edu.bcm.hgsc.gwt.lims454.NGenLimsGwt/uploadText";
#my $uploadhtmlURL = "http://localhost:8080/ngenlims/edu.bcm.hgsc.gwt.lims454.NGenLimsGwt/uploadText";
#my $uploadhtmlURL = "http://test-gen2.hgsc.bcm.tmc.edu/ngenlims/edu.bcm.hgsc.gwt.lims454.NGenLimsGwt/uploadText";
my $response = $ua ->post($uploadhtmlURL, {barcode => $ARGV[0],file_name => $ARGV[1] ,file_content => $file_content});

if(not $response->is_success ) {print "Error: Cannot connect\n"; exit(-1);}

my $textStr= $response->content;
$textStr =~ /^\s*(.+)\s*$/;
$textStr = $1;
print "$textStr\n";