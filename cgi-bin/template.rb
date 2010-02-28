require 'bdb'

class Template
	attr_reader :template, :vars, :i18n
	def initialize template, vars = Hash.new, i18n = Hash.new
		@template, @vars, @i18n = template, vars, i18n
	end

	def [] key
		@template[ key]
	end

	def var k, vars = Hash.new
		vars[k] || vars[k.to_sym] \
			|| @vars[k] || @vars[k.to_sym] \
			|| @@vars[k] || @@vars[k.to_sym] \
			|| k
	end

	def translate s, i18n = Hash.new
		i18n[s] || @i18n[s] || @@i18n[s] || s
	end

	def generate tmpl, vars = Hash.new, i18n = Hash.new
		self[t].gsub( /(^|[^\\])#\{(([^}]|\})*)\}/) do
			$1 + self.translate( $2.gsub( '\}', '}'), i18n)
		end.gsub /(^|[^\\])\$\{(\w+)\}/) do
			$1 + self.var( $2, vars)
		end
	end
end
