
require 'options'
require 'iconv'
require 'vdr/svdrp'

class ::VDR <::Svdrp
end

require 'vdr/channel'
require 'vdr/epg'
require 'vdr/timer'
require 'vdr/records'
require 'vdr/sar'

class ::Buffer
	attr_accessor :o
	attr_reader :d, :l

	def initialize d = nil, o = 60
		@l, @o = Time.at( 0), o
		self.d = d  if d
	end

	def d= v
		@d, @l = v, Time.now+@o
	end

	def outdated?
		Time.now <= @l
	end
end

class ExpCache < Hash
	attr_accessor :expire
	attr_reader :expires
	def initialize expire = nil
		@expire, @expires = expire || 60, {}
	end
	def expired? k
		@expires[ k] && @expires[ k] < Time.now
	end
	def expire k
		if expired? k
			self.delete k
			@expires.delete k
		end
	end

	%w{[] fetch key? has_key? include? member?}.each do |cmd|
		eval <<-EOC
			def #{cmd} k
				expire k
				super k
			end
		EOC
	end
	%w{[]= store}.each do |cmd|
		eval <<-EOC
			def #{cmd} k, v
				@expires[k] = Time.now + @expire
				super k, v
			end
		EOC
	end

	%w{clear delete}.each do |cmd|
		eval <<-EOC
			def #{cmd} *p
				@expires.#{cmd} *p
				super *p
			end
		EOC
	end

	%w{delete_if each each_key each_pair reject reject!}.each do |cmd|
		eval <<-EOC
			def #{cmd}
				super do |*p|
					expires p[0]
					yield *p  if has_key? k
				end
			end
		EOC
	end

	def each_value
		each do |k, v|
			expire k
			yield v  if has_key? k
		end
	end
end

class VDR
	class VDRError <RuntimeError
		attr_reader :err, :line
		def initialize err, line
			@err, @line = err, line
			super "#{err}: #{line}"
		end
	end
	class TimerAlreadyDefined <VDRError
	end

	attr_accessor :conv, :channels, :records

	def initialize opts = {}
		@conv = nil # opts[:conv] || opts[:charset] || opts[:cs]
		@channels, @records = Buffer.new, Buffer.new
		@cache = ExpCache.new opts[ :expire]
		@buffered = opts[:buffered].nil? ? true : !!opts[:buffered]
		super opts[:host] || 'localhost', opts[:port] || 2001
	end

	def puts line
		super @conv ? Iconv.conv( 'utf-8', @conv, line) : line
	end

	def gets
		x = super
		x[-1] = Iconv.conv @conv, 'utf-8', x[-1]  if @conv
		case x[1]
		when (0...400)
		when 550: raise TimerAlreadyDefined.new( x[1], x[-1])
		else raise VDRError.new( x[1], x[-1])  if x[0] && x[1] >= 400
		end	if x[0]
		x
	end

	def cmd line = nil, &e
		unless e
			a = Array.new
			e = lambda do |last, err, line|
				a.push [ err, line ]
			end
		end
		ret = nil
		puts line  unless line.nil?
		last = false
		begin
			until last
				last, err, line = gets
				next  unless line
				ret = e.call last, err, line
			end
		rescue VDRError
			raise
		rescue
			line = gets  until line[0]
			raise
		end
		ret
	end

	def super_cached m, x, p = nil
		<<-EOC
		a = @cache[ #{m.inspect}]
		if a.nil?
			a = Array.new
			if e
				super #{p} do |last, err, line|
					x = #{x}
					a.push x
					e.call x
				end
			else
				super #{p} do |last, err, line|
					a.push #{x}
				end
			end
			@cache[ #{m.inspect}] = a
		elsif e
			a.each &e
		end
		a
		EOC
	end

	def lstr num = nil, &e
		e ||= Array.new.method :push
		if num
			c, e = "", VDR::EPG::Entry.new( self)
			super num do |last, error, line|
				l = line[2..-1]
				case line[0]
				when ?C then e.channel = l
				when ?E then e.event = l
				when ?T then e.title = l
				when ?S then e.short_text = l
				when ?D then e.description = l
				when ?X then e.streams.push l
				when ?V then e.vps = l
				when ?c
				else { :unexpected_epg_data => line }.darkknight
				end  unless last
			end
			e
		else
			eval super_cached( :lstr, 'VDR::Records.new( line)')
		end
	rescue VDR::VDRError => e
		raise  unless e.err == 550
		[]
	end

	def lstc num = nil, &e
		eval super_cached( :lstc, 'VDR::Channel.new( self, line)')
	rescue VDR::VDRError => e
		raise  unless e.err == 550
		[]
	end

	def lstt num = nil, &e
		eval super_cached( "lstt_#{num}", 'VDR::Timer.new( self, line)', num)
	rescue VDR::VDRError => e
		raise  unless e.err == 550
		[]
	end

	def newt value
		value = value.to_s
		Kernel.expect String, value
		super value
	end

	def delt value
		value = value.number  if value.kind_of? VDR::Timer
		value = value.to_i
		value = nil  if value < 1
		Kernel.expect Integer, value
		super value
	end

	def lste chan = nil, time = nil, &e
		e ||= Array.new.method :push
		ret, c, event = nil, "", VDR::EPG::Entry.new( self)
		parser = lambda do |last, error, line|
			l = line[2..-1]
			case line[0]
			when ?C then c = l
			when ?E then event = VDR::EPG::Entry.new self, c, l
			when ?T then event.title = l
			when ?S then event.short_text = l
			when ?D then event.description = l
			when ?X then event.streams.push l
			when ?V then event.vps = l
			when ?e then ret = e.call event
			when ?c
			else { :unexpected_epg_data => line }.darkknight
			end  unless last
		end
		super chan, time, &parser
		ret
	end

	def epg()
		EPG.new self
	end
end
