#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")
$:.unshift File.dirname(__FILE__)

require 'yaml'
require 'Scheduler'
require 'SchedulerInfo'
require 'BWAParams'
require 'ErrorHandler'
require 'PathInfo'

# Class to control post alignment and post-capture stats blocks.
# This should be run from the same directory where the BAM and the vcf files
# live.
# Author: Nirav Shah niravs@bcm.edu

class VariantDriver
  def initialize()
    findBamFile()

    if @bamFile == nil
      $stderr.puts "No bam file found. Terminating."
      exit 0
    end

    readConfigParams()

    if false == isHumanSample()      
      $stderr.puts @fcBarcode + " is not a human sample. Terminating."
      exit 0
    end
  end
  
  # Method to run the stages
  def process(actionName)
    # Run "SNP" calling and SNP annotation
    if actionName.eql?("snp")
      variantCallCmd = buildSNPCallCommand() 
      variantAnnoCmd = buildSNPAnnotationCallCommand()
    else
      variantCallCmd = buildINDELCallCommand()
      variantAnnoCmd = buildINDELAnnotationCallCommand()
    end

    destDir = actionName.upcase
    FileUtils.mkdir(destDir)
    FileUtils.cd(destDir)
    variantCallObj = Scheduler.new(@fcBarcode + "_Mercury_" + actionName.upcase + "_Atlas", variantCallCmd)
    variantCallObj.setMemory(8000)
    variantCallObj.setNodeCores(1)
    variantCallObj.setPriority(SchedulerInfo::DEFAULT_QUEUE)
    variantCallObj.runCommand()
    prevJobName = variantCallObj.getJobName()

    
    if true == isReferenceHG19()    #Only run Cassandra annotation on hg19 human reference sequence
       variantAnnoObj = Scheduler.new(@fcBarcode + "_Mercury_" + actionName.upcase + "_Annotate", variantAnnoCmd)
       variantAnnoObj.setMemory(10000)
       variantAnnoObj.setNodeCores(1)
       variantAnnoObj.setPriority(SchedulerInfo::ANNOTATION_QUEUE)
       variantAnnoObj.setDependency(prevJobName)
       variantAnnoObj.runCommand()
       prevJobName = variantAnnoObj.getJobName()
    end
     
    if actionName.eql?("snp")     #Only upload VCF stats to LIMS after SNP Atlas and Annotate is complete which always finishes after INDEL, hence motive to upload after SNP.
       FileUtils.cd("../")        #These upload lines will upload SNP and INDEL VCF PATHS and FALGS set to TRUE if VCF exists
       uploadStatsLIMScmd = "ruby " + PathInfo::WRAPPER_DIR + "/ResultUploader.rb ANALYSIS_FINISHED"
       uploadStatsLIMS = Scheduler.new(@fcBarcode + "_uploadSTATSlimsVCF", uploadStatsLIMScmd)
       uploadStatsLIMS.setMemory(1000)
       uploadStatsLIMS.setNodeCores(1)
       uploadStatsLIMS.setPriority(SchedulerInfo::DEFAULT_QUEUE)
       uploadStatsLIMS.setDependency(prevJobName)
       uploadStatsLIMS.runCommand()
    end
  end

  private
    @bamFile          = nil    # Complete path of bam file
    @sampleName       = nil    # Sample name
    @libraryName      = nil    # Library name
    @reference        = nil    # Reference path
    @fcBarcode        = nil    # Flowcell barcode

  # Search for a valid bam file in the current directory
  def findBamFile()

    # Look for a bam with string "realigned" in its name. If it does not exist,
    # then look for a bam name "_marked". If that also does not exist, look for
    # a file with extension "bam".
    # On finding no bams, or more than one bams, return error.
    bamFiles = Dir["*_realigned.bam"]

    if bamFiles == nil || bamFiles.size == 0
      bamFiles = Dir["*_marked.bam"]

			if bamFiles == nil || bamFiles.size == 0
        bamFiles = Dir["*_calmd.bam"]

		      if bamFiles == nil || bamFiles.size == 0
    		    bamFiles = Dir["*.bam"]
			end 
     end
    end

    if bamFiles.size > 1
      raise "Found more than one valid BAM files in " + Dir.pwd
    elsif bamFiles != nil && bamFiles.size == 1
      @bamFile = Dir.pwd + "/" + bamFiles[0]
    else
      @bamFile = null
    end
  end

  # Read the configuration parameters to pass to blackboxes
  def readConfigParams()
    configParams = BWAParams.new()
    configParams.loadFromFile()

    @reference   = configParams.getReferencePath()
    @sampleName  = configParams.getSampleName()
    @libraryName = configParams.getLibraryName()
    @fcBarcode   = configParams.getFCBarcode()
  end

  # Read the reference path and determine if the given sequencing event is human
  # or not.
  def isHumanSample()
    if @reference != nil && @reference.match(/hg1[89]\.fa$/)
      return true
    else
      return false
    end
  end

  def isReferenceHG19()
    if @reference != nil && @reference.match(/hg19\.fa$/)
       return true
    else
       return false
    end
  end



  # Build the SNP caller command
  def buildSNPCallCommand()
    cmd = "ruby " + PathInfo::BLACK_BOX_DIR + "/VariantCallerWrapper.rb " +
          @bamFile.to_s + " " + @reference.to_s + " " + @sampleName.to_s + " " +
          @sampleName.to_s + " snp 1>snp_caller_log.o 2>snp_caller_log.e"
    return cmd
  end

  # Build the INDEL caller command
  def buildINDELCallCommand()
    cmd = "ruby " + PathInfo::BLACK_BOX_DIR + "/VariantCallerWrapper.rb " +
          @bamFile.to_s + " " + @reference.to_s + " " + @sampleName.to_s + " " +
          @sampleName.to_s + " indel 1>indel_caller_log.o 2>indel_caller_log.e"
    return cmd
  end

  # Build the command to annotate SNP calls
  def buildSNPAnnotationCallCommand()
    cmd = "ruby " + PathInfo::BLACK_BOX_DIR + "/VariantAnnotatorWrapper.rb snp " + 
          " 1>snp_annotator_log.o 2>snp_annotator_log.e"
    return cmd
  end

  # Build the command to annotate indel calls
  def buildINDELAnnotationCallCommand()
    cmd = "ruby " + PathInfo::BLACK_BOX_DIR + "/VariantAnnotatorWrapper.rb indel " + 
          " 1>indel_annotator_log.o 2>indel_annotator_log.e"
    return cmd
  end

  # Primitive error handler - currently send email about the error and exit
  def handleError(errorMessage)
    obj   = ErrorMessage.new()
    obj.workingDir = Dir.pwd
    obj.msgBrief   = "Variant calling error for " + @fcBarcode.to_s
    obj.msgDetail  = errorMessage

    ErrorHandler.handleError(obj)
    exit -1
  end
end

action = ARGV[0]

obj = VariantDriver.new()

if action.downcase.eql?("snp")
   obj.process("snp")
else
   obj.process("indel")
end
