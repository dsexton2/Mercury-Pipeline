#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'BWAParams'

# Script to hook up commands like SNP and variant calling after alignment is
# completed.
# Author Nirav Shah niravs@bcm.edu

puts "Invoking SNP caller"
bamFile = Dir["*_marked.bam"]

if bamFile != nil && bamFile.length > 0
  snpCallCmd = "ruby
/stornext/snfs3/1000GENOMES/challis/geyser_Atlas2_wrapper/Atlas2Submit.rb " +
               File.expand_path(bamFile[0])
  `#{snpCallCmd}`
end

