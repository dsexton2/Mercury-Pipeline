#!/usr/bin/ruby

require 'ErrorHandler'

obj = ErrorMessage.new()
obj.fcBarcode = "foofoofoo"
obj.workingDir = Dir.pwd
obj.msgBrief = "Brief error message"
obj.msgDetail = "Detail error message"

ErrorHandler.handleError(obj)
