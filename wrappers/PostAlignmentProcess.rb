#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PathInfo'
require 'BWAParams'
require 'ErrorHandler'

# Script to perform cleanup after alignment is complete.
# Author: Nirav Shah niravs@bcm.edu
class PostAlignmentProcess
  def initialize()
    getFlowcellBarcode()
    obtainPathAndResourceInfo()
    if true == isHumanSample() && true == existsBAMPath()      
       begin
          $stdout.puts @fcBarcode + " is a human sample, *_marked.bam exists, will go ahead and process GATK recalibration, indel realingment and SNP and INDEL calling."
          bamFile = @fcBarcode + "_marked.bam"
          runSAMTOOLSindex(bamFile)
          runGATKrecalibration()
          runGATKrealignment()
          runSamtoolsPileup()
          runVariantDriverSNP()
          runVariantDriverIndel()
       rescue Exception => e
           $stderr.puts "Error occured during Mercury stage for flowcell : " + @fcBarcode.to_s + "\n Also sending email to team"
	   $stderr.puts e.message
	   $stderr.puts e.backtrace.inspect
	   handleError(e.message)
       end
    elsif true == isHumanSample() && false == existsBAMPath()
       $stdout.puts @fcBarcode + " is a human sample but could not find maximum one *_marked.bam file for GATK recalibration, indel realingment and SNP and INDEL calling."
       handleError("Human sample does not have ONLY ONE " + @fcBarcode + "_marked.bam file for SNP and INDEL processing. iPipe does not know which BAM to use for downstream analysis") 
    else
       $stdout.puts @fcBarcode + " is not a human sample, will not process GATK recalibration, indel realingment and SNP and INDEL calling."
    end
    
    if false == isHumanSample()   #For non-human samples upload BWA BAM results now. For human samples, results upload command is run in /blackbox_wrappers/VariantDriver.rb which allows for LIMS upload after Mercury is finished
      uploadResultsToLIMS()
    end
    bwaStatsUpload()
    emailAnalysisResults()
    cleanIntermediateFiles()
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
    @queueName      = inputParams.getSchedulingQueue()
    @referencePath = inputParams.getReferencePath()   #Get path of reference to be used for SNP and INdel
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

  def obtainPathAndResourceInfo()
     
         yamlConfigFile = PathInfo::CONFIG_DIR + "/config_params.yml" 
         configReader = YAML.load_file(yamlConfigFile)
         # Obtain resources to use on the cluster
         #@maxMemory = configReader["scheduler"]["queue"][@queueName]["maxMemory"]
         #puts "Max memory : " + @maxMemory.to_s
         #@maxNodeCores = configReader["scheduler"]["queue"][@queueName]["maxCores"]
         #puts "Max cores per node : " + @maxNodeCores.to_s + " for queue " + @queueName
         # Obtain path information
         @gatkPath = configReader["generateVCF"]["gatkPath"]
	 @dbSnpPath = configReader["generateVCF"]["dbSnpPath"]
	 @samtoolsPath = configReader["generateVCF"]["samtoolsPath"]
	 #@javaDir = PathInfo::JAVA_DIR 
  end

  
# Read the reference path and determine if the given sequencing event is human
# or not.
  def isHumanSample()
     if @referencePath != nil && @referencePath.match(/hg1[89]\.fa$/)
        return true
     else
        return false
     end
  end

  def existsBAMPath()
     bamFile = Dir["*_marked.bam"]
     if bamFile == nil || bamFile.length != 1
        return false
     else
	return true
     end
  end

  def handleError(errorMessage)
     obj   = ErrorMessage.new()
     obj.workingDir = Dir.pwd
     obj.msgBrief   = "Error in PostAlignment.rb for flowcell: " + @fcBarcode.to_s
     obj.msgDetail  = errorMessage
     ErrorHandler.handleError(obj)
  end
  
  def runSAMTOOLSindex(bamFile)
    if bamFile != nil && bamFile.length > 0
	### Here is the command which generates the indexed BAM
        samtoolsCmd = "samtools index " + File.expand_path(bamFile)   
	samtoolsProcessObj = Scheduler.new(@fcBarcode + "_Mercury_samtoolsIndex", samtoolsCmd)
	samtoolsProcessObj.setMemory(25000)
	samtoolsProcessObj.setNodeCores(1)
	samtoolsProcessObj.setPriority(@queueName)
	if @prevJobID != nil
	  samtoolsProcessObj.setDependency(@prevJobID)     # @prevJobID will be nil for indexing of 1st BAM _marked.bam. Indexing of latter files will have @prevJobID
	end
	samtoolsProcessObj.runCommand()
	@prevJobID = samtoolsProcessObj.getJobName()
    end
  end

  
  def runGATKrecalibration()

    #Run first step of GATK recalibration - GATK Count Covariates
    bamFile = @fcBarcode + "_marked.bam"
    gatkCountCovariatesCmd = "java -Xmx26000M -jar " + @gatkPath + " -T CountCovariates -nt 8 -I " + bamFile + " -R " + @referencePath + " -dP illumina -knownSites:dbSNP,VCF " + @dbSnpPath + " -cov ReadGroupCovariate -cov QualityScoreCovariate -cov CycleCovariate -cov DinucCovariate -recalFile " + @fcBarcode + ".csv"
    puts gatkCountCovariatesCmd
    gatkCountCovariatesObj = Scheduler.new(@fcBarcode + "_Mercury_gatkCountCovariates", gatkCountCovariatesCmd)
    gatkCountCovariatesObj.setMemory(28000)
    gatkCountCovariatesObj.setNodeCores(8)
    gatkCountCovariatesObj.setPriority(@queueName)
    gatkCountCovariatesObj.setDependency(@prevJobID)
    gatkCountCovariatesObj.runCommand()
    @prevJobID = gatkCountCovariatesObj.getJobName()

    #Run second step of GATK recalibration - GATK Table Recalibration
    gatkTableRecalibrationCmd = "java -Xmx5000M -jar " + @gatkPath + " -T TableRecalibration -I " + bamFile + " -R " + @referencePath + " -dP illumina -o " + @fcBarcode + "_marked.recal.bam -recalFile " + @fcBarcode + ".csv"
    puts gatkTableRecalibrationCmd
    gatkTableRecalibrationObj = Scheduler.new(@fcBarcode + "_Mercury_gatkTableRecalibration", gatkTableRecalibrationCmd)
    gatkTableRecalibrationObj.setMemory(6000)
    gatkTableRecalibrationObj.setNodeCores(1)
    gatkTableRecalibrationObj.setPriority(@queueName)
    gatkTableRecalibrationObj.setDependency(@prevJobID)
    gatkTableRecalibrationObj.runCommand()
    @prevJobID = gatkTableRecalibrationObj.getJobName()
  end

  def runGATKrealignment()     #3rd and 4th step GATK. Method to do realignment using GATK. 
    bamFile = @fcBarcode + "_marked.recal.bam"
    
    gatkRealignerTargetCreatorCmd = "java -Xmx26000M -jar " + @gatkPath + " -T RealignerTargetCreator -nt 8 -I " + @fcBarcode + "_marked.recal.bam -R " + @referencePath + " -o " + @fcBarcode + ".intervals"
    puts gatkRealignerTargetCreatorCmd
    gatkRealignerTargetCreatorObj = Scheduler.new(@fcBarcode + "_Mercury_gatkRealignerTargetCreator", gatkRealignerTargetCreatorCmd)
    gatkRealignerTargetCreatorObj.setMemory(28000)
    gatkRealignerTargetCreatorObj.setNodeCores(8)
    gatkRealignerTargetCreatorObj.setPriority(@queueName)
    gatkRealignerTargetCreatorObj.setDependency(@prevJobID)
    gatkRealignerTargetCreatorObj.runCommand()
    @prevJobID = gatkRealignerTargetCreatorObj.getJobName()

    gatkIndelRealignerCmd = "java -Xmx10000M -jar " + @gatkPath + " -T IndelRealigner  -I " + @fcBarcode + "_marked.recal.bam -R " + @referencePath + " -targetIntervals " + @fcBarcode + ".intervals -o " + @fcBarcode + "_realigned.bam -compress 1"
    puts gatkIndelRealignerCmd
    gatkIndelRealignerObj = Scheduler.new(@fcBarcode + "_Mercury_gatkIndelRealigner", gatkIndelRealignerCmd)
    gatkIndelRealignerObj.setMemory(12000)
    gatkIndelRealignerObj.setNodeCores(1)
    gatkIndelRealignerObj.setPriority(@queueName)
    gatkIndelRealignerObj.setDependency(@prevJobID)
    gatkIndelRealignerObj.runCommand()
    @prevJobID = gatkIndelRealignerObj.getJobName()
  end
  

  def runSamtoolsPileup()    #Atlas2 doesn't require pileup, Cassandra annotation does
    samtoolsPileupCmd = @samtoolsPath + " pileup -vcf " + @referencePath + " " + @fcBarcode + "_realigned.bam > " + @fcBarcode + ".pileup"
    puts samtoolsPileupCmd
    samtoolsPileupObj = Scheduler.new(@fcBarcode + "_Mercury_samtoolsPileup", samtoolsPileupCmd)
    samtoolsPileupObj.setMemory(8000)
    samtoolsPileupObj.setNodeCores(1)
    samtoolsPileupObj.setPriority(@queueName)
    samtoolsPileupObj.setDependency(@prevJobID)
    samtoolsPileupObj.runCommand()
    @prevJobID = samtoolsPileupObj.getJobName()
  end

  def runVariantDriverSNP()               
    variantDriverSnpCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipeV2/blackbox_wrappers/VariantDriver.rb snp"
    variantDriverSnpObj = Scheduler.new(@fcBarcode + "_Mercury_variantDriverSNP", variantDriverSnpCmd)
    variantDriverSnpObj.setMemory(1000)
    variantDriverSnpObj.setNodeCores(1)               #VariantDriver.rb calls VariantCallerWrapper.rb which initiates new jobs to cluster
    variantDriverSnpObj.setPriority(@queueName)
    variantDriverSnpObj.setDependency(@prevJobID)    #@prevJobID is set to last SamtoolsPileUp run.. which should be last dependency
    variantDriverSnpObj.runCommand()
    @previousJobName_SNP = variantDriverSnpObj.getJobName() 
  end

  def runVariantDriverIndel()
    variantDriverIndelCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipeV2/blackbox_wrappers/VariantDriver.rb indel"
    variantDriverIndelObj = Scheduler.new(@fcBarcode + "_Mercury_variantDriverIndel", variantDriverIndelCmd)
    variantDriverIndelObj.setMemory(1000)
    variantDriverIndelObj.setNodeCores(1)    #VariantDriver.rb calls VariantCallerWrapper.rb which initiates new jobs to cluster
    variantDriverIndelObj.setPriority(@queueName)
    variantDriverIndelObj.setDependency(@prevJobID)
    variantDriverIndelObj.runCommand()
    @previousJobName_Indel = variantDriverIndelObj.getJobName()
  end



end

obj = PostAlignmentProcess.new()
