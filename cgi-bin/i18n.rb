
$LANG ||= ENV['LANG']
$LANG = :en  if !$LANG || $LANG.empty?

class I18N
	unless defined? @@translations
		@@translations = {}

		class << @@translations
			alias :entry :[] unless method_defined? :entry

			def [] key
				unless self.entry key
					self[ key] = {}
					class << self.entry( key)
						alias :entry :[] unless method_defined? :entry

						def [] ekey
							self.entry( ekey) || ekey
						end
					end
				end

				self.entry key
			end
		end
	end

	class <<I18N
		def set str, trans, lang = nil
			@@translations[(lang || $LANG || :en).to_sym][str] = trans
		end

		def []= str, a, b = nil
			trans, lang = b.nil? ? [ a, $LANG||:en ] : [ b, a ]
			p trans, lang
			lang = lang.to_sym
			{ :orig => str, :lang => lang, :trans => rans.inspect }.darkknight
			@@translations[lang][str] = trans
		end

		def get str, lang = nil
			lang ||= $LANG||:en
			lang = lang.to_sym
			@@translations[lang][str]
		end
		alias call get
		alias [] get

		def translations
			@@translations
		end
		alias hash translations
	end
end

class String
	def i18n lang = nil
		I18N[ self, lang]
	end

	def i18n! lang = nil
		self.replace i18n( lang)
	end

	def i18n= trans
		I18N[ self] = trans
	end

	def -@
		self.i18n
	end

	alias :element_reference :[] unless method_defined? :element_reference
	def [] *par
		if par.length == 1 and par[0].class == Symbol
			I18N[*par]
		else
			self.element_reference( *par)
		end
	end

	alias :element_reference= :[]= unless method_defined? :element_reference=
	def []= *par
		if par.length == 2 and par[0].class == Symbol
			I18N.[]= *par
		else
			element_reference= *par
		end
	end

	@@ksub ||= {}
	def String.ksub= hash
		@@ksub = hash
	end

	def ksub hash
		self.gsub( /(^|[^\\])\$\{(\w+)\}/) do
			$1 + ( hash[$2.to_sym] || hash[$2] || @@ksub[$2.to_sym] || @@ksub[$2] || $2 )
		end
	end

	alias :__procent__ :%  unless method_defined? :__procent__
	def % par
		if par.class == Hash
			self.ksub par
		else
			self.__procent__ par
		end
	end
end
