#!/bin/bash

FILE=$1
HERE=`pwd`
GATK='/stornext/snfs0/next-gen/project_SNP_calling/software/GenomeAnalysisTK/GenomeAnalysisTK.jar'
REF='/stornext/snfs5/next-gen/Illumina/bwa_references/h/hg19/original/hg19.fa'
DBSNP='/users/jy2/workspace/reference/phase2/mapping_resources/ALL.wgs.dbsnp.build135.snps.sites.vcf.gz'

#### File is a tab delimeted list of SAMPLES(henceforth named FC) and paths to where the BAMs are, and may include the BAM ###


cat $FILE | while read LINE

do

	FC=`echo $LINE | cut -d " " -f1`
	DIR_BAM_IN=`echo $LINE | cut -d " " -f2`
	DIR_BAM=`ls $DIR_BAM_IN/*marked.bam`   ### Comment this back in if the path does not contain the bam ###
	BAM=`basename $DIR_BAM`
	DIR=`dirname $DIR_BAM`


cd ${DIR}
### Here is the command which generates the indexed BAM
echo "samtools index ${BAM}" | msub -q normal -d ${DIR}  -V -l nodes=1:ppn=2,mem=8000mb -N ${FC}_index
sleep 3
### Here are the commands which do the recalibration
echo "java -Xmx26000M -jar $GATK -T CountCovariates -I ${BAM} -R $REF -dRG 0 -dP illumina -B:dbsnp,vcf $DBSNP -cov ReadGroupCovariate -cov QualityScoreCovariate -cov CycleCovariate -cov DinucCovariate -recalFile ${FC}.csv" | msub -q normal -d ${DIR} -V -l depend=afterok:${FC}_index -l nodes=1:ppn=8,mem=28G -N ${FC}_CC 
sleep 3
echo "java -Xmx26000M -jar $GATK -T TableRecalibration -I ${BAM} -R $REF -dRG 0 -dP illumina  -o ${FC}_marked.recal.bam -recalFile ${FC}.csv" | msub -q normal -d ${DIR} -V -l depend=afterok:${FC}_CC -l nodes=1:ppn=8,mem=28G -N ${FC}_recal
sleep 3
### Here is the command which generates the indexed recal-BAM
echo "samtools index ${FC}_marked.recal.bam" | msub -q normal -d ${DIR}  -V -l depend=afterok:${FC}_recal -l nodes=1:ppn=2,mem=8000mb -N ${FC}_index2
sleep 3
### Here is the command for generating realignment
echo "java -Xmx26000M -jar /stornext/snfs5/next-gen/Illumina/ipipeV2/gatk/GenomeAnalysisTK-1.3-8-gb0e6afe/GenomeAnalysisTK.jar -T RealignerTargetCreator -I ${FC}_marked.recal.bam -R $REF -o ${FC}.intervals" | msub -q normal -V -d $DIR -l depend=afterok:${FC}_index2 -l nodes=1:ppn=8,mem=28G -N ${FC}_intervals
sleep 3
echo "java -Xmx40000M -jar /stornext/snfs5/next-gen/Illumina/ipipeV2/gatk/GenomeAnalysisTK-1.3-8-gb0e6afe/GenomeAnalysisTK.jar -T IndelRealigner -I ${FC}_marked.recal.bam -R $REF -targetIntervals ${FC}.intervals -o ${FC}_realigned.bam -compress 1" | msub -q normal -V -d $DIR -l depend=afterok:${FC}_intervals -l nodes=1:ppn=8,mem=44G -N ${FC}_realign
sleep 3
### Here is the command which generates the indexed BAM
echo "samtools index ${FC}_realigned.bam" | msub -q normal -d ${DIR}  -V -l depend=afterok:${FC}_realign -l nodes=1:ppn=2,mem=8000mb -N ${FC}_index3
sleep 3
### Here is the command to generate pileup
echo "/stornext/snfs5/next-gen/software/samtools-0.1.7/samtools pileup -vcf ${REF} ${FC}_realigned.bam > ${FC}.pileup" | msub -V -q normal -d ${DIR} -l depend=afterok:${FC}_index3 -l nodes=1:ppn=4,mem=8000mb -N ${FC}_pileup 
sleep 3
### Here is the command to kick off VariantDriver
echo "ruby /stornext/snfs5/next-gen/Illumina/ipipeV2/blackbox_wrappers/VariantDriver.rb.ali snp" | msub -V -q normal -d ${DIR} -l depend=afterok:${FC}_pileup -l nodes=1:ppn=1,mem=4000mb -N ${FC}_snp
sleep 3
echo "ruby /stornext/snfs5/next-gen/Illumina/ipipeV2/blackbox_wrappers/VariantDriver.rb.ali indel" | msub -V -q normal -d ${DIR} -l depend=afterok:${FC}_pileup -l nodes=1:ppn=1,mem=4000mb -N ${FC}_indel
sleep 3
cd ${HERE}

done
