#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'net/smtp'
require 'PathInfo'

# This class encapsulates common routines required by email utilities
# Author Nirav Shah niravs@bcm.edu

class EmailHelper
  def initialize()
    @resultRecepients  = nil
    @errorRecepients   = nil
    @captureRecepients = nil
    getEmailList()
  end

  # Get a list of recepients to receive result email
  def getResultRecepientEmailList()
    return @resultRecepients
  end

  # Get a list of recepients to receive error email
  def getErrorRecepientEmailList()
    return @errorRecepients
  end  

  # Get a list of recepients to receive capture summary email
  def getCaptureResultRecepientEmailList()
    return @captureRecepients
  end

  # Method to send an email
  # Parameter "to" is an array of email addresses 
  def sendEmail(from, to, subject, message)
     toMail = ""
     to.each { |x| toMail= toMail + ",#{x}" }

msg = <<END_OF_MESSAGE
From: <#{from}>
To: <#{toMail}>
Subject: #{subject}

#{message}
END_OF_MESSAGE

      Net::SMTP.start('smtp.bcm.tmc.edu') do |smtp|
      smtp.send_message msg, from, to
    end
  end

  # Method to send email with one or multiple attachments
  def sendEmailWithAttachment(from, to, subject, message, attachment)
    jarPath = PathInfo::JAVA_DIR + "/AttachmentMailer.jar" 

    cmd = "java -jar " + jarPath + " sender=" + from + " sub=\"" + subject + "\" " + 
          " body=" + "\"" + message.to_s + "\""

    puts cmd
          
    to.each do |dest|
      cmd = cmd + " dest=" + dest
    end

    puts cmd

    attachment.each do |attach|
      cmd = cmd + " attach=" + attach
    end

    puts cmd
    `#{cmd}`
   end

  private
  # Obtain the list of email addresses who need to be emailed the results
  # or errors
  def getEmailList()
    emailListFile = PathInfo::CONFIG_DIR + "/email_recepients.txt"
    lines = IO.readlines(emailListFile)

    lines.each do |line|
      if line.match(/^EMAIL_RESULTS/)
        temp = line.gsub(/EMAIL_RESULTS=/, "")
        temp.strip!
        @resultRecepients = temp.split(",")
      elsif line.match(/^EMAIL_ERRORS/)
        temp = line.gsub(/EMAIL_ERRORS=/, "")
        temp.strip!
        @errorRecepients = temp.split(",")        
      elsif line.match(/^EMAIL_CAPTURE/)
        temp = line.gsub(/EMAIL_CAPTURE=/, "")
        temp.strip!
        @captureRecepients = temp.split(",")        
      end
    end
  end
end
