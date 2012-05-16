#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PathInfo'
require 'BWAParams'

# Script to perform cleanup after alignment is complete.
# Author: Nirav Shah niravs@bcm.edu
class PostAlignmentProcess
  def initialize()
    getFlowcellBarcode()
    uploadResultsToLIMS()
    bwaStatsUpload()
    emailAnalysisResults()
    cleanIntermediateFiles()
    runSNPCaller()
    zipSequenceFiles()
  end

  private
  
  #Method to read config file and obtain flowcell barcode
  def getFlowcellBarcode()
    @fcBarcode = nil

    inputParams = BWAParams.new()
    inputParams.loadFromFile()
    @fcBarcode  = inputParams.getFCBarcode() # Lane barcode FCName-Lane-BarcodeName

    if @fcBarcode == nil || @fcBarcode.empty?()
      raise "Did not obtain flowcell barcode in directory : " + Dir.pwd
    end
  end
 
  # Method to upload the alignment results to LIMS
  def uploadResultsToLIMS()
    uploadCmd = "ruby " + PathInfo::WRAPPER_DIR + 
                "/ResultUploader.rb ANALYSIS_FINISHED"
    output    = `#{uploadCmd}`
    puts output
  end
  
  #  #Push BWA Stats results to LIMS
    
  def bwaStatsUpload()
    resultFile = "BWA_Map_Stats.txt"
      
    if !File::exist?(resultFile)
      raise "Did not find " + resultFile + ", can't upload BWA results to LIMS"
    end
      
      limsScript = PathInfo::LIMS_API_DIR + "/uploadBAMAnalyzerFile.pl"
      
      limsUploadCmd = "perl " + limsScript + " " + @fcBarcode + " BWA_Map_Stats.txt"
      
      puts limsUploadCmd
      output = `#{limsUploadCmd}`
      puts "Output from LIMS upload command : " + output.to_s
  end

  # Method to email analysis results
  def emailAnalysisResults()
    cmd = "ruby " + PathInfo::LIB_DIR + "/ResultMailer.rb" 
    output = `#{cmd}`
    puts output
  end
 
  # Delete the intermediate files created during the alignment process
  def cleanIntermediateFiles()
   puts "Deleting intermediate files"
   deleteTempFilesCmd = "rm *.sam *.sai"
   `#{deleteTempFilesCmd}`

   # Be careful here, delete only _sorted.bam
   puts "Deleting intermediate BAM file"
   deleteTempBAMFileCmd = "rm *_sorted.bam"
  `#{deleteTempBAMFileCmd}`

   makeDirCmd = "mkdir casava_fastq"
   `#{makeDirCmd}`
   moveCmd = "mv *.fastq.gz ./casava_fastq"
   `#{moveCmd}`
  end

  # Zip the final sequence files to save disk space. Potential improvement: The
  # intermediate .gz fastq files created by CASAVA can also be deleted in this
  # step.
  def zipSequenceFiles()
    puts "Zipping sequence files"
    zipCmd = "bzip2 *sequence.txt"
    `#{zipCmd}`
  end

  def runSNPCaller()
    bamFile = Dir["*_marked.bam"]
    if bamFile != nil && bamFile.length > 0
       snpCallCmd = "ruby /stornext/snfs6/1000GENOMES/challis/geyser_Atlas2_wrapper/Atlas2Submit.rb " +
                     File.expand_path(bamFile[0])
       `#{snpCallCmd}`
    end
  end
end

obj = PostAlignmentProcess.new()
