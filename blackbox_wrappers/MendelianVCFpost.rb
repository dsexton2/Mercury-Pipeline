#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'yaml'
require 'PathInfo'
require 'ErrorHandler'
require 'BWAParams'

#Take INDEL VCF and SNP VCF along with BAM to generate metrics used for Mendelian projects

class MendelianVCFpost
     
   def initialize()    
     readConfigParams()
     yamlConfigFile = PathInfo::CONFIG_DIR + "/blackboxes_configuration.yml"
     configReader   = YAML.load_file(yamlConfigFile)
     runMendelianStats(configReader)
     executeCmd()
   end
    
   def runMendelianStats(configReader)
     indel_annotatedVCF = Dir["INDEL/*_Annotated.vcf"]
     snp_annotatedVCF = Dir["SNP/*_Annotated.vcf"]
     bam_file = Dir["*_realigned.bam"]

     if (indel_annotatedVCF[0] !=nil && indel_annotatedVCF[0].size > 0) &&  (snp_annotatedVCF[0] !=nil && snp_annotatedVCF[0].size > 0) && (bam_file[0] !=nil && bam_file[0].size > 0)  #All required files exist
       howToRun    = configReader["Mendelian_VCFpost"]["starter"]
       codeDir     = configReader["Mendelian_VCFpost"]["codeDirectory"]
       code        = configReader["Mendelian_VCFpost"]["code"]
     
       cmdPrefix = howToRun + " " + codeDir + "/" + code
       dir_name = "Mendelian"
       Dir.mkdir(dir_name) unless File.exists?(dir_name)
       @cmdToRun = cmdPrefix + " " + snp_annotatedVCF[0] + " " + indel_annotatedVCF[0] + " Mendelian/" + @sampleName + " " + bam_file[0] 
     end
   end
 
  # Read the configuration file containing input parameters
  def readConfigParams()
    inputParams = BWAParams.new()
    inputParams.loadFromFile()
    @sampleName = inputParams.getSampleName()
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
      obj = ErrorMessage.new()
      obj.msgDetail  = errorMsg
      obj.msgBrief   = "Error while generating Mendelian stats on annotated VCF "
      obj.workingDir = Dir.pwd
      ErrorHandler.handleError(obj)
      exit -1
    end 
   
end
obj = MendelianVCFpost.new
