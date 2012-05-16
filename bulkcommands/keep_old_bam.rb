#!/usr/bin/ruby

# the input is a file name which contains a list of result directories.
dirList = IO.readlines(ARGV[0])
currDir = Dir.pwd

dirList.each do |dir|
  Dir.chdir(dir.strip)
  bam = Dir["*.bam"]
  oldName = bam[0]
  puts oldName + " " + dir


  # Within the result directory, create another directory. For this time we
  # name it hg18_bam and move the existing bam there.
  newDir = "hg18_bam"
  Dir.mkdir(newDir)
  cmd = "mv " + oldName + " ./" + newDir
  output = `#{cmd}`
  puts output
  Dir.chdir(currDir)  
  end
 
