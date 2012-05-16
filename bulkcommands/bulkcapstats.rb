#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PathInfo'

# Script to calculate capture stats on a bulk of directories. The input should
# be two parameters. The first parameter is the filename containing the list of
# directories for which capture stats should be run. The second is chip design
# name without "/users/p-illumina"
# Author: Nirav Shah niravs@bcm.edu

# Put the correct file name here
dirList = IO.readlines(ARGV[0])

# Put the correct chip design here, don't add /users/p-illumina
chipDesign = ARGV[1]

currDir = Dir.pwd
index = 1

dirList.each do |dirEntry|
  nextDir = dirEntry.strip
  Dir.chdir(nextDir.to_s)
  puts "Curr Dir : " + Dir.pwd
  cmd  = "ls *_marked.bam"
  bamName = `#{cmd}`
  bamName.strip!
  
  # delete existing capture stats directory if it exists
  delCapStatsDirCmd = "rm -rf capture_stats"
  `#{delCapStatsDirCmd}`

  # Update the BWAConfigParams file to have the new value of chip design
  if File::exist?("BWAConfigParams.txt")

    configFileLines = IO.readlines("BWAConfigParams.txt")
    newFile = File.open("BWAConfigParams_temp.txt", "w")

    configFileLines.each do |line|
      if !line.match(/CHIP_DESIGN/)
        newFile.puts line
      end
    end

    newFile.puts "CHIP_DESIGN=/users/p-illumina/" + chipDesign.to_s
    newFile.close

    #Replace the original BWAConfigParams.txt file
    cmd = "mv BWAConfigParams_temp.txt BWAConfigParams.txt"
    `#{cmd}`
  end

  capStatsCmd = "ruby " + PathInfo::BLACK_BOX_DIR + "/CaptureStats.rb " +
                bamName.to_s + " " + chipDesign.to_s
  puts "running : " + capStatsCmd.to_s
  obj = Scheduler.new("Capstats_" + index.to_s, capStatsCmd)
  obj.setMemory(28000)
  obj.setNodeCores(4)
  obj.setPriority("high")
  obj.runCommand()
  jobName = obj.getJobName()
  puts jobName 
  index = index + 1
  Dir.chdir(currDir)
end
