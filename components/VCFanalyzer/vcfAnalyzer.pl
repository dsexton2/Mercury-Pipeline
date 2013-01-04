#!/usr/bin/perl

#0	1	2	3	4	5	6	7	8	9		10+
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	SAMPLE_1	...

# assumes format is GT:VR:RR:DP:GQ -- genotype : variant reads : reference reads : depth of coverage : genotype fitler/quality

my %titv = ( "AC" => "transversion", "AG" => "transition",   "AT" => "transversion",
             "CA" => "transversion", "CG" => "transversion", "CT" => "transition",
             "TA" => "transversion", "TC" => "transition",   "TG" => "transversion",
             "GA" => "transition",   "GC" => "transversion", "GT" => "transversion" );

my %RFG = ();
my %UCG = ();
my %GENE = ();
my %HGMD = ();

my $vcfFile = $ARGV[0];
open(vcfFP,"<$vcfFile");

print "## vcf Analyzer output for $vcfFile ##\n";

my @D = ();
my @I = ();
my @SAMPLE = ();
my @COVERAGE = ();

my $number_of_header_lines = 0;
my $number_of_variants = 0;
my $number_of_pass_variants = 0;
my $number_of_low_variant_reads_variants = 0;
my $number_of_not_pass_variants = 0;

my $number_of_transitions = 0;
my $number_of_transversions = 0;
my $titv_ratio = 0;

my $reference_homozygous_count = 0;
my $heterozygous_count = 0;
my $variant_homozygous_count = 0;
my $hete_to_homo_ratio = 0;

my $X_count = 0;
my $Y_count = 0;
my $MT_count = 0;

my $X_heterozygous_count = 0;
my $Y_heterozygous_count = 0;
my $MT_heterozygous_count = 0;

while (<vcfFP>) {
  chomp($_);
  $current_line = $_;

  if ($current_line =~ /^##/) { 
    $number_of_header_lines++;
  } elsif ($current_line =~ /^#CHROM/) { 
    @D = split(/\t/,$current_line);
    my $number_of_samples = scalar(@D)-9;
    print "\'number of header lines\' = $number_of_header_lines\n";
    print "\'number of samples\' = $number_of_samples\n";
  } else {
    $number_of_varaints++;
    @D = split(/\t/,$current_line);

    my $CHROM = $D[0]; my $POS = $D[1];
    my $ID = $D[2]; my $REF = $D[3];
    my $ALT = $D[4]; my $QUAL = $D[5];
    my $FILTER = $D[6]; my $INFO = $D[7];

    @I = split(/;/,$INFO);

    my $FORMAT = $D[8]; 

    ### Assumes single ref & var alleles (for now)    
    # for (my $i = 0; $i < $number_of_samples; $i++) { $SAMPLE[$i] = $D[($i+9)]; }
    $SAMPLE[0] = $D[9];

    if ($FILTER eq 'PASS') {

      ### Assumes single sample vcfs (for now)
      $number_of_pass_variants++;

      my $key = "$REF$ALT";
      ###print ":$key:$REF:$ALT:$titv{$key}\n";
      if ($titv{$key} eq 'transition') { $number_of_transitions++; }
      elsif ($titv{$key} eq 'transversion') { $number_of_transversions++; }

      my $rsid = '.';
      foreach my $info_field (@I) {
        if ($info_field =~ /(RFG|IRF)=(\S+)/) { $RFG{$2}++; }
        if ($info_field =~ /(UCG|IUC)=(\S+)/) { $UCG{$2}++; }
        if ($info_field =~ /GN=(\S+)/) { $GENE{$1}++; }
        if ($info_field =~ /HD=(.+)/) { $HGMD{$1}++; }
        if ($info_field =~ /RSID=(.+)/) { $rsid = $1; }
      }

      my @S = split(/:/,$SAMPLE[0]);
      # GT:VR:RR:DP:GQ
      my $GT = $S[0]; 
      my $VR = $S[1]; my $RR = $S[2]; 
      my $DP = $S[3]; my $GQ = $S[4];

      $COVERAGE[$DP]++;
    
      $GT =~ /(\d)\/(\d)/;
      my $allele_one = $1;
      my $allele_two = $2;

      if ($allele_one != $allele_two) { $heterozygous_count++; }
      elsif ($allele_one == 0) { $reference_homozygous_count++; }
      else { $variant_homozygous_count++; }

      if ($CHROM eq 'X') { 
        $X_count++; 
        if ($allele_one != $allele_two) { $X_heterozygous_count++; }
      }
      if ($CHROM eq 'Y') { 
        #if (%rsid ne '.') {
          $Y_count++; 
          if ($allele_one != $allele_two) { $Y_heterozygous_count++; }
        #}
      }
      if ($CHROM eq 'MT') { 
        $MT_count++; 
        if ($allele_one != $allele_two) { $MT_heterozygous_count++; }
      }

    } else {

      if ($FILTER eq 'low_VariantReads') { $number_of_low_variant_reads_variants++; }
      $number_of_not_pass_variants++;

    }

  }
}

if ($variant_homozygous_count > 0) { $hete_to_homo_ratio = $heterozygous_count/$variant_homozygous_count; }
if ($number_of_transversions > 0) { $titv_ratio = $number_of_transitions/$number_of_transversions; }

print "\n";
print "\'number of non-passing variants\' = $number_of_not_pass_variants\n";
print "\'number of low allele fraction variants\' = $number_of_low_variant_reads_variants\n";
print "\'number of passing variants\' = $number_of_pass_variants\n";

print "\n";
print "\'number of transitions\' = $number_of_transitions\n";
print "\'number of transversions\' = $number_of_transversions\n";
print "\'TiTv ratio\' = $titv_ratio\n";

print "\n";
print "\'reference homozygous count'\ = $reference_homozygous_count\n";
print "\'heterozygous count'\ = $heterozygous_count\n";
print "\'variant homozygous count'\ = $variant_homozygous_count\n";
print "\'heterozygous:homozygous variant ratio\' = $hete_to_homo_ratio\n";

$X_hete_to_homo_ratio = 999;

if (($X_count-$X_heterozygous_count) > 0) { $X_hete_to_homo_ratio = $X_heterozygous_count/($X_count-$X_heterozygous_count); }
if (($Y_count-$Y_heterozygous_count) > 0) { $Y_hete_to_homo_ratio = $Y_heterozygous_count/($Y_count-$Y_heterozygous_count); }
if (($MT_count-$MT_heterozygous_count) >0) { $MT_hete_to_homo_ratio = $MT_heterozygous_count/($MT_count-$MT_heterozygous_count); }

print "\n";

if ($X_hete_to_homo_ratio == 999) { print "Not enough information to determine gender \n\n";}
elsif ($X_hete_to_homo_ratio < 0.5*$hete_to_homo_ratio) { print "Sample appears to be MALE (X homozygous)\n"; }
else { print "Sample appears to be FEMALE (X heterozygous)\n"; }

print "\'X chromosome variant count\' = $X_count\n";
print "\'X chromosome heterozygous count\' = $X_heterozygous_count\n";
print "\'X heterozygous:homozygous variant ratio\' = $X_hete_to_homo_ratio\n";

print "\'Y chromosome variant count\' = $Y_count\n";
print "\'Y chromosome heterozygous count\' = $Y_heterozygous_count\n";
print "\'Y heterozygous:homozygous variant ratio\' = $Y_hete_to_homo_ratio\n";

print "\'MT chromosome variant count\' = $MT_count\n";
print "\'MT chromosome heterozygous count\' = $MT_heterozygous_count\n";
print "\'MT heterozygous:homozygous variant ratio\' = $MT_hete_to_homo_ratio\n";

print "\n";
print "### RefSeq Gene Model Variant Annotations ###\n";
foreach my $key (sort keys %RFG) { 
  my $ratio = $RFG{$key}/$number_of_pass_variants;
  print "$key\t$RFG{$key}\t$ratio\n"; 
}

print "\n";
print "### UCSC Gene Model Variant Annotations ###\n";
foreach my $key (sort keys %UCG) { 
  my $ratio = $UCG{$key}/$number_of_pass_variants;
  print "$key\t$UCG{$key}\t$ratio\n"; 
}

print "\n";
print "### HGMD Top Disease Hits ###\n";
my @list = sort {$HGMD{$b} <=> $HGMD{$a}} keys %HGMD;
for (my $i = 0; $i < 21; $i++) { 
  if (($list[$i] ne '.') && ($list[$i] ne '')) { print "$list[$i]\t$HGMD{$list[$i]}\n"; }
}

print "\n";
print "### Genes with highest number of PASS variants ###\n";
my @list = sort {$GENE{$b} <=> $GENE{$a}} keys %GENE;
for (my $i = 0; $i < 21; $i++) { 
  if (($list[$i] ne '.') && ($list[$i] ne '')) { print "$list[$i]\t$GENE{$list[$i]}\n"; }
}

print "\n";
if ($number_of_pass_variants > 0) {
  print "### Coverage Distribution on PASS Variants ###\n";
  my $total = $number_of_pass_variants;
  for (my $i = 6; $i < 57; $i++) {
    $total -= $COVERAGE[($i-1)];
    my $ratio = $total/$number_of_pass_variants;
    print "$i\t$COVERAGE[$i]\t$ratio\n";
  }
}

