require 'options'

class ::VDR::EPG
	attr_reader :vdr
	def initialize( vdr)  @vdr = vdr  end
	def each( &e)  select.each &e  end
	def parse( file = nil, &e)  self.class.parse @vdr, file, &e  end
	def find_first( h = nil)  find h do |entry| return entry end  end

	def self.parse vdr, file = nil, &e
		file ||= ::EPGDATA || '/var/vdr/epg.data'
		e ||= ::Array.new.method :push
		ret, c, event = nil, "", ::VDR::EPG::Entry.new( vdr)
		::File.open file do |f|
			f.each do |line|
				l = line.chomp![2..-1]
				case line[0]
				when ?C: c = l
				when ?E: event = ::VDR::EPG::Entry.new vdr, c, l
				when ?T: event.title = l
				when ?S: event.short_text = l
				when ?D: event.description = l
				when ?X: event.streams.push l
				when ?V: event.vps = l
				when ?e: ret = e.call event
				when ?c
				else { :unexpected_epg => line }.dakknight
				end
			end
		end
		ret
	end

	def select h = nil, &e
		e ? ::VDR::EPG::Select.new( self, h) : ::VDR::EPG::Select.new( self, h, &e)
	end

	def find h = nil, &e
		s = select h
		e ? s.each( &e) : s.to_a
	end
end

class ::VDR::EPG::Select
	attr_reader :epg, :between, :channel, :title, :description, :block
	def each( &e)  eval gen_filter  end
	def first()  each do |entry| return entry end  end

	def initialize epg, h = nil, &e
		h ||= {}
		@block, @epg, @between, @channel, @title, @description = \
			e, epg, h[:between], h[:channel], h[:title], h[:description]
		@start, @stop, @duration = h[:start], h[:stop], h[:duration]
	end

	def gen_filter t = nil, p = nil, u = nil
		s = []
		s.push '@start === event.start'  if @start
		s.push '@stop === event.stop'  if @stop
		s.push '@duration === event.duration'  if @duration
		if @channel
			@channel = ::VDR::EPG::Channel.new @vdr, @channel.to_s
			s.push '@channel === entry.channel'
		end
		s.push '@description === entry.description'  if @description
		s.push '@title === entry.title'  if @title
		s.push 'event.vergleichen @between'  if @between
		s.push '@block.call( entry)'  if @block
		#s.push t || 'e.call( entry)'
		s = <<-EOF
			#{p || '@epg.parse do |entry|'}
				event = entry.event
				#{s.collect( & "(%s) || next".method( :%)).join "\n\t\t\t\t"}
				#{t || 'e.call( entry)'}
			#{u || 'end'}
		EOF
		s
	end

	def collect &e
		ret []
		eval gen_filter( 'ret.push( e.call( entry))')
		ret
	end

	def to_a
		ret = []
		e = gen_filter( 'ret.push( entry)')
		begin
			eval e
		rescue Object
			File.open( '/tmp/vdr.cgi.debug', 'w+') do|f|
				f.puts '='*80
				f.puts e
				f.puts '-'*80
				f.puts "#{$!.message} (#{$!.class})"
				f.puts "\t" + $!.backtrace.join( "\n\t")
			end
			raise $!
		end
		ret
	end
end

class ::VDR::EPG::Entry
	attr_accessor :short_text, :description, :streams, :vps
	attr_reader :title, :vdr, :event, :channel
	def title=( value)  @title = value.to_s  end

	def initialize vdr, c = ::VDR::EPG::Channel.new( vdr), e = "", t = "", s = "", d = "", x = [], v = ""
		::Kernel.expect ::VDR, vdr
		@vdr, self.channel, self.event, self.title, self.short_text,
			self.description, self.streams, self.vps = vdr, c, e, t, s, d, x, v
	end

	def channel= value
		value = ::VDR::EPG::Channel.new @vdr, value  if value.kind_of? ::String
		::Kernel.expect ::VDR::EPG::Channel, value
		@channel = value
	end

	def event= value
		value = ::VDR::EPG::Event.new value  if value.kind_of? ::String
		::Kernel.expect ::VDR::EPG::Event, value
		@event = value
	end

	def to_timer
		e = self.event
		::VDR::Timer.new @vdr, 3, self.channel, ::VDR::Timer::Day.new( e.start),
			::VDR::Timer::Clock.new( e.start.hour, e.start.min),
			::VDR::Timer::Clock.new( e.stop.hour, e.stop.min),
			99, 99, self.title, self.description
	end

	def record?
		timer, chan = self.to_timer, self.channel
		r = []
		vdr.lstt do |a|
			if timer.channel == a.channel && (x = (timer =~ a))
				r.push x 
			end
		end
		r.uniq
	end

	def inspect
		"#<#{self.class} #{self.channel.inspect} #{self.title.inspect} #{self.event.inspect}>"
	end

	def vergleichen m
		[ :short_text, :description, :streams, :vps, :title, :vdr, :event,
				:channel ].each do |k|
			m[k] ? m[k] === e.method( k) : true
		end
	end
	alias =~ vergleichen
end

class ::VDR::EPG::Event
	attr_reader :id, :start, :duration, :table_id
	def id=( value)  @id = value.to_i  end
	def duration=( value)  @duration = value.to_i  end
	def table_id=( value)  @table_id = value  end
	def to_s()  [ @id, @start.to_i, @duration, @table_id].compact.join " "  end

	def initialize id = 0, start = nil, duration = nil, table_id = nil
		self.id, self.start, self.duration, self.table_id = if id.kind_of? ::String
				id.split " "
			else [ id, start, duration, table_id ]
			end
	end

	def stop()  self.start + self.duration  end

	def stop= value
		value = ::Time.at value  unless value.kind_of? ::Time
		self.duration = (value - self.start).to_i
	end

	def start= value
		value = ::Time.at value.to_i  unless value.kind_of? ::Time
		@start = value
	end

	def vergleichen value
		start, stop = self.start.to_i, self.stop.to_i
		case value
		when ::Numeric, ::Time: (start .. stop) === value.to_i
		when ::Range
			value = value.begin.to_i..value.end.to_i
			value.include?( start) || value.include?( stop) ||
				(start..stop).include?( value.begin)
		when self.class
			vstart, vstop = value.start.to_i, value.stop.to_i
			(start..stop) === vstart || (start..stop) === vstop ||
				(vstart..vstop) === start
		else raise ::ArgumentError, "#{value.inspect}"
		end
	end
	alias =~ vergleichen

	def inspect
		"#<#{self.class} #{self.start.inspect}  #{self.duration.inspect}>"
	end
end

class VDR::EPG::Channel
	attr_reader :vdr, :id
	def to_i()  channel.number  end
	def name()  @name || channel.name  end

	def initialize vdr, id = nil, name = nil
		@vdr = vdr
		self.id, self.name = if id.nil? then [ '', '' ]
			elsif name.nil? then id.to_s.split ' ', 2
			else [ id, name ]
			end
	end

	def id= value
		::Kernel.expect ::String, value
		@channel = nil
		@id = value
	end

	def channel
		return @channel  if @channel
		source, tid, rid, nid = @id.split "-"
		@channel = @vdr.lstc.find do |c|
			c.source == source && c.tid == tid && c.rid == rid && c.nid == nid
		end
	end

	def name= value
		::Kernel.expect [::String, nil], value
		@name = value
	end

	def == v
		case v
		when ::Numeric: to_i == v
		when ::VDR::EPG::Channel: self.id == v.id
		else super v
		end
	end

	def inspect
		"#<#{self.class} #{self.name.inspect} #{self.to_i.inspect} @id=#{self.id.inspect}>"
	end
end
