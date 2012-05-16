#!/usr/bin/ruby

#$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")
$:.unshift "/stornext/snfs5/next-gen/Illumina/ipipe/lib"
require 'Scheduler'

# Class to merge BAM files
# Author Nirav Shah niravs@bcm.edu
class BAMMerger
  # Class constructor - read list of input bam files to merge and the output
  # file name where to write the output to
  def initialize(inputList, outputFile)
    @inputBAMs = inputList
    @outputBAM = outputFile.strip
    @mergedBAM = outputFile.gsub(/\.[bs]am$/, "") + "_marked.bam"
    @outputDir = File::dirname(@outputBAM)

=begin
    inputList.each do |inputFile|
      @inputBAMs << inputFile.strip
    end
=end

    begin
      validateInputData()
      configurePaths()
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
      exit -1 
    end
  end

  # Run the commands to merge the BAMs
  def process()
    cmd = buildMergeCommand()
    puts "Running the Merge command"
    runCommand(cmd, "MergeBAM")
    cmd = buildMarkDupCommand()
    puts "Marking duplicates"
    runCommand(cmd, "MarkDups")
    cmd = buildMappingStatsCmd()
    puts "Calculating mapping stats"
    runCommand(cmd, "MappingStats") 
    puts "All done. Exiting..."
  end

  private 
  # Validate that the input data is correct, i.e., all files to merge exist and
  # are BAM / SAM files and output directory exists.
  def validateInputData()
    @inputBAMs.each do |inputFile|
      if !File::exist?(inputFile) || !File::file?(inputFile) || 
         !inputFile.match(/[bs]am$/)
         raise inputFile + " does not exist or is not a valid bam/sam file"
      end
    end

    outputDir = File.dirname(@outputBAM.to_s)
    if !File::directory?(outputDir)
      raise "Specified output directory : " + outputDir + " does not exist"
    end
  end

  # Helper method to configure settings needed by merge and other commands
  def configurePaths()
    # Directory hosting various custom-built jars
    @javaDir         = "/stornext/snfs5/next-gen/Illumina/ipipe/java"
    # Parameters for picard commands
    @picardPath       = "/stornext/snfs5/next-gen/software/picard-tools/current"
    @picardValStr     = "VALIDATION_STRINGENCY=SILENT"
    # Name of temp directory used by picard
    @picardTempDir   = "TMP_DIR=/space1/tmp"
    # Number of records to hold in RAM
    @maxRecordsInRam = 3000000
    # Maximum Java heap size
    @heapSize        = "-Xmx22G"
  end

  # Build the command to merge BAMs
  def buildMergeCommand()
    cmd = "java " + @heapSize + " -jar " + @picardPath + "/MergeSamFiles.jar "
 
   @inputBAMs.each do |inputFile|
     cmd = cmd + " I=" + inputFile.to_s
   end

   cmd = cmd + " O=" + @mergedBAM.to_s + " " +  @picardTempDir + " USE_THREADING=true " +
         " MAX_RECORDS_IN_RAM=" + @maxRecordsInRam.to_s + " " + @picardValStr +
         " AS=true 1>" + @outputDir + "/mergelog.o 2>" + @outputDir + "/mergelog.e"
   return cmd 
  end

  # Mark duplicates on a sorted BAM
  def buildMarkDupCommand()
    cmd = "java " + @heapSize + " -jar " + @picardPath + "/MarkDuplicates.jar I=" +
          @mergedBAM + " O=" + @outputBAM + " " + @picardTempDir + " " +
          "MAX_RECORDS_IN_RAM=" + @maxRecordsInRam.to_s + " AS=true M=metrics.foo " +
          @picardValStr  + " 1>markDups.o 2>markDups.e"
    return cmd
  end

  # Method to build command to calculate mapping stats
  def buildMappingStatsCmd()
    jarName = @javaDir + "/BAMAnalyzer.jar"
    cmd = "java " + @heapSize + " -jar " + jarName + " I=" + @outputBAM +
          " O=" + @outputDir + "/BWA_Map_Stats.txt X=" + @outputDir +
          "/BAMAnalysisInfo.xml " + "1>" + @outputDir + "/mappingStats.o" +
          " 2>" + @outputDir + "/mappingStats.e" 
    return cmd
  end

  # Method to run the specified command
  def runCommand(cmd, cmdName)
    startTime = Time.now
    `#{cmd}`
    endTime   = Time.now
    returnValue = $?
    displayExecutionTime(startTime, endTime)

    if returnValue != 0
      handleError(cmdName)
    end
  end

  # Display execution time as the difference between start time and end time
  def displayExecutionTime(startTime, endTime)
    timeDiff = (endTime - startTime) / 3600
    puts "Execution time : " + timeDiff.to_s + " hours"
  end

  # Method to handle error. Current behavior, print the error stage and abort.
  # TODO:
  def handleError(commandName)
    puts "ERROR : OOPS Error occurred in " + commandName.to_s
  end
end
