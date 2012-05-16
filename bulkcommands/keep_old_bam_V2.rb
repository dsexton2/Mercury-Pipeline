#!/usr/bin/ruby

def usage
  puts "Usage:"
  puts "#{$0} <file with analysis dirs> <directory_name>"
  exit 1
end

usage if ARGV.size != 2
dirs_file, dir_name = ARGV

# the input is a file name which contains a list of result directories.
dirList = IO.readlines(dirs_file)
currDir = Dir.pwd

dirList.each do |dir|
  Dir.chdir(dir.strip)
  # Find the files we want to copy to the new dir
  bam = Dir["*.bam"]
  bwa_stats = Dir["BWA*"]
  cap_stats = Dir["capture_stats/cap_stats*.csv"]
  oldName = bam[0]
  puts oldName + " " + dir

  # Within the result directory, create another directory. For this time we
  # name it hg18_bam and move the existing bam there.
  newDir = dir_name
  #Dir.mkdir(newDir)
  cmd = "mkdir #{newDir}; mv " + oldName + " ./" + newDir
  cmd2 = []; bwa_stats.each {|f| cmd2 << "cp #{f} #{newDir}/"}
  cmd3 = []; cap_stats.each   {|f| cmd3 << "cp #{f} #{newDir}/"}

  puts "#{cmd}"
  puts "#{cmd2.join(';')}"
  puts "#{cmd3.join(' ')}"
  puts "Copying bam ..."          ; output = `#{cmd}`; puts output
  puts "Copying BWA stats ..."    ; output = `#{cmd2}`; puts output
  puts "Copying Capture stats ..."; output = `#{cmd3}`; puts output
  Dir.chdir(currDir)
end

