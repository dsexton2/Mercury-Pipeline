#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

# This script searches for all new flowcells that have finished copying and
# analysis has not been started for them. On finding a "new" flowcell, it starts
# the analysis. It also adds this flowcell's name to done_list.txt (in instrument
# directory). This prevents the same flowcell from being analyzed multiple
# times.
# Author: Nirav Shah niravs@bcm.edu
 
require 'asshaul.rb'
require 'fileutils'
require 'PipelineHelper.rb'
require 'PathInfo'
require 'ErrorHandler'

# Class to automatically start the flowcells. It runs as part of a crontab job.
# On detecting that a flowcell has copied, it starts the analysis automatically.
# It searches for each child directory (corresponding to an instrument
# directory) in the base directory passed to this class. To change the search
# volume, change the parameter passed to this class's constructor.
#
# Author: Nirav Shah niravs@bcm.edu

class AnalysisStarter
  def initialize()
    initializeMembers()

    baseDir = PipelineHelper.getInstrumentRootDir()

    # ATTEmpt to obtain the lock, if another instance of this program is
    # running, this operation will fail. Print a suitable message and exit.
    if !@lock.try_to_lock
      puts "Another instance of this program is running. Exiting..."
      obj = ErrorMessage.new()   #Added May 15, 2012. File system outage caused lock_startAnalysis.lock not to be deleted
      obj.workingDir = Dir.pwd   #during @lock.unlock command at line 62. This prevented this script from running. Added email notification to team if reoccurs  
      obj.msgBrief = "MAJOR Error in iPipeV2 - Must ACT for analysis to continue for ALL flowcells"
      obj.msgDetail = "File " + File.dirname(__FILE__) + "/lock_startAnalysis.lock" + " must be deleted for the cronjob to work. The cronjob calls the script startAnalysis.rb. The cause is most likely  a file system outage. The script " + File.dirname(__FILE__) + "/startAnalysis.rb" + " does erase the .lock file, however a file system outage could prevent that from happening. If the .lock file exists then the pipleine assumes a cronjob instance is running at that exact moment and will not kick off another instance of startAnalysis.rb" 
      ErrorHandler.handleError(obj)
      exit 0
    end
    
    baseDir.each do |baseDirAll|        #Iterate through BluArc and Stornext FS. baseDir is an array containing multiple Instrument DIR mount points
      buildInstrumentList(baseDirAll)
      puts "Root directory to look for new flowcells : " + baseDirAll
    
      @instrList.each do |instrName|    
        puts "Checking for new flowcells for sequencer : " + instrName.to_s
        @instrDir = baseDirAll + "/" + instrName.to_s

        puts "Directory : " + @instrDir.to_s
        buildAnalyzedFCList()
        findNewFlowcells()

        @newFC.each do |fcName|
          if fcReady?(fcName) == true
            updateDoneList(fcName)
            processFlowcell(fcName)
          end
        end
      end
    end

    # Release the lock to allow another instance of this program to run.
    @lock.unlock
    #end
  end

private
  def initializeMembers()
    @instrDir  = ""                   # Directory of instrument
    @instrList = ""                   # List of instruments
    @fcList    = nil                  # Flowcell list
    @completedFCLog = "done_list.txt" # List of flowcells analyzed
    @newFC     = Array.new            # Flowcell to analyze
    @instrList = Array.new

    # Create a new lock - this acts like a Singleton pattern for this program.
    # The lock is a file "lock_$filename" in the directory where this code
    # lives.  It is used to prevent multiple instance of this program from
    # running at the same time.
    @lock      = Locker.new(File.dirname(__FILE__) + "/lock_startAnalysis.lock")
  end

  # Method to build a list of instruments
  def buildInstrumentList(baseDir)
    entries = Dir[baseDir + "/*"] 

    @instrList = Array.new

    entries.each do |entry|
      if !entry.eql?(".") && !entry.eql?("..") &&
         File::directory?(entry)

         @instrList << entry.slice(/[a-zA-Z0-9]+$/).to_s
      end
    end
  end

  # Build a hashtable of flowcells for which analysis was already started
  def buildAnalyzedFCList()
    logFile = @instrDir + "/" + @completedFCLog
    puts logFile
    @fcList = nil
    @fcList = Hash.new()
 
    if File::exist?(logFile)
      lines = IO.readlines(logFile)

      if lines != nil && lines.length > 0
        lines.each do |line|
          @fcList[line.strip] = "1"
        end 
      end
    else
       # If this directory is newly created and it does not have the log of
       # completed flowcells, create this file.
       cmd = "touch " + logFile
       `#{cmd}`
    end
  end

  # Find flowcells for which analysis is not yet started. Read the directory
  # listing under the instrument directory, compare directories against the list
  # of completed flowcells and find the directories (flowcells) that are new.
  def findNewFlowcells()
    @newFC = Array.new

    dirList = Dir.entries(@instrDir)

    dirList.each do |dirEntry|
      if !dirEntry.eql?(".") && !dirEntry.eql?("..") &&
         File::directory?(@instrDir + "/" + dirEntry) &&
         !@fcList.key?(dirEntry.strip)
         @newFC << dirEntry
      end
    end      
  end

  # Accurate as of 26th Sept 2011:
  # Every HiSeq flowcell running RTA version 1.12 that is copied directly to the
  # cluster will have a marker file RTAComplete.txt written at the end of copy
  # operation. On finding this file, we add another marker file .rsync_finished.
  # In this case, this flowcell will be picked up for analysis in the next
  # iteration of cron job.

  # For GAIIx flowcells running RTA version 1.9, RTAComplete.txt is not written.
  # However, we can assume that all GAIIx flowcells are paired-end, and look for
  # the following files 
  # Basecalling_Netcopy_complete.txt,
  # Basecalling_Netcopy_complete_READ1.txt
  # Basecalling_Netcopy_complete_READ2.txt
  # If these files are copied more than an hour ago, return true, which enables
  # the pipeline to start the analysis on this flowcell.
  def fcReady?(fcName)
    fcDir = @instrDir + "/" + fcName
    puts "FCDir : " + fcDir.to_s
    if File::exist?(fcDir + "/.rsync_finished")
      return true
    end
   
    # The pipeline does not automatically pick up any flowcell from sequencer
    # 700601 (or SN601) for analysis. This is because Rui Chen's flowcells are 
    # periodically loaded on 601. Current approach (16th Dec 2011) is to
    # monitor the run finished emails from LIMS and insert the marker
    # file ".rsync_finished" in the flowcell's directory. This will enable the
    # pipeline to pick it up for analysis.
    # However, please comment the following if block (4 lines) if the pipeline
    # must auto pick up all flowcells on 601. In this case, when Rui Chen's
    # flowcells are picked up, an error will occur while trying to contact LIMS
    # and an email will be sent. However. all HGSC flowcells on this sequencers
    # should be picked up properly.
    #if fcName.match(/SN601/) 
    #   puts "Flowcell " + fcName + " is not configured for automatic analysis"
    #   return false
    #end

    # If the marker file RTAComplete.txt was written more than 1 hour ago, then
    # add the new marked file and return.
    if File::exist?(fcDir + "/RTAComplete.txt")
      cmd = "touch " + @instrDir + "/" + fcName + "/.rsync_finished"
      `#{cmd}`
    else
       rtaVersion = PipelineHelper.findRTAVersion(fcName) 

       if rtaVersion != nil && rtaVersion.match(/1\.9/)
         puts "Flowcell with RTA version 1.9 found : " + fcName

         if File::exist?(fcDir + "/Basecalling_Netcopy_complete.txt") &&
            File::exist?(fcDir + "/Basecalling_Netcopy_complete_READ1.txt") &&
            File::exist?(fcDir + "/Basecalling_Netcopy_complete_READ2.txt") 
 
            modificationTime = Time.now - File::mtime(fcDir + "/Basecalling_Netcopy_complete.txt")
            puts "Mod time : " + modificationTime.to_s
            if modificationTime >= 3600
              return true
            else
              return false
            end
         else
           return false
         end
       end
    end
    return false
  end

  # Add the entry of the flowcell to "done" list so that it won't be processed
  # more than once.
  def updateDoneList(fcName)
    logFileName = @instrDir + "/" + @completedFCLog
    logFile = File.new(logFileName, "a")
    puts "Adding to log : " + logFileName + " FC : " + fcName.to_s
    logFile.puts fcName
    logFile.close 
  end

  # Start the analysis for the flowcell. 
  def processFlowcell(fcName)
    puts "Starting analysis for flowcell : " + fcName.to_s
    currDir = Dir.pwd
    Dir::chdir(PathInfo::BIN_DIR)
    cmd = "ruby PreProcessor.rb  fcname=" + fcName.to_s + " action=all"
    puts "Running command : " + cmd.to_s
    output = `#{cmd}`
    puts output
    Dir::chdir(currDir)
  end

end




obj = AnalysisStarter.new()
