#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'yaml'
require 'PathInfo'
require 'ErrorHandler'

# Class to encapsulate the command to run annotation calls
# Author: Nirav Shah niravs@bcm.edu
class VariantAnnotatorWrapper
  def initialize(cmdParams)
    parseCommandLineParams(cmdParams)
    findVCFFile()
    yamlConfigFile = PathInfo::CONFIG_DIR + "/blackboxes_configuration.yml"
    configReader   = YAML.load_file(yamlConfigFile)
    buildAnnotationCommandString(configReader)
    executeCmd()
    buildAnnotationToVCFCommandString(configReader)
    executeCmd()
    buildVCFanalyzerCommandString(configReader)
    executeCmd()
  end

  private 

  # Parse the command line parameter to determine whether to annotate SNPs or
  # INDELs
  def parseCommandLineParams(cmdParams)
    if cmdParams[0].downcase.eql?("snp")
      @action = "snp"
    else
      @action = "indel"
    end 
  end

  # Find the VCF file corresponding to the action to be performed
  def findVCFFile()
    @vcfFile = nil

    if @action.eql?("snp")
      vcfFiles = Dir["*SNPs.vcf"]
    else
      vcfFiles = Dir["*INDELs.vcf"]
      puts vcfFiles.to_s
    end

    if vcfFiles == nil || vcfFiles.size != 1
      handleError("Error: Did not find exactly one vcf file to annotate " + 
                  @action + " in directory : " + Dir.pwd)
    else
      @vcfFile = vcfFiles[0]
    end
  end

  # Look for a .pileup file in the parent directory (i.e the directory where the
  # bam file lives.
  def findPileupFile()
    pileupFile = Dir["../*.pileup"]

    if pileupFile != nil && pileupFile.length > 0
      return pileupFile[0]
    else
      return nil
    end
  end

  # Method to find the DONESORTED file from the annotation command for the
  # specified action (snp/indel)
  def findAnnotatedOutputFile()
    annotatedOutput = @vcfFile + ".DONESORTED"

    if !File::exist?(annotatedOutput)
      handleError("File: " + annotatedOutput + " does not exist")
    else
      return annotatedOutput
    end
  end

  # Method to find the ".meta" file from the annotation command for the
  # specified action (snp/indel)
  def findAnnotatedMetaFile()
    metaFile = @vcfFile + ".meta"

    if !File::exist?(metaFile)
      handleError("File: " + metaFile + " does not exist")
    else
      return metaFile
    end
  end

  # Create a name for annotated vcf file based on the original input vcf file
  def getOutputFileName()
    return @vcfFile.gsub(/\.vcf$/, "_Annotated.vcf")
  end

  # Method to parse the command line parameters. Since this wrapper is invoked
  # only by blackbox control script, it is guaranteed that the parameters are
  # always passed in the correct order, format. Hence, validation is not
  # required at this stage.
  def parseCommandLineParameters(cmdParams)
    @vcfFile   = cmdParams[0]
  end

  # Helper method to build the command string to annotate SNP / indel
  def buildAnnotationCommandString(configReader)
    if @action.eql?("snp")
      howToRun       = configReader["snpAnnotator"]["starter"]
      codeDir        = configReader["snpAnnotator"]["codeDirectory"]
      code           = configReader["snpAnnotator"]["code"]
      dbConfigFile   = configReader["snpAnnotator"]["dbConfigFile"]
    else
      howToRun       = configReader["indelAnnotator"]["starter"]
      codeDir        = configReader["indelAnnotator"]["codeDirectory"]
      code           = configReader["indelAnnotator"]["code"]
      dbConfigFile   = configReader["indelAnnotator"]["dbConfigFile"]
    end

    cmdPrefix = howToRun + " " + codeDir + "/" + code
    @cmdToRun = cmdPrefix + " " + @vcfFile.to_s + " " + dbConfigFile

    pileupFile = findPileupFile()

    if pileupFile != nil
      @cmdToRun = @cmdToRun + " " + pileupFile.to_s
    end

    puts "Command to annotate " + @action
    puts @cmdToRun.to_s
  end

  # Helper method to consume the output of annotation command and build
  # annotated VCF files
  def buildAnnotationToVCFCommandString(configReader)
    if @action.eql?("snp")
      howToRun    = configReader["snpAnnoToVCF"]["starter"]
      codeDir     = configReader["snpAnnoToVCF"]["codeDirectory"]
      code        = configReader["snpAnnoToVCF"]["code"]
    else
      howToRun    = configReader["indelAnnoToVCF"]["starter"]
      codeDir     = configReader["indelAnnoToVCF"]["codeDirectory"]
      code        = configReader["indelAnnoToVCF"]["code"]
    end
    cmdPrefix = howToRun + " " + codeDir + "/" + code
    @cmdToRun = cmdPrefix + " " + @vcfFile.to_s + " " + findAnnotatedOutputFile() + 
                " " + findAnnotatedMetaFile() + " " + getOutputFileName()
  end

  def buildVCFanalyzerCommandString(configReader)
    howToRun    = configReader["VCFanalyzer"]["starter"]
    codeDir     = configReader["VCFanalyzer"]["codeDirectory"]
    code        = configReader["VCFanalyzer"]["code"]
    cmdPrefix = howToRun + " " + codeDir + "/" + code
    libraryNameFromVCF = @vcfFile.gsub(/\.vcf$/, "") 
    @cmdToRun = cmdPrefix + " " + getOutputFileName() + ">" + libraryNameFromVCF + "_VCFanalyzer_results" + ".txt" 
  end

  # Execute the command
  def executeCmd()
    `#{@cmdToRun}`
    exitCode = $?

    if exitCode != 0
      handleError(@cmdToRun + " failed with error code : " + exitCode.to_s)
    end
  end

  # Method to handle the error and exit
  def handleError(errorMsg)
    obj            = ErrorMessage.new()
    obj.msgDetail  = errorMsg
    obj.msgBrief   = "Error while annotating " + @action
    obj.workingDir = Dir.pwd
    ErrorHandler.handleError(obj)
    exit -1
  end
end

obj = VariantAnnotatorWrapper.new(ARGV)
