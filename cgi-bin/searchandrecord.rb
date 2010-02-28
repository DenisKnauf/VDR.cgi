#!/usr/bin/ruby

require 'getoptlong'

def usage
	$stderr.puts "Usage:\t$0 [-h | -n | -L]"
	$stderr.puts "\t$0 [-n] [-s | -m | -t <TYPE>] <EXPRESSION>"
end

def help
	usage
end

def listtypes
	$stderr.puts 'Possible types of records: Movie, Series'
end

options = { :dryrun => false }

opts = GetoptLong.new(
	[ '--dryrun', '-n', GetoptLong::NO_ARGUMENT ],
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--series', '--serie', '-s', GetoptLong::NO_ARGUMENT ],
	[ '--movie', '-m', GetoptLong::NO_ARGUMENT ],
	[ '--type', '-t', GetoptLong::REQUIRED_ARGUMENT],
	[ '--typelist', '--listtypes', '-L', GetoptLong::NO_ARGUMENT ]
)

opts.each do |o,a|
	case o
	when '--help': help; exit 0
	when '--typelist': listtypes; exit 0
	when '--dryrun': options[ :dryrun] = true
	when '--series': options[ :type] = :Series
	when '--movie': options[ :type] = :Movie
	when '--type':
		if a == 'list'
			listtypes
			exit 0
		end
		options[ :type] = a.to_sym
	end
end

EPGDATA = '/exports/vdr/epg.data'
$:.unshift File.dirname( $0)
require "vdr"

s = search = VDR::SearchAndRecord.new
s.push /simpsons/i, nil, :Series

vdr, ecount = s.vdr, 0
todo = Proc.new do |e|
	STDERR.print "\r#{e.event.start.strftime '%W, %H:%M'} #{e.channel.name} - #{e.title}"[0...80]+"\033[J"
	if t = search.call( e)
		STDERR.puts "\n"
		vdr.newt t
	end
end

if options[ :dryrun]
	todo = Proc.new do |e|
		STDERR.print "\r#{e.event.start.strftime '%W, %H:%M'} #{e.channel.name} - #{e.title}"[0...80]+"\033[J"
		STDERR.puts "\n"  if search.call e
	end
end

VDR::EPG.parse vdr do |e|
	begin
		todo.call e
	rescue VDR::TimerAlreadyDefined
		STDERR.puts "# #{$!.class}"
	rescue VDR::VDRError
		ecount += 1
		STDERR.puts "Event: #{e.title}"
		STDERR.puts "#{ecount}: #{$!.class}: #{$!}"
		$!.backtrace.join( "\n").each_line do |l|
			STDERR.puts "#{ecount}: #{l}"
		end
	end
end
STDERR.puts "\r\033[J"
