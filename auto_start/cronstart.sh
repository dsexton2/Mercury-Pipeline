#!/usr/bin/sh

echo "Starting shell script"
source /users/p-illumina/.bashrc
echo "Done source .bashrc"

echo "Starting Ruby startAnalysis.rb"
date >> /stornext/snfs5/next-gen/Illumina/ipipeV2/auto_start/flowcell_start.log
ruby /stornext/snfs5/next-gen/Illumina/ipipeV2/auto_start/startAnalysis.rb >> /stornext/snfs5/next-gen/Illumina/ipipeV2/auto_start/flowcell_start.log
echo "DONE"
