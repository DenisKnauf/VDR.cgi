
require 'syslog'
Syslog.open 'vdr-cgi', Syslog::LOG_NDELAY | Syslog::LOG_PERROR, Syslog::LOG_DAEMON

class Object
	def darkknight s = '%s'
		Syslog.debug s, self.inspect
		self
	end
end

require 'active_support'
require 'zlib'
require 'bdb'

%w[i18n cgi-extend vdr options v2h style epg timer records].each do |r|
	require File.join( File.dirname( __FILE__), r)
end

EPGDATA = '/exports/vdr/epg.data'

class String
	def no?()  !self.yes?  end
	def yes?
		case self.downcase
		when 'not', 'no', 'false', '0': false
		when 'sure', 'yes', 'true', /^\d+$/: true
		else false
		end
	end
end

class Object
	def with( &e)  e.call self  end
end

class IO
	def with &e
		r = e.call self
		self.close
		r
	end
end

class I18N
	@@translations ||= {}
	class <<@@translations
		def [] key
			unless self.entry( key)
				self[ key] = BDB::Hash.new '/var/lib/svdrpd/i18n.db',
						key.to_s, BDB::CREATE
				class << self.entry( key)
					alias :entry :[]  unless method_defined? :entry
					attr_accessor :unknown

					def [] ekey
						unless r = self.entry( ekey)
							@unknown.push ekey
							@unknown.uniq!
							r = ekey
						else r
						end
					end
				end
				self.entry( key).unknown = []
			end

			self.entry key
		end
	end
end

def main vdr, cgi
	data, cookies, cgi, env = {}, {}, cgi, cgi.env_table
	cgi.params.each {|k, v| data[k] = v[0] }

	cgi.cookies['svdrp.rb'].each do |i|
		if i =~ /^(.*?)=(.*)$/
			cookies[$1] = $2
		end
	end

	conf = V2H::Conf.new Tagen.new, vdr, Options.new( data, cookies),
			env[ 'SCRIPT_NAME']
	path = File.expand_path( env[ 'PATH_INFO'] || '').split '/'
	path.shift
	class <<path
		attr_accessor :path
	end
	path.path = env[ 'PATH_INFO'].darkknight

	$LANG = if conf.opts[ 'language']  then conf.opts[ 'language']
	elsif env[ 'HTTP_ACCEPT_LANGUAGE'] && ! env[ 'HTTP_ACCEPT_LANGUAGE'].empty?
		env[ 'HTTP_ACCEPT_LANGUAGE'].gsub( /\s/, '').split( ',')[0]
	else 'en'
	end

	data = begin
		case path.shift
		when 'style'
			cgi.out 'type' => 'text/css' do
				Style.new[ :default]
			end

		when 'redirect': conf.redirect conf.opts.over[ 'path']
		when 'epg': V2H::EPG.new( conf)[path]
		when 'timer': V2H::Timer.new( conf)[path]
		when 'records': V2H::Records.new( conf)[path]

		when 'i18n'
			case path.shift
			when 'push'
				l = cgi.params[ 'language'][ 0]
				cgi.params.each do |k, v|
					v = v.to_s
					if k[ 0...6] == 'trans_' && !v.empty?
						I18N.set CGI.unescape( k[ 6..-1]), v, l
					end
				end
				conf.redirect path.join( '/')

			when nil
				t = Tagen::Table.new 'translations'
				t.push :title => -'Original', :value => lambda { |o|
						o = o[ 0].to_s
						Tagen.label( :for => "trans_#{CGI.escape( o)}") { o }
					}
				t.push :title => -'Translation', :value => lambda { |o|
						Tagen.input :type => :input,
								:id => "trans_#{CGI.escape( o[0].to_s)}",
								:name => "trans_#{CGI.escape( o[0].to_s)}",
								:value => CGI.escapeHTML( o[1].to_s)
					}
				u = Tagen.form( :method => :post,
						:action => conf.urlgen( 'i18n/push',
							env['PATH_INFO'])) do
					Tagen.h1 { -'Language:' + " #{$LANG}" } +
					Tagen.input( :type => 'hidden', :language => $LANG) +
					t.generate( I18N.hash[ $LANG].to_hash.to_a) + 
					Tagen.input( :type => :submit, :value => -'Submit')
				end
				V2H::Data.new [], -'Translations', u

			else
				V2H::Data.new [], -'Ups' do
					-'I don\'t know, what you want. :-/'
				end
			end

		when 'confirm'
			V2H::Data.new [], -'Confirm' do
				o = conf.opts.over
				text = o['confirm_text'] || ''
				text = Zlib::Inflate.inflate text  if (o['confirm_compressed']||'').yes?
				p = path.join( '/').split '|', 2
				text.gsub( /[\n<>]/, &{"\n" => Tagen.br, '<' => '&lt;',
						'>' => '&gt;'}.method( '[]')) +
				Tagen.br*2 +
				Tagen.a( :href => conf.urlgen( p[0])) { Tagen.b { -'Yes' } } +
				'&nbsp;'*4 +
				Tagen.a( :href => conf.urlgen( :var => p[1],
						:alt => 'records')) { Tagen.b { -'No' } }
			end

		when nil: conf.redirect 'epg'

		else V2H::Data.new [], -'SVDRPD2HTTP', ''
		end
	
	rescue SystemExit
		# Everything OK -- raise it again
		raise
	rescue Errno::ECONNREFUSED
		V2H::Data.new [], -'Connection refused', -"I can't connect to server. Check your server."
	rescue Object
		conf.rescued $!
	end

	opts = {
		'type' => 'text/html',
		'Cache-Control' => 'no-cache',
		'Pragma' => 'no-cache'
	}
	cookies = conf.opts.to_h.collect { |k, v| "#{k}=#{v}" }
	opts['cookie'] = CGI::Cookie.new 'svdrp.rb', *cookies  unless cookies.empty?

	data ||= conf.unknown_page ''
	data = V2H::Data.new [], '', data  if data.kind_of? String

	cgi.out opts do
		'<?xml version="1.0" encoding="UTF-8" ?>' +
		'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1 Strict//EN" ' +
				'"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' +
		Tagen.html( :xmlns => "http://www.w3.org/1999/xhtml",
				'xml:lang' => :de) do
			Tagen.head do
				Tagen.title do data.title end +
				Tagen.meta( 'http-equiv' => :Pragma, :content => 'no-cache') +
				Tagen.link( :rel => :stylesheet, :type => 'text/css',
						:href => conf.urlgen( 'style')) +
				data.head.join
			end +
			Tagen.body do
				links = [
						[ :epg, :EPG ], [ :timer, :Timer ],
						[ :records, :Records ], [ :i18n, :Translations ]
					].collect do |l|
						Tagen.a( :href => conf.urlgen( l[0])) { -l[1].to_s }
					end
				links = Tagen::VerticalLinks.new links

				d = Tagen.div( :style => 'text-align: center') { links.to_s } +
					Tagen.hr( :class => :spacer) +
					data.body
				b = Tagen.input :type => :submit, :value => -'Submit'
				u = Tagen.h5() { -'Unknown Translations:' }

				t = Tagen::Table.new( 'translations').with do |t|
					t.push :title => -'Original', :value => lambda { |o|
						Tagen.label( :for => "trans_#{CGI.escape o}") { o.to_s }
					}
					t.push :title => -'Translation', :value => lambda { |o|
						Tagen.input :type => :input,
								:id => "trans_#{CGI.escape o}",
								:name => "trans_#{CGI.escape o}"
					}
				end

				c = I18N.translations[ $LANG.to_sym].unknown
				u += Tagen.form( :method => :post, :action =>
						conf.urlgen( 'i18n/push', env['PATH_INFO'])) do
					Tagen.input( :type => :hidden, :language => $LANG) +
					t.generate( c) + b
				end
				d + (c.empty? ? '' : u)
			end
		end +
		"\n"
	end

rescue SystemExit
	# Everything OK
rescue Object
	Syslog.err "#{$!} (#{$!.class}) -- #{$!.backtrace.join"\n\t"}"  if $!
	begin
		if $!
			cgi.out { "<hr/><strong>Exception: </strong><em>#{CGI.escapeHTML $!.to_s} (#{CGI.escapeHTML $!.class.to_s}), #{CGI.escapeHTML $!.backtrace.join( "<br/>")}</em>" }
		end
	end
end
