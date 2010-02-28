require 'cgi'
require 'uri'

class Tagen
	def method_missing *p, &e
		self.class.method_missing *p, &e
	end

	class <<self
		def out opts, &e
			o = {}
			opts.each do |k, v|
				o[ k.to_s.gsub( /(\s|[:=])+/, '').capitalize] = v
			end
			content = e.call
			o[ 'Content-size'] = content.size
			o[ 'Content-type'] ||= 'text/html'
			o.collect do |k, v|
				"#{k}: #{v}" if k && v
			end.join "\n"
		end

		def method_missing name, opts=nil, &e
			t = [ name.to_s.sub( /^[^a-zA-Z_]+/, '').gsub( /[^a-zA-Z0-9_:]+/, '') ]
			t += opts.collect do |k, v|
				k = k.to_s.sub( /^[^a-zA-Z_]+/, '').gsub( /[^a-zA-Z0-9_:]+/, '')
				v = case v
				when true then k
				when Array then v.join ' '
				else v
				end
				"#{k}=\"#{v}\""  if v
			end  if opts
			#t += %w[/]  unless e
			#b = "<#{t.join ' '}>"
			#b += "\n#{e.call.to_s.gsub /^/m, "\t"}\n</#{name}>"  if e
			#"#{b}\n"
			t += %w[/]  unless e
			b = "<#{t.join ' '}>"
			b += "#{e.call}</#{name}>"  if e
			b
		end
		alias tag method_missing

		def classes pre, *p
			p.collect do |i|
				pre = nil  if '' == pre
				i = nil  if '' == i
				if pre && i
					"#{pre}_#{i}"
				else
					(pre || i).to_s
				end
			end.join ' '
		end
	end
end

class Tagen::ConfTable <Array
	attr_accessor :name, :tagen
	def initialize name = nil, *paras
		super( *paras)
		name ||= 'conftable'
		@name, @tagen = name.to_s, Tagen.new
	end

	def gen_line i
		x = case i
		when 0 then :first
		when self.size then :last
		else :body
		end
		@tagen.tr( :class => ["r#{i%2}", x]) do
			@tagen.td( :class => :r0) do
				self[i][0]
			end +
			@tagen.td( :class => :r1) do
				self[i][1]
			end
		end
	end

	def gen
		@tagen.table( :class => @name) do
			(0...self.size).collect do |i|
				self.gen_line i
			end.join
		end
	end
end

class Tagen::Input
	def initialize cgi = nil, data = nil
		@cgi, @data = cgi || Tagen.new, data || {}
	end

	def time n, f = '%h:%m'
		self.digits( "#{n}_hour", Time.now.hour, 2) + ' : ' +
			self.digits( "#{n}_min", Time.now.min, 2)
	end

	def date n, f= '%h:%m'
		self.digits( "#{n}_day", Time.now.day, 2) + ' . ' +
			self.digits( "#{n}_month", Time.now.month, 2) + ' . ' +
			self.digits( "#{n}_year", Time.now.year, 4)
	end

	def digits n, v = nil, d = nil, c = nil
		n = n.to_s
		v ||= ''
		d = d ? { :size => d, :length => d } : {}
		@cgi.input d.update( :class => [:digits, c], :type => :text, :name => n,
				:id => n, :value => @data[ n]||v)
	end
end

class Tagen::InputRadio <Array
	attr_accessor :name, :checked, :tagen
	def initialize name, *paras
		super( *paras)
		@checked, @name, @tagen = nil, name, Tagen.new
	end

	def gen
		self.collect do |k|
			@tagen.span( :style => 'white-space: nowrap') do
				@tagen.input( :type => :radio, :name => @name, :value => k[0],
					:id => "#{@name}_#{k[0]}", :checked => @checked == k[0]) +
				@tagen.label( :for => "#{@name}_#{k[0]}") { k[1] }
			end
		end.join ' '
	end
end

class Tagen::Select <Array
	attr_accessor :name, :selected, :tagen, :uri

	def initialize name, *paras
		super( *paras)
		@name, @tagen, @simple = name, Tagen.new, true
	end

	def gen uri = nil
		uri ||= @uri || '.'
		uri = URI.parse uri  unless uri.kind_of? URI
		@tagen.form( :action => uri) do
			@tagen.select( :name => @name, :id => @name) do
				body = self.collect do |k|
					@tagen.option( :value => k[0],
							:selected => @selected == k[0]) { k[1] }
				end.join
			end + @tagen.input( :type => :submit)
		end
	end
end

class Tagen::SelectMenu <Tagen::Select
	attr_accessor :title, :css_class, :cols

	def initialize title, *paras
		super nil, *paras
		@title = title
	end

	def gen uri = nil, css_class = nil, cols = nil
		uri ||= @uri
		css_class ||= @css_class
		cols ||= @cols || 1
		uri = URI.parse uri  unless uri.kind_of? URI
		@tagen.span( :class => [:select, css_class]) do
			@tagen.span( :class => :selector) { @title }+
			@tagen.span( :class => :subselect) do
				(0...self.length).collect do |i|
					k = self[ i]
					u = uri.dup
					if @name
						u.query = "#{u.query && "#{u.query}&"}#{@name}=#{k[0]}"
					else
						u.path += "/#{k[0]}"
					end
					@tagen.a( :href => u.to_s) { k[1] }
				end.join @tagen.span( :class => %w{spacer hide}) { ' | ' }
			end
		end
	end
end

class Tagen::Table <Array
	class Column
		attr_reader :title, :class
		def initialize opts
			if x = opts[:value] || opts[:name]
				self.gen_meth :value, x
			else
				raise "Need Proc to get value (:name => '...' or :value => lambda{...})"
			end

			@title, @class = opts[:title], opts[:class]

			if x = opts[:sort]
				self.gen_meth :sort, x
			elsif x = opts[:compare] || opts[:name]
				if x.kind_of? Proc
					self.gen_meth :sort do |i|
						i.sort &x
					end
				else
					eval <<-EOS
						class <<self
							def sort i
								i.sort do |a, b|
									a.#{x} <=> b.#{x}
								end
							end
						end
					EOS
				end
			end
		end

		def gen_meth name, call=nil, &e
			call = e  if e
			raise ArgumentError, 'I need something to call.'  unless call
			o = if call.kind_of? Proc
				eval "@#{name} = call"
				"@#{name}.call o"
			else "o.#{call}"
			end
			eval <<-EOM
				class <<self
					def #{name} o
						#{o}
					end
				end
			EOM
		end
	end

	attr_reader :name, :tagen, :sort_by, :reverse
	def initialize name, tagen = nil
		@name, @tagen = name, tagen || Tagen.new
	end

	def sort_by= value
		@sort_by, @reverse = if [ '', nil ].include? value
				[ false, false ]
			else
				value = value.to_i
				value < 0 ? [ ~value, true ] : [ value, false ]
			end
	end

	def push value
		value = Column.new value  unless value.class == Column
		super value
	end

	def []= key, value
		value = Column.new value  unless value.class == Column
		super key, value
	end

	def gen_abstract a, &p
		case a.size
		when 0 then ''
		when 1 then p.call a, 0, 'first last'
		else
			p.call( a, 0, 'first') +
			(1...a.size-1).collect do |i|
				p.call a, i, 'body'
			end.join +
			p.call( a, a.size-1, 'last')
		end
	end
	alias gen_abstract_td gen_abstract
	alias gen_abstract_th gen_abstract
	alias gen_abstract_tr gen_abstract

	def sort array
		array = self[ @sort_by].sort array  if @sort_by && self[ @sort_by].respond_to?( :sort)
		array.reverse!  if @reverse
		array
	end

	def generate array
		@tagen.table :id => @name, :class => :table do
			@tagen.thead do
				@tagen.tr do
					self.gen_abstract_th self do |a, i, p|
						t = a[i].title
						l, d = if @sort_by == i
							if @reverse
								[ i, 'sorted reverse' ]
							else [ ~i, 'sorted' ]
							end
						else [ i, 'normal' ]
						end
						@tagen.th :class => [p, d, "r#{i%2}"] do
							if a[i].respond_to? :sort
								@tagen.a :href => "?#{@name}_sortBy=#{l}" do
									t
								end
							else t
							end
						end
					end
				end
			end +
			@tagen.tbody do
				self.gen_abstract_tr self.sort( array) do |a, i, p|
					@tagen.tr :class => [p, "row#{i}", "r#{i%2}"] do
						self.gen_abstract_td self do |b, j, p|
							@tagen.td :class => [p, "c#{j%2}", "col#{j}", @sort_by == j ? 'sorted' : ''] do
								b[j].value a[i]
							end
						end
					end
				end
			end
		end
	end
end

class Tagen::Directory < Tagen::Table
	attr_reader :opened
	
	def initialize *p
		super( *p)
		@opened = []
	end

	def opened= value
		unless [ '', nil ].include? value
			value.split( ',').each &method( 'open=')
		end
	end

	def open value
		value = value.split '.'  if value.kind_of? String
		raise "Unexpected type of value instead Array: #{value.class}"  unless value.kind_of? Array
		@opened.push value.collect {|x| x.to_i }
	end
	alias open= open

	def close value
		value = value.split '.'  if value.kind_of? String
		raise "Unexpected type of value instead Array: #{value.class}"  unless value.kind_of? Array
		@opened.delete value.collect {|x| x.to_i }
	end
	alias close= close

	def generate array
		@tagen.table :id => @name, :class => :table do
			@tagen.thead do
				@tagen.tr do
					self.gen_abstract self do |a, i, p|
						t = a[i].title
						l, d = if @sort_by == i
							if @reverse
								[ i, 'sorted reverse' ]
							else [ ~i, 'sorted' ]
							end
						else [ i, 'normal' ]
						end
						@tagen.th :class => [p, d, "r#{i%2}"] do
							if a[i].respond_to? :sort
								@tagen.a :href => "?#{@name}_sortBy=#{l}" do
									t
								end
							else t
							end
						end
					end
				end
			end +
			@tagen.tbody do
				self.gen_abstract self.sort( array) do |a, i, p|
					@tagen.tr :class => [p, "row#{i}", "r#{i%2}"] do
						self.gen_abstract self do |b, j, p|
							@tagen.td :class => [p, "c#{j%2}", "col#{j}", @sort_by == j ? 'sorted' : ''] do
								b[j].value a[i]
							end
						end
					end
				end
			end
		end
	end
end

class Tagen::VerticalLinks <Array
	def join
		Tagen.span( :class => 'vertical-links') do
			super Tagen.span( :class => 'spacer') {' | '}
		end
	end
	alias to_s join
end

class Tagen::WebSearch
	attr_accessor :text, :tagen
	def icon()  ''  end
	def title()  ''  end

	def initialize text = nil
		@text, @tagen = text, Tagen.new
	end

	def gen text = nil
		raise ArgumentError, 'No Title to search'  unless text ||= @text
		t = self.icon ? @tagen.img( :src => self.icon) : ''
		t += self.title || ''
		@tagen.a( :href => self.uri( text), :target => :_blank) { t }
	end
end

class Tagen::IMDb < Tagen::WebSearch
	def uri( t)  "http://imdb.com/find?s=all&q=#{CGI.escape t}"  end
	def icon()  'http://imdb.com/favicon.ico'  end
end

class Tagen::Wikipedia < Tagen::WebSearch
	def uri( t)
		"http://de.wikipedia.org/wiki/Spezial:Suche?go=Artikel&search=#{CGI.escape t}"
	end
	def icon()  'http://de.wikipedia.org/favicon.ico'  end
end
