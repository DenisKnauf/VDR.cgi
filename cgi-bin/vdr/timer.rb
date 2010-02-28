require 'options'

class VDR::Timer
	attr_reader :vdr, :status, :channel, :day, :start, :stop, :priority
	attr_reader :file, :summary, :number, :lifetime

	def initialize vdr, status = VDR::Timer::Status.new, channel = 1,
			day = VDR::Timer::Day.new, start = VDR::Timer::Clock.new,
			stop = VDR::Timer::Clock.new, priority = 0, lifetime = 0,
			file = "", summary = "", number = 0

		@vdr = vdr
		self.status, self.channel, self.day, self.start, self.stop,
				self.priority, self.lifetime, self.file, self.summary,
				@number = if status.kind_of? String
						status = /^((\d+) )?(.*)$/.match status
						status[3].split( ':', 9) + [ status[2].to_i ]
					else [ status, channel, day, start, stop, priority,
								lifetime, file, summary, number ]
					end
	end

	def status= value
		value = VDR::Timer::Status.new value  if [ String, Fixnum ].include? value.class
		Kernel.expect VDR::Timer::Status, value
		@status = value
	end

	def priority= value
		value = value.to_i
		Kernel.expect 0..99, value
		@priority = value
	end

	def file= value
		@file = value.to_s.gsub ":", "|"
	end

	def channel= value
		value = value.to_i
		Kernel.expect Fixnum, value
		@channel = value
	end

	def start= value
		case value
		when String, Integer:  value = VDR::Timer::Clock.new value
		end
		Kernel.expect VDR::Timer::Clock, value
		@start = value
	end

	def stop_time
		day, stop = self.day, self.stop
		t = Time.gm day.year, day.month, day.day, stop.hour, stop.minute
		t += 1440  if self.start > stop
		t
	end

	def stop_time= t
		t = Time.local t  if t === Integer
		@stop = VDR::Timer::Clock.new t.hour, t.min
	end

	def start_time
		day, start = self.day, self.start
		Time.gm day.year, day.month, day.day, start.hour, start.minute
	end

	def start_time= t
		t = Time.local t  if t === Integer
		@day = VDR::Timer::Day.new t.year, t.month, t.day
		@start = VDR::Timer::Clock.new t.hour, t.min
	end

	def stop= value
		case value
		when String, Integer:  value = VDR::Timer::Clock.new value
		end
		Kernel.expect VDR::Timer::Clock, value
		@stop = value
	end

	def summary= value
		@summary = value.to_s.gsub "\n", "|"
	end

	def lifetime= value
		value = value.to_i
		Kernel.expect 0..99, value
		@lifetime = value
	end

	def day= value
		value = VDR::Timer::Day.new value  if value.kind_of? String
		Kernel.expect VDR::Timer::Day, value
		@day = value
	end

	def to_s
		"#{@status}:#{@channel}:#{@day}:#{@start}:#{@stop}:#{@priority}:#{@lifetime}:#{@file}:#{@summary}"
	end

	def =~ value
		start, stop, vstart, vstop = self.start_time, self.stop_time,
				value.start_time, value.stop_time
		pre, post = (vstart..vstop) === start, (vstart..vstop) === stop
		if pre && post then true
		elsif pre then -1
		elsif post then 1
		elsif (start..stop) === vstart then 0
		else false
		end
	end
end

class VDR::Timer::Status
	%w{ACTIVE INSTANT USE_VPS RECORDING}.each_with_index do |l,i|
		i, m = i**2, l.downcase
		consts_multiset i, l
		c = lambda {|| @repeat&i == i }
		define_method m, &c
		define_method "#{m}?", &c
		define_method "#{m}=" do |value|
			@repeat = @repeat & ~i | (value ? i : 0)
		end
	end

	attr_reader :status

	def initialize( status = 0)  self.status = status  end
	def to_s()  @status.to_s  end

	def status= value
		value = value.to_i
		Kernel.expect [Bignum, Fixnum], value
		@status = value
	end
end

class VDR::Timer::Clock
	attr_reader :hour, :minute

	def initialize hour = 0, minute = nil
		self.hour, self.minute = if minute.nil?
				case hour
				when String then [ hour[0..1], hour[2..3] ]
				when Integer then [ hour/60, hour%60 ]
				else [ 0, 0 ]
				end
			else
				[ hour, minute ]
			end
	end

	def minute= value
		value = value.to_i
		Kernel.expect 0..60, value
		@minute = value
	end

	def hour= value
		value = value.to_i
		Kernel.expect 0..23, value
		@hour = value
	end

	def -( value)  self.class.new self.to_i - value  end
	def +( value)  self.class.new self.to_i + value  end
	def <( value)  self.to_i < value.to_i  end
	def >( value)  self.to_i > value.to_i  end

	def to_i= value
		Kernel.expect Integer, value
		self.hour, self.minute = value/60, value%60
	end

	def to_i()  @hour*60 + @minute  end
	def to_s()  "%02i%02i" % [ @hour, @minute ]  end
	def to_a()  [@hour, @minute]  end
	def <=>()  value self.to_i <=> value.to_i  end
end

class VDR::Timer::Day
	<<-EOD.split( "\n").each_with_index do |l,i|
		MON MO MONDAY MONTAG
		TUE DI TUESDAY DIENSTAG
		WED MI WEDNESDAY MITTWOCH
		THU DO THURSDAY DONNERSTAG
		FRI FR FRIDAY FREITAG
		SAT SA SATURDAY SAMSTAG
		SUN SO SUNDAY SONNTAG
	EOD
		l = l.split( /\s+/)[1..-1]
		i, m = i**2, l[2].downcase
		consts_multiset i, *l
		c = lambda {|| @repeat&i == i }
		define_method m, &c
		define_method "#{m}?", &c
		define_method "#{m}=" do |value|
			@repeat = @repeat & ~i | (value ? i : 0)
		end
	end

	<<-EOD.split( "\n").each_with_index { |l,i| consts_multiset i, l }
		DEL DELETE
		JAN JANUARY JANUAR
		FEB FEBRUARY FEBRUAR
		MAR MARCH MAERZ
		APR APRIL
		MAY MAI
		JUN JUNE JUNI
		JUL JULY JULI
		AUG AUGUST
		SEP SEPTEMBER
		OCT OCTOBER
		NOV NOVEMBER
		DEC DEZ DECEMBER DEZEMBER
	EOD

	attr_reader :year, :month, :day, :repeat

	def initialize *paras
		# year = Time.new.year, month = Time.new.month, day = Time.new.day, repeat = 0
		x = nil

		if paras.size == 1
			x = case paras[0]
			when String
				value = paras[0]
				if days = /^(\d{4})-(\d{2})-(\d{2})$/.match( value)
					days = days.to_a[0..-1]
					days[0] = 0
					days
				elsif days = /^([a-zA-Z\-]{7})@(\d{4})-(\d{2})-(\d{2})$/.match( value)
					days.to_a[1..-1]
				elsif /^[a-zA-Z\-]{7}$/.match value
					[ value, 0, 0, 0 ]
				else raise ArgumentError, "Not a valid Day-string (#{value})"
				end
			when Time
				t = paras[0]
				[ 0, t.year, t.month, t.day ]
			end
		end
		self.repeat, self.year, self.month, self.day = *x || [ paras[3] || 0, paras[0] || Time.new.year, paras[1] || Time.new.month, paras[2] || Time.new.day ]
	end

	def year= value
		value = value.to_i
		Kernel.expect Fixnum, value
		@year = value
	end

	def month= value
		value = case value.to_s.downcase
			when %w{del delete} then 0
			when %w{jan january januar} then 1
			when %w{feb february februar} then 2
			when %w{mar march maerz} then 3
			when %w{apr april} then 4
			when %w{may mai} then 5
			when %w{jun june juni} then 6
			when %w{jul july juli} then 7
			when %w{aug august} then 8
			when %w{sep september} then 9
			when %w{oct october} then 10
			when %w{nov november} then 11
			when %w{dec december dez dezember} then 12
			else value.to_s.to_i
			end  if value.kind_of?( String) || value.kind_of?( Symbol)
		Kernel.expect 0..12, value
		@month = value
	end

	def day= value
		value = value.to_i
		Kernel.expect 0..31, value
		@day = value
	end

	def repeat= value
		if value.kind_of? String
			d = value
			value = 0
			(0...7).each do |i|
				j = i**2
				value |= j  unless d[i] ==?-
			end
		end
		Kernel.expect 0..MON|TUE|WED|THU|FRI|SAT|SUN, value
		@repeat = value
	end

	def -( value)  self + -value  end
	def <=>( value)  self.to_i||0 <=> value.to_i||0  end
	def to_a()  [ @repeat, @month, @day, @year ]  end

	def to_i
		@repeat == 0 ? nil : (Time.local( @year, @month, @day).to_i / 86400)
	end

	def to_s
		if (@month | @day | @year == 0) && @repeat == 0
			""
		elsif @repeat == 0
			"%04i-%02i-%02i" % [ @year, @month, @day]
		else
			str = "MTWTFSS"
			str += "@%04i-%02i-%02i" % [ @year, @month, @day]  unless [ @year, @month, @day ].include? 0
			(0...7).each do |i|
				j = i**2
				str[i] = '-'  unless @repeat&j == j
			end
			str
		end
	end

	def + value
		t = if @year | @month | @day == 0
				[ 0, 0, 0]
			else
				t = Time.gm( @year, @month, @day) + 86400*value
				[ t.year, t.month, t.day ]
			end
		self.class.new t[0], t[1], t[2], @repeat && (((@repeat + (@repeat << 7)) >> (value%7)) & 127)
	end

	def =~ value
		day = self.to_i
		if day
			case value
			when Time then day == value.to_i / 86400
			when Integer then day == value
			else super value
			end
		else
			case value
			when Time
				day = 2**value.wday
				self.repeat & day == day
			when Integer then self === Time.at( value)
			else super value
			end
		end
	end
end
