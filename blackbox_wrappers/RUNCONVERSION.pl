#usage: <SNPs.Annotated.vcf> <INDELs.Annotataed.vcf> <output name> <BAM>
$loc = "/stornext/snfs5/next-gen/Illumina/ipipeV2/components/_CONVERT_BIN/";
$name = $ARGV[2];
$cmd = "perl $loc/MergeAndConvertAnnos.pl  $ARGV[0]  $ARGV[1]  $name.tsv";
$ccmd = "$cmd;perl $loc/annotateIntoGeneSets.pl $name.tsv; perl $loc/filtTsvARIC.pl  $name.tsv.all.tsv ; perl $loc/getPharmaco.pl $ARGV[3] $name.tsv.pharm; rm -f  $name.tsv.pharm.temp";




#perl $loc/parseIntoGeneSets.pl   $name.tsv; perl  $loc/generateReport.pl $name.tsv.genetest;  perl  $loc/generateReport.pl $name.tsv.hgmd;  perl  $loc/generateReport.pl $name.tsv.other;";
print "$ccmd\n";
system("bsub -q normal \"$ccmd\"");

