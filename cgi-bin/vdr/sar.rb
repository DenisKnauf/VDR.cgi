
class String
	def tsub! opts = nil, &e
		unless e
			opts ||= {}
			e = lambda do |f, a|
				if opts.has_key? f
					case v = opts[ f]
					when Method, Proc: v.call a
					else v.to_s
					end
				end
			end
		end
		self.gsub!( %r<(\\*)\$\{(.*?)\}>) do
			b, k = $1, $2
			m = if b.length%2 == 0
				k =~ %r<^(\w+)(?:\((.*)\))?$>
				e.call $1 + ($2 ? '()' : ''), $2
			end || "${#{k}}"
			( '\\' * (b.length/2) ) + m
		end
	end

	def tsub opts = nil, &e
		e ? self.dup.tsub!( opts, &e) : self.dup.tsub!( opts)
	end
end

class VDR::SearchAndRecord < Array
	attr_reader :vdr
	class AutoTimer
		attr_reader :vdr, :type, :start, :stop, :earlier, :later
		attr_accessor :channel, :file, :title
		def initialize vdr, title, channel, type = nil, file = nil,
					earlier = nil, later = nil
			@vdr, self.title, self.channel = vdr, title.dup, channel
			self.file, self.type = file || '${title}', type || :timer
			self.earlier, self.later = earlier || 10, later || 10
		end

		def series()  @type = :series; self  end
		def series?()  @type == :series  end
		def movie()  @type = :movie; self  end
		def movie?()  @type == :movie  end
		def type=( x)  @type = x.to_s.downcase.to_sym  end
		def earlier=( x)  @earlier = x.to_i  end
		def later=( x)  @later = x.to_i  end

		def test e
			def eqon( a, v)  a ? a === v : true  end
			eqon( @channel, e.channel) && eqon( @title, e.title)
		end
		alias =~ test

		def testnrecord e
			return false  unless self =~ e
			record e
		end
		alias test_and_record testnrecord
		alias call testnrecord
		alias run testnrecord

		def record e
			t = e.to_timer
			t.file = @file
			case @type
			when :series:  t.file += '~${start(%y-%m-%d)}'
			end
			t.stop_time += earlier*60
			t.start_time -= later*60
			title = @title.match e.title
			t.file.tsub! do |f, a|
				case f
				when 'start': t.start_time.strftime '%y-%m-%d.%H:%M'
				when 'start()': t.start_time.strftime a
				when 'stop': t.stop_time.strftime '%y-%m-%d.%H:%M'
				when 'stop()': t.stop_time.strftime a
				when 'title': e.title
				when 'title()': title[ a.to_i]
				end
			end
=begin
			t.file.gsub!( /\$\{([A-Za-z][0-9A-Za-z]*)(?:|\[([0-9]+)\]|\{([^}]*)\})\}/) do |a|
				var, index, key = $1, $2.to_i, $3 || ''
				case var
				when "title":  index == 0 ? e.title.dup : title[ index]
				when "start":  t.start_time.strftime key || '%y-%m-%d.%H:%M'
				when "stop":  t.stop_time.strftime key || '%y-%m-%d.%H:%M'
				when *%w{wday month day hour min sec}:
					'%02i' % t.start_time.method( var).call
				when "year":  t.start_time.year
				else a.to_s
				end
			end
=end
			t
		end
	end

	def testnrecord e
		@vdr.lstc
		@vdr.lstt
		self.each do |a|
			return a  if a = a.call( e)
		end
		return nil
	end
	alias test_and_record testnrecord
	alias call testnrecord

	def initialize *a
		@vdr = VDR.new :buffered => false
		super *a
	end

	def run
		@vdr.epg.parse &:testnrecord
	end

	def push *x
		super x  if x.length == 1 && x[0] === AutoTimer
		super AutoTimer.new( @vdr, *x)
	end
	def []=( k, x)  super k, x  if x === AutoTimer  end
end
