#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'LimsInfo'

puts LimsInfo::LIMS_DB_NAME
