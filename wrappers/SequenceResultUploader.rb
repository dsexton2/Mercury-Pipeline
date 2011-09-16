#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'PipelineHelper'
require 'EmailHelper'
require 'BWAParams'

# Class to upload the result metrics generated by CASAVA after sequences are
# generated. Run this from the same directory where sequence files and BWA
# config parameter file are present.
# Author: Nirav Shah niravs@bcm.edu

# Enumeration like to describe read type
class ReadType
  READ1 = 1
  READ2 = 2
end

# Lane barcode result for specified read type
class LaneResult

  # Class constructor
  def initialize(fcBarcode, readType,  isPaired, demuxBustardSummaryXML, demuxStatsHTM)
    @fcBarcode = fcBarcode
    @readType  = readType 
    @isPaired  = isPaired

    initializeDefaultParameters()
    getPhasingPrephasing(demuxBustardSummaryXML)
    getYieldAndClusterInfo(demuxStatsHTM)
  end

  # Method to get the result string for LIMS upload
  def getLIMSUploadString()
    result = @fcBarcode + " SEQUENCE_FINISHED " +  
             "READ " + @readType.to_s + " PERCENT_PHASING " + @phasing.to_s + 
             " PERCENT_PREPHASING " + @prePhasing.to_s + " LANE_YIELD_KBASES " +
             @yield.to_s + " CLUSTERS_PF " + @percentPFClusters.to_s

    return result
  end

  private

  # Put default values for results to upload to LIMS
  def initializeDefaultParameters()
    @phasing           = 0
    @prePhasing        = 0
    @yield             = 0
    @percentPFClusters = 0
  end

  # Read DemultiplexedBustardSummary.xml file and obtain values of phasing and
  # prephasing
  def getPhasingPrephasing(demuxBustardSummaryXML)
    laneNumber = @fcBarcode.slice(/-\d/)
    laneNumber.gsub!(/^-/, "")

    xmlDoc = Hpricot::XML(open(demuxBustardSummaryXML))

    (xmlDoc/:'ExpandedLaneSummary Read').each do|read|
     readNumber = (read/'readNumber').inner_html

      if readNumber.to_s.eql?(@readType.to_s)

        (read/'Lane').each do |lane|
          laneNum = (lane/'laneNumber').inner_html
 
          if laneNum.to_s.eql?(laneNumber.to_s)

            tmp = (lane/'phasingApplied').inner_html
            !isEmptyOrNull(tmp) ? @phasing = tmp : @phasing = 0
            tmp = (lane/'prephasingApplied').inner_html
            !isEmptyOrNull(tmp) ? @prePhasing = tmp : @prePhasing = 0
          end
        end
      end
    end
  end

  # Read Demultiplex_Stats.htm file and get values of yield, percent PF clusters
  # and raw clusters (TODO)
  def getYieldAndClusterInfo(demuxStatsHTM)
    doc = open(demuxStatsHTM) { |f| Hpricot(f) }

    table = (doc/"/html/body/div[@ID='ScrollableTableBodyDiv']").first

    rows = (table/"tr")
    rows.each do |row|
      dataElements = (row/"td")

      if dataElements[1].inner_html.eql?(@fcBarcode)
        # Convert yield from MBases to KBases and remove all comma characters
        @yield = dataElements[7].inner_html.gsub(",", "").to_i * 1000

        if @isPaired == true
          @yield = @yield / 2
        end

        @percentPFClusters = dataElements[8].inner_html
      end
    end
  end

  # Private helper method to check if the string is null / empty
  def isEmptyOrNull(value)
    if value == nil || value.eql?("")
      return true
    else
      return false
    end
  end
end

# Class to upload the result string to LIMS
class SequenceResultUploader
  # Class constructor, the parameter is a complete flowcell name (i.e. directory
  # name)
  def initialize()
    begin
      defaultInitializer()
      getFCBarcode()
      getResultFileNames()
      isPairedEnd()
    rescue Exception => e
      handleError(e.message)
      puts e.backtrace.inspect
    end
  end

  # Method to upload the results to LIMS
  def uploadResult()
    cmdPrefix  = "perl " + File.dirname(File.expand_path(File.dirname(__FILE__))) + 
                 "/lims_api/setIlluminaLaneStatus.pl"
    laneResult = LaneResult.new(@fcBarcode, "1", @pairedEnd, @demuxBustardSummaryXML,
                                @demuxStatsHTM) 

    uploadCmd  = cmdPrefix + " " + laneResult.getLIMSUploadString()
    executeUploadCmd(uploadCmd)

    if @pairedEnd == true
      laneResult = LaneResult.new(@fcBarcode, "2", @pairedEnd, @demuxBustardSummaryXML,
                                  @demuxStatsHTM)
      uploadCmd  = cmdPrefix + " " + laneResult.getLIMSUploadString()
      executeUploadCmd(uploadCmd)
    end
  end

  private
  
  # Default constructor
  def defaultInitializer()
    @fcBarcode              = nil
    @demuxBustardSummaryXML = nil
    @demuxStatsHTM          = nil
    @pairedEnd              = false
  end
    
  # Obtain flowcell barcode for the current sequence event
  def getFCBarcode()
    inputParams = BWAParams.new()
    inputParams.loadFromFile()
    @fcBarcode  = inputParams.getFCBarcode() # FCName-Lane-BarcodeName

    if @fcBarcode == nil || @fcBarcode.empty?()
      raise "FCBarcode cannot be null or empty"
    end
  end  

  # Get names of files containing CASAVA result data
  def getResultFileNames()
    resultDir               = File.dirname(File.dirname(File.expand_path(Dir.pwd)))
    @demuxBustardSummaryXML = resultDir + "/DemultiplexedBustardSummary.xml"

    baseCallsStatsDir       = Dir[resultDir + "/Basecall_Stats_*"]
    @demuxStatsHTM          = baseCallsStatsDir[0] + "/Demultiplex_Stats.htm"

    if !File::exist?(@demuxBustardSummaryXML)
      raise "File " + @demuxBustardSummaryXML + " does not exist or is unreadable"
    end

    if !File::exist?(@demuxStatsHTM)
      raise "File " + @demuxStatsHTM + " does not exist or is unreadable"
    end
    
  end

  # Check if a flowcell is paired-end or fragment
  def isPairedEnd()
    sequenceFiles = Dir["*_sequence.txt*"]
    
    if sequenceFiles.size < 2
      @pairedEnd = false
    else
      @pairedEnd = true
    end
  end

  # Upload the results to LIMS and check for errors
  def executeUploadCmd(cmd)
    puts "Executing command : " + cmd
    output = `#{cmd}`
    exitStatus = $?
    output.downcase!

    if output.match(/error/)
      puts "ERROR IN UPLOADING ANALYSIS RESULTS TO LIMS"
      puts "Error Message From LIMS : " + output
    elsif output.match(/success/)
      puts "Successfully uploaded to LIMS"
    end
    handleError("Error in upload sequence metrics to LIMS for " + @fcBarcode) 
  end

  # Handle error and abort.
  def handleError(msg)
    errorMessage = "Error while uploading sequence results to LIMS. Working Dir : " +
                    Dir.pwd + " Message : " + msg.to_s

    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error while uploading sequence results to LIMS" 

    obj.sendEmail(emailFrom, emailTo, emailSubject, errorMessage)
    puts errorMessage.to_s
    exit -1
  end
end

obj = SequenceResultUploader.new()
obj.uploadResult()
