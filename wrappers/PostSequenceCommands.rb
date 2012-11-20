#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'BWAParams'
require 'PathInfo'
require 'SchedulerInfo'

#Commands to run after sequence generation is complete.
#Author: Nirav Shah niravs@bcm.edu

fcBarcode   = nil
reference = nil
inputParams = BWAParams.new()
inputParams.loadFromFile()
fcBarcode   = inputParams.getFCBarcode()
reference   = inputParams.getReferencePath()  # Genome Reference path

# Upload the sequence generation results (phasing, prephasing, raw clusters,
# percent purity filtered cluster and yield to LIMS.
uploadCmd = "ruby " + PathInfo::WRAPPER_DIR + "/ResultUploader.rb SEQUENCE_FINISHED"
output    = `#{uploadCmd}`
puts output

# Command to start sequence analysis
seqAnalyzerCmd = "ruby " + PathInfo::WRAPPER_DIR + "/SequenceAnalyzerWrapper.rb"
sch1 = Scheduler.new(fcBarcode + "_SequenceAnalysis", seqAnalyzerCmd)
sch1.setMemory(8000)
sch1.setNodeCores(1)
sch1.setPriority(SchedulerInfo::DEFAULT_QUEUE)
sch1.runCommand()
uniqJobName = sch1.getJobName()   #Later used as a dependency

# Run PostAlignmentProcess now if sequence set to N/A, else do Aligner.rb b/c sequence set to genomic reference
if reference.eql?("N/A") || reference.eql?("N/A_auto") 
    puts "Reference sequence has been set to N/A. Skipping read mapping, proceed to clean DIRs and upload result path"

    postRunCmd = "ruby " + PathInfo::WRAPPER_DIR + "/PostAlignmentProcess.rb"
    objPostRun = Scheduler.new(fcBarcode + "_post_run_reference_is_NA", postRunCmd)
    objPostRun.setMemory(2000)
    objPostRun.setNodeCores(1)
    objPostRun.setPriority(SchedulerInfo::DEFAULT_QUEUE)
    objPostRun.setDependency(uniqJobName)  #Wait for SequenceAnalyzerWrapper.rb to finish
    objPostRun.runCommand()
else

    # Command to start the alignment
    alignerCmd = "ruby " + PathInfo::BIN_DIR + "/Aligner.rb"

    output = `#{alignerCmd}`
    puts output
end

# Put CASAVA generated fastq files into its own directory
#FileUtils.mkdir("casava_fastq")
#FileUtils.mv("*.fastq.gz", "./casava_fastq")
