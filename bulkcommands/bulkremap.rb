#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PathInfo'

# Script to perform remap operations in bulk. It requires an input file
# containin the list of directories where we need to remap the data. Each line
# of the file should contain one directory. The second parameter should be new
# reference path and the third optional parameter should be chip design.
# Author: Nirav Shah niravs@bcm.edu
# Usage : ruby bulkremap.rb dirListFile referenecePath chipDesign
# e.g. ruby bulkremap.rb list.txt /stornext/snfs0/hgsc-refs/Illumina/bwa_references/h/hg19/original/hg19.fa  /users/p-illumina/vcrome2.1_hg19

directoryList    = IO.readlines(ARGV[0])
newReferenceName = ARGV[1]

chipDesignName = nil

if ARGV.length >= 3
  chipDesignName = ARGV[2]
end

currDir = Dir.pwd
index = 1
directoryList.each do |geraldDirectory|
  puts "In directory : " + geraldDirectory.to_s
  geraldDirectory.strip! 

  Dir.chdir(geraldDirectory)

  if !File::exist?("BWAConfigParams.txt")
    puts "Did not find BWAConfigParams file in dir " + geraldDirectory.to_s
  else
    configFileLines = IO.readlines("BWAConfigParams.txt")

    newFile = File.open("BWAConfigParams_temp.txt", "w") 
    configFileLines.each do |line|
      if line.match(/REFERENCE_PATH/)
        newFile.puts "REFERENCE_PATH=" + newReferenceName
      elsif chipDesignName != nil && !chipDesignName.empty?() && line.match(/CHIP_DESIGN/)
        newFile.puts "CHIP_DESIGN=" + chipDesignName.to_s  
      else
        newFile.puts line
      end
    end
    newFile.close

    #Replace the original BWAConfigParams.txt file
    cmd = "mv BWAConfigParams_temp.txt BWAConfigParams.txt"
    `#{cmd}`

    sleep 10

    cmd = "rm -rf capture_stats"
    `#{cmd}`

    puts "Current Directory : " + Dir.pwd
    cmd = "ruby " + PathInfo::BIN_DIR + "/Aligner.rb"
    puts "Executing command : " + cmd.to_s
    output = `#{cmd}`
    puts output

    sleep 20
  end 
  index = index + 1
  puts "Index = " + index.to_s
  Dir.chdir(currDir)
end
