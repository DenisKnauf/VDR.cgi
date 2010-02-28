require 'v2h'

class V2H::Timer <V2H::V2HContainer
	def [] k
		case k[0]
		when /^\d+$/ then self.timer k
		when 'new' then self.new k[1..-1]
		when 'form' then self.form k[1..-1]
		when 'delete' then self.del k[1..-1]
		when 'list', nil then self.list
		else @conf.unknown_page
		end
	end

	def del key
		@conf.vdr.delt( key[0]).inspect
		@conf.redirect 'timer'
	end

	def new url
		c, cgi = @conf.opts.over, @conf.cgi

		day = VDR::Timer::Day.new( c['date_year'] || 0, c['date_month'] || 0, c['date_day'] || 0)
		day.monday, day.tuesday = '1' == c['rmon'], '1' == c['rtue']
		day.wednesday, day.thursday = '1' == c['rwed'], '1' == c['rthu']
		day.friday, day.saturday = '1' == c['rfri'], '1' == c['rsat']
		day.sunday = c['rsun']

		timer = VDR::Timer.new @vdr, c['active'].to_i, c['channel'], day,
			VDR::Timer::Clock.new( c['start_hour'], c['start_min']),
			VDR::Timer::Clock.new( c['stop_hour'], c['stop_min']),
			c['prio'] || 0, c['lifetime'] || 0, c['file'] || '',
			(c['summ'] || '').gsub( "\n", '|')

		@conf.vdr.newt timer
		@conf.redirect :var => url, :alt => 'timer'
	end

	def form url
		c, cgi = @conf.opts.over, @conf.cgi
		body = cgi.form( 'action' =>
				@conf.urlgen( :var => url.join( '/'), :alt => 'timer/new')) do
			table = Tagen::ConfTable.new

			Tagen::InputRadio.new( 'active').with do |a|
				a.push [ '1', -'yes' ]
				a.push [ '0', -'no' ]
				a.checked = c['active'] || '1'
				table.push [ -'Timer active?', a.gen]
			end

			Tagen::Select.new( 'channel').with do |cs|
				@conf.vdr.lstc do |chan|
					chan.darkknight
					cs.push [ chan.number.to_s, chan.names[0] ]
				end
				cs.selected = c['channel'] || '1'
				table.push [ Tagen.label( :for => :channel) { -'Channel' },
						cs.gen ]
			end

			Tagen::Input.new( cgi, c).with do |input|
				date = input.date( :date) + cgi.br
				date += %W{rmon:Monday rtue:Tuesday rwed:Wednesday rthu:Thursday
						rfri:Friday rsat:Saturday rsun:Sunday}.collect do |d|
					d = d.split ':'
					Tagen.span( :style => 'white-space: nowrap') do
						cgi.input( :type => :checkbox, :name => d[ 0],
							:id => d[ 0], :value => 1,
							:checked => c[ d[ 0]] == '1') +
						Tagen.label( :for => d[0]) { -d[1] }
					end
				end.join( ' ')
				table.push [ Tagen.label( :for => :day) { -'Date' }, date ]

				table.push [
					Tagen.label( :for => :start_hour) { -'Start' },
					input.time( :start, c)
				]
				table.push [
					Tagen.label( :for => :stop_hour) { -'Stop' },
					input.time( :stop, c)
				]

				table.push [
					Tagen.label( :for => :prio) { -'Priority' },
					prio = input.digits( :prio, 99, 2)
				]
				table.push [
					Tagen.label( :for => :lifetime) { -'Lifetime' },
					input.digits( :lifetime, 99, 2)
				]

			file = cgi.input :size => 40, :type => :text, :name => :file,
					:id => :file, :value => c['file']
			table.push [ Tagen.label( :for => :file) { -'File' }, file ]

			summ = cgi.textarea :cols => 40, :rows => 5, :name => :summ,
					:id => :summ do c[ 'summ'].gsub( '|', "\n") end
			table.push [ Tagen.label( -'Summary'), summ ]
			end

			table.gen+
			cgi.input( :type => :submit, :value => 'Absenden')
		end
		V2H::Data.new Array.new, -'Define timer', body
	end

	def timer n
		cgi, timer = @conf.cgi, @conf.vdr.lstt( n)[0]
		raise NoPage  if timer.nil?
		body = cgi.h1 do
				Tagen::Wikipedia.new.gen( timer.file)+ ' '+
				Tagen::IMDb.new.gen( timer.file)+ ' '+
				timer.file
			end
		body += cgi.p do
				b = timer.start_time
				e = timer.stop_time
				t = cgi.b { b.strftime( -'%m-%d-%Y') }
				t += ' '
				t += b.strftime( -"%H:%M")
				t += ' - '
				t + e.strftime( -"%H:%M")
			end
		body += cgi.p { timer.summary.gsub '|', cgi.br }
		V2H::Data.new Array.new, -'Timer', body
	end

	def list
		table, cgi = Tagen::Table.new( 'timer'), @conf.cgi
		require 'zlib'

		table.push :value => lambda { |a|
				if a.status.recording then 'R'
				else
					@conf.confirm( 'timer/delete', a.number.to_s,
						:suf => '|timer', :class => :delete,
						:txt => -'Do you really want to delete timer "%s"?' % a.file.gsub( '~', '/')) do
						'x'
					end
				end
			}

		table.push :title => -'Number', :name => :number
		table.push :title => -'Channel', :name => :channel
		table.push :title => -'Date', :value => lambda { |a|
					d = a.day
					Time.local( d.year, d.month, d.day).strftime -'%m-%d-%Y'
				}

		table.push :title => -'Start',
			:value => lambda { |a| -'%02i:%02i' % a.start.to_a },
			:compare => lambda { |a, b| a.start_time <=> b.start_time }

		table.push :title => -'Stop',
			:value => lambda { |a| -'%02i:%02i' % a.stop.to_a },
			:compare => lambda { |a, b| a.stop_time <=> b.stop_time }

		table.push :title => -'File', :name => :file,
			:value => lambda { |a|
				cgi.a :href => @conf.urlgen( 'timer', a.number) do
					subtitle = cgi.span( :style => 'font-size: 50%;') { ' - \1' }
					a.file.gsub( / - ([^~]*)/, subtitle).gsub( '~', '/')
				end
			}

		table.sort_by = @conf.opts['timer_sortBy'] || '4'
		t = table.generate @conf.vdr.lstt
		V2H::Data.new Array.new, -'Timer', t
	end
end
