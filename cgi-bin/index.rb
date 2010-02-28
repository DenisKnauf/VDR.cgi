#!/usr/bin/ruby

$:.unshift File.dirname( __FILE__)
require 'fcgi'
require 'main'

vdr = VDR.new :conv => 'utf-8', :expire => 5
environment = ENV.to_hash

FCGI.each_cgi 'html4' do |cgi|
	main vdr, cgi
end
