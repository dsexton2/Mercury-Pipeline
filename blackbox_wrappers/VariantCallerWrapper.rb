#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'yaml'
require 'PathInfo'
require 'ErrorHandler'

# Class to encapsulate the command to generate two variants namely SNP and indel
# Author: Nirav Shah niravs@bcm.edu

class VariantCallerWrapper
  def initialize(cmdParams)
    parseCommandLineParameters(cmdParams)

    if @variantType.downcase.eql?("snp")
      buildSNPCommandString()
    else
      buildIndelCommandString() 
    end
    executeCmd()
  end

  private 
  # Method to parse the command line parameters. Since this wrapper is invoked
  # only by blackbox control script, it is guaranteed that the parameters are
  # always passed in the correct order, format. Hence, validation is not
  # required at this stage.
  def parseCommandLineParameters(cmdParams)
    @bamFile      = cmdParams[0]
    @reference    = cmdParams[1]
    @fcBarcode    = cmdParams[2]
    @sample       = cmdParams[3]
    @variantType  = cmdParams[4]
    @cmdToRun     = nil
  end

  # Helper method to build the command string to generate SNP
  def buildSNPCommandString()
    yamlConfigFile = PathInfo::CONFIG_DIR + "/blackboxes_configuration.yml"
    configReader   = YAML.load_file(yamlConfigFile)
    howToRun       = configReader["snpCaller"]["starter"]
    codeDir        = configReader["snpCaller"]["codeDirectory"]
    code           = configReader["snpCaller"]["code"]
    vipBedFile     = configReader["AtlasVIP"]["BEDfile"]

    cmdPrefix = howToRun + " " + codeDir + "/" + code
    snpCmd = cmdPrefix + " -i " + @bamFile.to_s + " -r " + @reference + 
              " -o " + @sample.to_s + ".SNPs -y 6 -s -n " +    #removed -v not needed option in new version AtlasVIP
              @sample.to_s + " -a " + vipBedFile
    puts "Command to run SNP "
    puts snpCmd.to_s
    @cmdToRun = snpCmd
  end

  # Helper method to build the command string to generate indels
  def buildIndelCommandString()
    yamlConfigFile = PathInfo::CONFIG_DIR + "/blackboxes_configuration.yml"
    configReader   = YAML.load_file(yamlConfigFile)
    howToRun       = configReader["indelCaller"]["starter"]
    codeDir        = configReader["indelCaller"]["codeDirectory"]
    code           = configReader["indelCaller"]["code"]
    vipBedFile     = configReader["AtlasVIP"]["BEDfile"]

    cmdPrefix = howToRun + " " + codeDir + "/" + code
    indelCmd  = cmdPrefix + " -b " + @bamFile.to_s + " -r " + @reference +
                " -s " + @sample + " -I " + "-o " + @sample + ".INDELs.vcf" + " -a " + vipBedFile
    puts "Command to run indel "
    puts indelCmd.to_s
    @cmdToRun = indelCmd
  end

  # Execute the command
  def executeCmd()
    `#{@cmdToRun}`
    exitCode = $?

    if exitCode != 0
      handleError("Return code : " + exitCode.to_s)
    end
  end

  # Helper method to send error email and exit
  def handleError(errorMsg)
    obj            = ErrorMessage.new()
    obj.workingDir = Dir.pwd
    obj.fcBarcode  = @fcBarcode

    if @variantType != nil
      obj.msgBrief = @variantType.upcase + " call command failed for " + @fcBarcode
    else
      obj.msgBrief = "Variant call command failed for " + @fcBarcode
    end
    obj.msgDetail  = errorMsg
    ErrorHandler.handleError(obj)
    exit -1
  end
end

obj = VariantCallerWrapper.new(ARGV)
