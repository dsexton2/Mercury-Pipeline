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
end


listFile = ARGV[0]

flowcellList = IO.readlines(listFile)

flowcellList.each do |fc|
  puts "Cleaning Flowcell : " + fc.to_s
  obj = CleanFlowcell.new(fc.strip)
end
