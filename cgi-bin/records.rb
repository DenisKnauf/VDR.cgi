require 'v2h'

class V2H::Records <V2H::V2HContainer
	def [] key
		case key.shift
		when 'delete' then self.delete key
		when nil then self.list
		when 'list' then self.list key
		when 'show' then self.show key
		else @conf.unknown_page key.join( '/')
		end
	end

	def show key
		cgi, rec = @conf.cgi, @conf.vdr.lstr( key)
		start, stop = rec.event.start, rec.event.stop

		body = cgi.h1( :class => :title) do
			rec.title+ ' ' +
			Tagen::Wikipedia.new.gen( rec.title)+ ' ' +
			Tagen::IMDb.new.gen( rec.title)
		end +
		cgi.p do
			cgi.b do
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
		cgi.p { rec.description.gsub '|', cgi.br }

		V2H::Data.new [], -'Record', body
	end

	def delete key
		if [ ENV[ 'SERVER_ADDR'], '127.0.0.1', '::1' ].include? ENV[ 'REMOTE_ADDR']
			@conf.vdr.delr key.shift
			return V2H::Data.new( []), 'Kann nicht loeschen',
					'Sie duerfen nicht loeschen'
		end
		@conf.redirect :var => key, :alt => 'records'
	end

	def list dir = []
		cgi = @conf.cgi
		table = Tagen::Table.new 'records'
		dtable = Tagen::Table.new 'recorddirs'
		dtable.sort_by = @conf.opts['recorddirs_sortBy'] || '2'
		table.sort_by = @conf.opts['records_sortBy'] || '1'

		dtable.push :title => -'Directory', :name => '[](0)',
				:value => lambda { |a|
					a = a[0]
					Tagen.a( :href =>
							@conf.urlgen( 'records/list/', a.join( '/'))
						) { a[-1] }
				}
		dtable.push :title => -'Number of', :name => '[](1)'
		dtable.push :title => -'New', :name => '[](2)'

		table.push :title => -'Title', :name => 'title',
			:value => lambda { |a|
				subtitle = cgi.span( :style => 'font-size: 50%') { ' - \1' }
				Tagen.a( :href => @conf.urlgen( 'records/show', a.number),
						:class => a.seen? ? 'notseen' : 'seen') do
					a.title[-1].gsub( / - ([^~]*)/, subtitle)
				end
			}
		table.push :title => -'Time', :name => 'time',
			:value => lambda { |a| a.time.strftime -'%m-%d-%Y %H:%M' }
		#table.push :title => -'Number', :name => 'number'
		table.push :value => lambda { |a|
				@conf.confirm( 'records/delete', a.to_i, :suf => '|records',
						:class => :delete,
						:txt => -'Do you want to delete record "%s"?' %
								a.title.to_s) { 'x' }
			}

		recs, dirs = [], Hash.new
		@conf.vdr.lstr do |r|
			t = r.title
			if dir != t[ 0...dir.length]
			elsif t.size-1 == dir.length
				recs.push r
			else
				d = t[ 0..dir.length]
				e = dirs[ d] || [0,0]
				e[0] += 1
				e[1] += 1  if r.seen?
				dirs[ d] = e
			end
		end
		dirs = dirs.collect {|k, v| [ k, v[0], v[1] ] }

		page = cgi.p do
				stat = @conf.vdr.stat( 'disk')[0][1]
				#m = /^\s*(\d+)([a-z]?B)\s+(\d+)([a-z]?B)\s+(\d+)%\s*$/i.match stat
				-'Total: %s Free: %s - %s' % stat.split
			end + 
			if dir.empty?  then ''
			else
				Tagen.p do
					Tagen.a( :href => @conf.urlgen( 'records/list/')) do
						'&lt;&lt;&lt;'
					end +
					'/' +
					(0...dir.size).collect do |i|
						Tagen.a( :href => @conf.urlgen( 'records/list/',
								dir[ 0..i].join( '/'))) { dir[ i] }
					end.join( '/')
				end
			end +
			(dirs.empty? ? '' : dtable.generate( dirs) + Tagen.br)+
			(recs.empty? ? '' : table.generate( recs))
		V2H::Data.new Array.new, -'Records', page
	end
end
