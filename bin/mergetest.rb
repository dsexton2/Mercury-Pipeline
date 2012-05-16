#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'yaml'
require 'PathInfo'
require 'SchedulerInfo'
require 'MergeHelper'

inputList = Array.new
inputList << "/stornext/snfswgl/next-gen/Illumina/Instruments/EAS376/110914_USI-EAS376_00036_FC63A2RAAXX/Results/Project_110914_USI-EAS376_00036_FC63A2RAAXX/Sample_63A2RAAXX-1"
inputList << "/stornext/snfswgl/next-gen/Illumina/Instruments/EAS376/110914_USI-EAS376_00036_FC63A2RAAXX/Results/Project_110914_USI-EAS376_00036_FC63A2RAAXX/Sample_63A2RAAXX-5"
inputList << "/stornext/snfswgl/next-gen/Illumina/Instruments/EAS376/110914_USI-EAS376_00036_FC63A2RAAXX/Results/Project_110914_USI-EAS376_00036_FC63A2RAAXX/Sample_63A2RAAXX-6-ID12"
inputList << "/stornext/snfswgl/next-gen/Illumina/Instruments/EAS376/110914_USI-EAS376_00036_FC63A2RAAXX/Results/Project_110914_USI-EAS376_00036_FC63A2RAAXX/Sample_63A2RAAXX-7-ID12"

outDir = "/stornext/snfswgl/next-gen/Illumina/Instruments/EAS376/110914_USI-EAS376_00036_FC63A2RAAXX/merged"


obj = MergeHelper.new(inputList, outDir)
obj.startMerge()
