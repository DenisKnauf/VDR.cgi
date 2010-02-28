require 'v2h'
require 'cgi'

class V2H::EPG <V2H::V2HContainer
	def initialize *p
		super *p
		@dura, @dura2 = (@conf.opts[ 'epg_duration'] || 1.hour).to_i, (@conf.opts[ 'epg_dayduration'] || 1.day).to_i
	end

	def [] key
		case key[0]
		when 'record':  self.record key[1..-1]
		when 'list', nil:  self.list [ 'now' ]
		when 'find'
			key.shift
			case key[0]
			when 'search':	self.find_search key[1..-1]
			when 'form', nil: self.find_form key[1..-1]
			end
		when 'graph', 'line'
			self.graph key.size == 0 ? ["at:#{Time.now.to_i}"] : key
		else
			if key.size == 1
				self.list key
			else
				self.epg key
			end
		end
	end

	def key key
		chans = @conf.vdr.lstc
		time, chan = nil, nil
		key[0..1].each do |i|
			case i
			when 'next': time = i
			when 'now': time = "at #{Time.now.to_i}"
			when /^at[:= ]?(.*)$/
				case a = $1
				when /^(\d+)$/: time = "at #{a}"
				when /^(\d\d?):(\d\d?)$/
					time = "at #{(Time.now.beginning_of_day + $1.to_i.hours + $2.to_i.minutes).to_i}"
				else @conf.fail key
				end
			when /^(\d\d?):(\d\d?)$/
				time = "at #{(Time.now.beginning_of_day + $1.to_i.hours + $2.to_i.minutes).to_i}"
			when /^\d+$/: chan = i.to_i
			when /^[DTS]-([0-9-]+)$/: chan = i
			else
				c = i.downcase
				c = chans.find do |i|
					! i.names.find_all do |s|
						c == s.downcase
					end.empty?
				end
				@conf.fail key  unless c
				chan = c.number
			end
		end
		[ chan, time ]
	end

	def chansel chan, time
		cgi = @conf.cgi
		sel = @conf.vdr.lstc.collect do |c|
			[ "epg/#{c.number}", '%02i %s' % [ c.number, c.names[0]] ]
		end
		time = if time =~ /^at (\d+)/
				Time.at $1.to_i
			else Time.now
			end
		day = time.beginning_of_day
		today = Time.now.beginning_of_day
		daytime = time - day

		Tagen::VerticalLinks.new.with do |links|
			sm = Tagen::SelectMenu.new -'Channel', sel
			links.push sm.gen( @conf.urlgen(), :chanselect)
			0.upto 5 do |i|
				t = today.in i.days
				ts = [20, 22] + (0..19).to_a + [23]
				ts = ts.collect do |h|
					h = t + h*1.hours
					[ "epg/at:#{h.to_i}", h.strftime( -'%H:%M') ]
				end
				t += daytime
				_a = { :href => @conf.urlgen( "epg/at:#{t.to_i}") }
				_a.update :class => :now  if day..(day.in 1.day) === t
				t = cgi.a( _a) { t.strftime -'%m-%d' }
				sm = Tagen::SelectMenu.new t, ts
				links.push sm.gen( @conf.urlgen, :timeselect)
			end
			links.push ''
			t = time.in -@dura
			links.push cgi.a( :href => @conf.urlgen( 'epg', "at:#{t.to_i}")) {
					CGI.escapeHTML "<< #{t.strftime -'%H:%M'}"
				}  if time > Time.now
			t = time.in @dura
			links.push cgi.a( :href => @conf.urlgen( 'epg/now')) { -'Now' }
			links.push cgi.a( :href => @conf.urlgen( 'epg',
							"at:#{t.to_i}")) {
					CGI.escapeHTML "#{t.strftime -'%H:%M'} >>"
				}
		end.to_s
	end

	def get_epg chan = nil, time = nil, dura = nil
		vdr, dura = @conf.vdr, dura.to_i
		stime = if /^at\s+(\d+)/ =~ time then Time.at $1.to_i end
		x = if dura != 0 && stime && !chan
				{:between => stime.to_i .. stime.in( dura).to_i}
			else
				{:channel => chan, :between => stime}
			end.darkknight( 'get_epg: %s')
		vdr.epg.select( x).to_a
	end

	def epg key
		chan, time = self.key key
		epg, cgi = self.get_epg( chan, time).first, @conf.cgi
		raise 'No Entry found'  unless epg
		start, stop = epg.event.start, epg.event.stop

		body = cgi.h1( :class => :title) do
			cgi.a( :class => :record, :href => @conf.urlgen(
					'epg/record', key.join( '/'), :suf => ENV[ 'PATH_INFO'])) do
				'o'
			end + ' ' +
			epg.title + ' ' +
			Tagen::Wikipedia.new.gen( epg.title) + ' ' +
			Tagen::IMDb.new.gen( epg.title)
		end +
		cgi.p do
			cgi.b do
				cgi.a( :href => @conf.urlgen( 'epg', chan)) do
					epg.channel.name
				end +
				': ' +
				start.strftime( -'%m-%d-%Y') +
				' ' +
				cgi.a( :href => @conf.urlgen( 'epg', "at:#{start.to_i}")) do
					start.strftime -'%H:%M'
				end +
				' - ' +
				cgi.a( :href => @conf.urlgen( 'epg', "at:#{stop.to_i}")) do
					stop.strftime -'%H:%M'
				end
			end
		end +
		cgi.p do
			epg.description.gsub '|', cgi.br
		end

		Array.new.with do |links|
			links.push cgi.link( :rel =>:next, :title => -'Next',
				:href => @conf.urlgen( 'epg', "#{chan}/at:#{stop.to_i}"))
			V2H::Data.new links, epg.title, body
		end
	end

	def record key
		epg = self.get_epg( *self.key( key).darkknight( 'key => %s')).flatten[0].darkknight
		raise NoPage  unless epg
		start, stop = epg.event.start-5.minutes, epg.event.stop+5.minutes
		@conf.redirect 'timer/form/timer/new', key[ 2..-1].join( '/'),
				:channel => epg.channel.to_i,
				:date_year => start.year,
				:date_month => start.month,
				:date_day => start.day,
				:start_hour => start.hour,
				:start_min => start.min,
				:stop_hour => stop.hour,
				:stop_min => stop.min,
				:file => epg.title,
				:summ => epg.description
	end

	def list key
		chan, time = self.key( key)
		list_epg self.get_epg( chan, time, @dura), chan, time
	end

	def list_epg epg, chan, time
		vdr, cgi = @conf.vdr, @conf.cgi
		table = Tagen::Table.new 'epg'
		table.push :title => -'Date',
			:value => lambda { |a| a.event.start.strftime -'%m-%d-%Y' }
		table.push :title => -'Start', :name => 'event.start',
			:value => lambda { |a|
					s = a.event.start
					Tagen.a :href => @conf.urlgen( 'epg', "at:#{s.to_i}") do
						s.strftime -'%H:%M'
					end
				}

		table.push :title => -'Stop', :name => 'event.stop',
			:value => lambda { |a|
					s = a.event.stop
					Tagen.a :href => @conf.urlgen( 'epg', "at:#{s.to_i}") do
						s.strftime -'%H:%M'
					end
				}
		table.push :title => -'Channel', :name => 'channel.name',
			:value => lambda { |a|
					c = a.channel
					Tagen.a :href => @conf.urlgen( 'epg', c.id) do
						c.name
					end
				}  unless chan
		table.push :value => lambda { |a|
					start, stop = a.event.start, a.event.stop
					url = @conf.urlgen 'epg/record',
							"#{a.channel.id}/at:#{start.to_i}",
							:suf => ENV[ 'PATH_INFO']
					start, stop = start.min+start.hour*60, stop.min+stop.hour*60
					Tagen.a( :class => :record, :href => url) { 'o' }
				}

		table.push :title => -'Title', :name => 'title', :value => lambda { |a|
					start, stop = a.event.start, a.event.stop
					url = @conf.urlgen 'epg', "#{a.channel.id}/at:#{start.to_i}"
					start, stop = start.min+start.hour*60, stop.min+stop.hour*60
					rec = a.record?.collect do |i|
						case i
						when false then :norecord
						when true then :fullrecord
						when -1 then :postrecord
						when 1 then :prerecord
						when 0 then :partrecord
						end
					end
					click = Tagen.a( :href => url, :class => rec) do
						if (start .. stop).include? 20*60+16
							Tagen.b { CGI.escapeHTML( a.title) }
						else
							CGI.escapeHTML( a.title)
						end
					end
					click
				}

		if time && 'next' != time.to_s
			t = time.to_s == 'now' ? Time.now : Time.at( time.match( /\d+/).to_s.to_i)
			tagen = table.tagen
			eval <<-EOC
			def tagen.tbody *p
				ret = super *p
				#{ _t = t.in -@dura
				<<-EOCP  if t < Time.now
				ret = self.tr( :class => [:link_prev_epg, :r1]) do
					self.td( :style => 'text-align: center;',
							:class => [:first, :last],
							:colspan => #{table.length}) do
						self.a( :href => #{
								@conf.urlgen( 'epg', "at:#{_t.to_i}").inspect
								}) do
							"... #{_t.strftime -'%H:%M'} - #{t.strftime -'%H:%M'} ..."
						end
					end
				end+ ret
				EOCP
				}
				#{ _t = t.in @dura
				<<-EOCP
				ret += self.tr( :class => [:link_next_epg, :r1]) do
					self.td( :style => 'text-align: center;',
							:class => [:first, :last],
							:colspan => #{table.length}) do
						self.a( :href => #{
								@conf.urlgen( 'epg', "at:#{_t.to_i}").inspect
								}) do
							"... #{_t.strftime -'%H:%M'} - #{_t.in( @dura).strftime -'%H:%M'} ..."
						end
					end
				end
				EOCP
				}
			end
			EOC
		end

		table.sort_by = @conf.opts['epg_sortBy'] || "1"
		body = self.chansel( chan, time) + table.generate( epg)
		V2H::Data.new Array.new, -'EPG', body
	end

	def find_form key
	end

	def find_search key
		h = @conf.opts.over.symbolize_keys
		list_epg @conf.vdr.epg.find( h), false, nil
	end

	def graph time
		chan, time = self.key( time)
		epg = self.get_epg nil, time, @dura
		@tagen.table( :class => :timeline) do
			@tagen.thead do
				@tagen.tr do
				end
			end +
			@tagen.tbody do
				epg.collect do |e|
					@tagen.tr do
						epg.collect do |f|
							@tagen.td do
							end
						end
					end
				end
			end
		end
	end
end
