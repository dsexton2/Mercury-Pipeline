#!/usr/bin/ruby

# Tool to delete intermediate files from flowcells.
# It deletes the position files form the ./Data/Intensities directory, unwanted 
# files from the basecalls directory
# Please use this only for flowcells processed with CASAVA 1.8
# Author Nirav Shah niravs@bcm.edu

class CleanFlowcell
  def initialize(fcName)
      puts "To Clean : " + fcName
 #     if File.directory?(fcName) && !fcName.eql?(".") &&
 #        !fcName.eql?("..")
        pwd = Dir.pwd
        puts "PWD = " + pwd.to_s
 
        Dir.chdir(fcName)

        puts "Dir now : " + Dir.pwd

        if File.exists?("./Data")
          puts "Found data directory. Time to remove unwanted files"
          cleanIntensityDir()
          cleanBaseCallsDir()
        else
          puts fcName + " does not have data directory"
        end

        if File.exists?("./Thumbnail_Images")
          puts "Cleaning Thumbnail images"
          cleanThumbnailDir()
        end
        
	puts "Cleaning casava_fastq directories in each sample folder."
	cleanCasavaFastq()
	
	puts "Cleaning large files left over by Mercury GATK and SNP and INDEL calling components"
	cleanMurcuryExcess(fcName)
	
	puts "Completed cleaning " + fcName
        puts ""
        Dir.chdir(pwd)
 #     end
  end

  private

  def cleanThumbnailDir()
    cmd = "rm -rf Thumbnail_Images"
    `#{cmd}`
  end

  def cleanIntensityDir()
    puts "Cleaning intensity directory"
    rmintensityFilesCmd = "rm ./Data/Intensities/*_pos.txt"
    output = `#{rmintensityFilesCmd}`
    puts output

    rmLanesDirCmd = "rm -rf ./Data/Intensities/L00*"
    output = `#{rmLanesDirCmd}`
    puts "Intensity files cleaned"
  end

  def cleanBaseCallsDir()
    puts "Cleaning basecalls directory"
    rmFilterFilesCmd = "rm ./Data/Intensities/BaseCalls/*.filter"
    output = `#{rmFilterFilesCmd}`

    # If a flowcell was run with CASAVA 1.7 bcl to qseq generation (for
    # additional) analysis, it might have qseq files. Hence, we retain the code
    # to remove qseq files.
    puts "Removing qseq files"
    rmQseqFilesCmd = "rm ./Data/Intensities/BaseCalls/*_qseq.txt"
    output = `#{rmQseqFilesCmd}`

    puts "Removing lane directories (NOT GERALD)"
    rmLanesDirCmd = "rm -rf ./Data/Intensities/BaseCalls/L00*"
    output = `#{rmLanesDirCmd}`
    puts "BaseCalls directory cleaned"
#    cleanDemultiplexedDirs()
  end
 
  def cleanCasavaFastq()
    cmd = "find ./Results/Project* -type d -name casava_fastq -exec rm -rf {} \\;"
    puts "Running command: " + cmd 
    output = `#{cmd}`
    puts output
  end

  def cleanMurcuryExcess(fcName)
    projectDIR = Dir["Results/Project_*"]
    fcResults = fcName + "/" + projectDIR[0]
    Dir.chdir(fcResults)
    puts "Inside Results DIR : " + Dir.pwd
    samplesInFlowCell = Dir['*/']
    samplesInFlowCell.each do |x| 
      Dir.chdir(x)
      @GATKraligned_BAM_FILE = Dir["*_realigned.bam"]
      @BWA_BAM_FILE = Dir["*_marked.bam"]
      @BWA_BAM_INDEX = Dir["*_marked.bam.bai"]
      if @BWA_BAM_FILE != nil && (@BWA_BAM_FILE.size > 0) && (@GATKraligned_BAM_FILE !=nil) && (@GATKraligned_BAM_FILE.size > 0)
      #Found Both BWA BAM and GATK realined BAM. Remove BWA BAM and the BAM index 
        cmd = "rm -f " + File.expand_path(@BWA_BAM_FILE[0])
        puts "Removing BWA BAM because GATK BAM exists. Command:  " + cmd
	output = `#{cmd}`
	puts output
        runRemoveCommand(File.expand_path(@BWA_BAM_INDEX[0])) if (@BWA_BAM_INDEX[0] !=nil && @BWA_BAM_INDEX[0].size > 0)
      
      end
      pileUp = Dir["*.pileup"]
      intervals = Dir["*.intervals"]
      rawAtlasSNPvcf = Dir["SNP/*.SNPs"]
      recalBAMfile = Dir["*_marked.recal.bam"]
      recalBAMfileBAI = Dir["*_marked.recal.bai"]
   
      runRemoveCommand(File.expand_path(pileUp[0])) if (pileUp[0] !=nil && pileUp[0].size > 0)
      runRemoveCommand(File.expand_path(intervals[0])) if (intervals[0] !=nil && intervals[0].size > 0)
      runRemoveCommand(File.expand_path(rawAtlasSNPvcf[0])) if (rawAtlasSNPvcf[0] !=nil && rawAtlasSNPvcf[0].size > 0)
      runRemoveCommand(File.expand_path(recalBAMfile[0])) if (recalBAMfile[0] !=nil && recalBAMfile[0].size > 0)
      runRemoveCommand(File.expand_path(recalBAMfileBAI[0])) if (recalBAMfileBAI[0] !=nil && recalBAMfileBAI[0].size > 0)
      Dir.chdir(fcResults)
    end
  end

  def runRemoveCommand(filename)
    runCommand = "rm -f " + filename
    #puts "Executing: " + runCommand
    system(runCommand)
  end


end


listFile = ARGV[0]

flowcellList = IO.readlines(listFile)

flowcellList.each do |fc|
  puts "Cleaning Flowcell : " + fc.to_s
  obj = CleanFlowcell.new(fc.strip)
end
