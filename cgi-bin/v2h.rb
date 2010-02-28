require 'cgi-extend'
require 'options'
require 'i18n'

class NoPage <RuntimeError
end

class V2H
	class Data
		attr_reader :head, :title, :body, :links
		def initialize head = nil, title = nil, body = nil, links = nil, &e
			body = e.call  unless body
			@head, @title, @body, @links =
				head||'', title||'', body||'', links||''
		end
	end

	class Conf
		attr_reader :cgi, :vdr, :opts, :link
		def initialize *opts
			@cgi, @vdr, @opts, @link, @wap = 
				Kernel.options( opts, :cgi, :vdr, %W[opts options], :link, :wap)
		end

		def unknown_page e
			V2H::Data.new [], -'Uknown Page', e
		end

		def rescued e
			text = -'I don\'t know, what you want.'+
				"<hr/>#{CGI.escapeHTML e.to_s} (#{CGI.escapeHTML e.class.to_s})<br/>"+
				e.backtrace.collect( &CGI.method( :escapeHTML)).join( '<br/>')
			V2H::Data.new [], -'Exception Raised', text
		end

		def urlgen *paras
			paras = Kernel.str_options paras, :pre, :var, :alt, :suf
			opts = if paras.last.kind_of? Hash
				o = paras.last.collect do |k, v|
					"#{k}=#{CGI.escape v.to_s}"  \
							unless [:pre, :var, :alt, :suf].include? k
				end.compact.join ';'
				o == '' ? '' : '?' + o
			else ''
			end
			paras[1] ||= paras[2]
			paras[2] = paras[3]
			paras.unshift @link || ''
			paras[0...4].compact.collect do |i|
				j = i.kind_of?( Array) ? i.join( '/') : i.to_s
				j.gsub( /([^a-z0-9_\-\/.,+()])/i) do |c|
					'%%%02s' % c[0].to_s( 16)
				end
			end.join( '/').gsub( /\/+/, '/') + opts
		end

		def confirm *paras, &e
			paras = Kernel.str_options paras, :pre, :var, :alt, :suf, :class, :txt
			opts = if paras.last.kind_of? Hash
				o = paras.pop
				txt = paras[5] || o[:confirm_text]
				o[:confirm_text] = txt  if txt
				unless o.empty?
					o = o.collect do |k, v|
						"#{k}=#{CGI.escape v.to_s}" \
							unless [:pre, :var, :alt, :suf, :class, :txt].include? k
					end.compact.join ';'
					o == '' ? '' : '?' + o
				else ''
				end
			else ''
			end
			paras[1] ||= paras[2]
			paras[2] = paras[3]
			paras.unshift 'confirm'
			paras.unshift @link || ''
			@cgi.a :href => paras[0...5].join( '/').gsub( /\/+/, '/') + opts,
				:class => paras[6], &e
		end

		def redirect *paras
			{ :redirect => self.urlgen( *paras) }.darkknight
			$stdout.puts <<EOF
Status: 301
Location: #{self.urlgen *paras}
Content-Type: text/text
Content-Length: #{'Redirect... '.size}

Redirect...
EOF
			exit 0
		end

		def fail key
			raise NoPage
		end
	end

	module V2HModule
		attr_reader :conf

		def initialize conf
			@conf = conf
		end
	end

	class V2HContainer
		include V2HModule
	end
end
