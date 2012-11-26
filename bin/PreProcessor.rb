#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'FlowcellDefinitionBuilder'
require 'ErrorHandler'
require 'AnalysisInfo'
require 'BarcodeDefinitionBuilder'
require 'PathInfo'
require 'LimsInfo'

# Class to prepare the flowcell for analysis.
# Author: Nirav Shah niravs@bcm.edu

class PreProcessor
  def initialize(cmdParams)
    initializeDefaultParams()
    parseCommandString(cmdParams)

    begin
      @baseCallsDir = PipelineHelper.findBaseCallsDir(@fcName)

      if @buildFCDefinition == true
         puts "Creating definition file for flowcell : " + @fcName.to_s
         createFlowcellDefinitionXML()
      end

      if @uploadStartDate == true
        puts "Uploading analysis start date"
        uploadAnalysisStartDate()      
      end

      if @buildBarcodeDefn == true
         puts "Building local copy of barcode definition"
         buildBarcodeDefinitionFile()
      end

      if @buildSampleSheet == true
         puts "Writing SampleSheet.csv"
         buildSampleSheet()
      end

      if @runNextStep == true
         puts "Starting BCL -> FastQ Generator"
         startBCLToFastQConversion()
      end

    rescue Exception => e
      $stderr.puts "Exception occurred while pre-processing flowcell : " + @fcName.to_s
      $stderr.puts e.message
      $stderr.puts e.backtrace.inspect
      handleError(e.message)
      exit -1
    end
  end

  private
  # Parse the command string and validate the command line arguments
  def parseCommandString(cmdParams)
    cmdParams.each do |entry|
      line = entry.dup
      line.strip!
      if line.match(/fcname=/)
        @fcName = line.gsub(/fcname=/,"")      
      elsif line.eql?("action=all")
        @buildFCDefinition = true
        @uploadStartDate   = true
        @buildSampleSheet  = true
        @buildBarcodeDefn  = true
        @runNextStep       = true
      elsif line.eql?("action=build_fc_defn")
        @buildFCDefinition = true
      elsif line.eql?("action=upload_start_date")
        @uploadStartDate   = true
      elsif line.eql?("action=build_sample_sheet")
        @buildSampleSheet  = true
      elsif line.eql?("action=build_barcode_defn")
        @buildBarcodeDefn  = true
      elsif line.eql?("action=run_next_step")
        @runNextStep       = true
      end
    end

    if @fcName == nil || (@buildFCDefinition == false && @buildSampleSheet ==
       false && @uploadStartDate == false && @buildBarcodeDefn == false &&
       @runNextStep == false)
       printUsage()
       exit -1
    end
  end

  def initializeDefaultParams()
    @fcName            = nil   # Flowcell name
    @baseCallsDir      = nil   # BaseCalls dir of the flowcell

    # List of potential actions to perform
    @buildFCDefinition = false # Create FCDefinition.xml in BaseCalls dir
    @buildSampleSheet  = false # Create SampleSheet.csv in BaseCalls dir
    @uploadStartDate   = false # Upload analysis start date to LIMS
    @buildBarcodeDefn  = false # Create a local copy of barcode defn file
    @runNextStep       = false # Whether to run the next step (BCL->FastQ)
  end

  # Contact LIMS and write an XML file having necessary information to start the
  # analysis. This is a temporary functionality until LIMS can provide this XML.
  def createFlowcellDefinitionXML()
#    obj = FlowcellDefinitionBuilder.new(@fcName, @baseCallsDir)

    outputFile = @baseCallsDir + "/FCDefinition.xml"
    outLog     = @baseCallsDir + "/fcPlanDownloader.o"
    errLog     = @baseCallsDir + "/fcPlanDownloader.e"

    # MiSeq depends on cartridge ID and not flowcell ID. Pipeline can use cartridge ID
    # but needs to be parsed correctly. MiSeq instruments cartridge ID and run folders
    # have suffix ID 00300 but in LIMS suffix is stored as 300 as flowcell ID. Following code removes 2 zeros 
    # This code snippet was not placed in PipelineHelper.formatFlowcellNameForLIMS as many other scripts rely on it.
    # It is only in PreProcessor.rb that we have to address this. The rest of pipeline calls PipelineHelper.formatFlowcellNameForLIMS
    # in its native form and works well.
    limsFCName = PipelineHelper.formatFlowcellNameForLIMS(@fcName)
    if limsFCName.match(/[a-zA-Z0-9]+-00[0-9]+/)   # For MiSeq v1
       limsFCName.gsub!(/-00/, "-")
    end 

    #if limsFCName.match(/-\d00V2/)         #For MiSeq V2
    #   limsFCName.gsub!(/00V2/, "00v2")
    #end                                    #Illumina updated the cartridge IDs to UPPERCASE. No need to change to uppercase here

    cmd = "java -jar " + PathInfo::LIMS_API_DIR + "/FlowcellPlanDownloader.jar" +
          " " + LimsInfo::LIMS_DB_NAME + " " + limsFCName +
          " " + outputFile + " 1>" + outLog + " 2>" + errLog
    puts "Executing command to download flowcell plan"
    output = `#{cmd}`
    returnCode = $?

    if !File::exist?(outputFile) || (returnCode != 0)
      raise outputFile + " not created"
    end

    f = File.new(outputFile)
    text = f.read           #Must re-write bottom code.. No test env is setup for MiSeq at this time
    if text =~ /300-1-/ || text =~ /\d00V2-/ then
       removeMiseqCartridge = File.read(outputFile) 
       replace = removeMiseqCartridge.gsub(/Name="300-1-/, 'Name="1-')
       File.open(outputFile, "w") { |file| file.puts replace }
       removeMiseqCartridge = File.read(outputFile)
       replace2 = removeMiseqCartridge.gsub(/ID="300-1-/, 'ID="1-')
       File.open(outputFile, "w") { |file| file.puts replace2 }
       removeMiseqCartridge = File.read(outputFile)
       replace3 = removeMiseqCartridge.gsub(/ID="\d00V2-1-/, 'ID="1-')
       File.open(outputFile, "w") { |file| file.puts replace3 }
       removeMiseqCartridge = File.read(outputFile)
       replace4 = removeMiseqCartridge.gsub(/Name="\d00V2-1-/, 'Name="1-')
       File.open(outputFile, "w") { |file| file.puts replace4 }
    end

  end  

  # Helper method to upload analysis start date to LIMS for tracking purposes
  def uploadAnalysisStartDate()
    fcNameForLIMS = PipelineHelper.formatFlowcellNameForLIMS(@fcName)
    if fcNameForLIMS.match(/-[0]+\d[0]+/)         #For MiSeq v1
      fcNameForLIMS.gsub!(/-00/, "-")
    end 

    #if fcNameForLIMS.match(/-\d00V2/)         #For MiSeq V2
    #  fcNameForLIMS.gsub!(/00V2/, "00v2")
    #end                                     #Illumina updated the cartridge IDs to UPPERCASE. No need to change to uppercase here

    limsScript = PathInfo::LIMS_API_DIR + "/setFlowCellAnalysisStartDate.pl"

    uploadCmd = "perl " + limsScript + " " + fcNameForLIMS
    output = `#{uploadCmd}`
   
    if output.match(/[Ee]rror/)
      puts "Error in uploading Analysis Start Date to LIMS"
    else
      puts "Successfully uploaded Analysis Start Date to LIMS"
    end
  end

  # Create a local copy of barcode tag names and their sequences in the
  # BaseCalls directory of the flowcell. This will be used to create
  # SampleSheet.csv for demultiplexing the reads.
  def buildBarcodeDefinitionFile()
    laneBarcodes = AnalysisInfo.getBarcodeList(@baseCallsDir + "/FCDefinition.xml")

    if laneBarcodes == nil
      raise "Did not find any lane barcodes in FCDefinition.xml file"
    end
    BarcodeDefinitionBuilder.writeBarcodeMapFile(@baseCallsDir, laneBarcodes)
  end

  # Write SampleSheet.csv in the BaseCalls directory of the flowcell.
  def buildSampleSheet()
    laneBarcodes = AnalysisInfo.getBarcodeList(@baseCallsDir + "/FCDefinition.xml")

    formattedFCName = PipelineHelper.formatFlowcellNameForLIMS(@fcName)

    outFile = File.new(@baseCallsDir + "/SampleSheet.csv", "w")
    headerLine = "flowcell,lane,sample,reference,index,description," +
                 "control,recipe,operator,project"
    outFile.puts(headerLine)

    laneBarcodes.each do |laneBC|
      laneNum   = laneBC.slice(/^\d/)               # Lane number without barcode
      fcBarcode = formattedFCName + "-" +           # Flowcell name in LIMS
                  laneBC.to_s

      if fcBarcode.match(/-[0]+\d[0]+/)         #For MiSeq
        fcBarcode.gsub!(/-00/, "-")
      end 

      #if fcBarcode.match(/-\d00V2/)         #For MiSeq V2
      #  fcBarcode.gsub!(/00V2/, "00v2")
      #end                                  #Illumina updated the cartridge IDs to UPPERCASE. No need to change to uppercase here
      
      # Remove the lane name from lane barcode
      if laneBC.match(/^\d$/)
        bcName    = laneBC.gsub(/^\d/,"")          # Barcode name without lane
      else
        bcName    = laneBC.gsub(/\d-/,"")
      end

      if bcName == nil || bcName.empty?()
        indexSeq = ""                               # Actual index sequence
      else
        indexSeq  = BarcodeDefinitionBuilder.findBarcodeSequence(@baseCallsDir, bcName)
      end

      line = @fcName + "," + laneNum.to_s + "," + fcBarcode + ",sequence," +
             indexSeq + ",desc,n,r1,fiona," + @fcName
      outFile.puts line
    end
    outFile.close()
  end

  # Method to start the next step of the pipeline - BCL -> FastQ conversion
  def startBCLToFastQConversion()
    cmd = "ruby " + PathInfo::BIN_DIR + "/BclToFastQConvertor.rb " +
          "fcname=" + @fcName.to_s
    output = `#{cmd}`
  end

  # Show usage information
  def printUsage()
    puts "Script to prepare the flowcell for analysis"
    puts ""
    puts "Usage:"
    puts ""
    puts "ruby " + __FILE__ + " fcname=value action=value action=value..."
    puts ""
    puts "fcname      - full flowcell name"
    puts "action      - List of actions to perform - Allowed values : "
    puts "  build_fc_defn      : Write FCDefinition.xml in BaseCalls dir"
    puts "  upload_start_date  : Upload analysis start date to LIMS"
    puts "  build_sample_sheet : Write SampleSheet.csv in BaseCalls dir"
    puts "  build_barcode_defn : Write a local copy of barcode names and their"
    puts "                       sequences in BaseCalls dir"
    puts "  run_next_step      : Automatically runs the next step of the pipeline"
    puts "                       i.e. Create Results directory and run bclToFastQ"
    puts "  all                : Do all of the above"
    puts ""
    puts "Note : For regular use, provide action=all"
    puts "       Use specific actions only for debugging or running parts of the"
    puts "       pipeline manually."
 end

  # Handle the error and perform appropriate action.
  def handleError(msg)
    obj            = ErrorMessage.new()
    obj.msgDetail  = msg
    obj.msgBrief   = "Error in pre-processing flowcell " + @fcName.to_s
    obj.workingDir = Dir.pwd
    ErrorHandler.handleError(obj)
    exit -1
  end
end

cmdParams = ARGV
obj = PreProcessor.new(cmdParams)
