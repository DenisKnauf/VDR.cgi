require 'cgi'
require 'sass'

class Style
	def initialize
		@styles = {
			:default => <<-STYLE.gsub( /\t/, '  ').gsub( /^ {8,8}/, '')
				!linkcolor = #0000A0
				!tablecolor = #FAFAFA
				!tablecolorsorted = !tablecolor - 8
				!actioncolor = #F00
				!background = #EEE


				html, body
					:background = !background
				a
					:color = !linkcolor
					:text-decoration none
					&:hover, &:active
						:text-decoration underline
					&.prerecord, &.postrecord, &.fullrecord
						:font-style italic
						:color = !actioncolor
					&.record
						:font-weight bold
						:color = !actioncolor
					&.delete
						:font-weight bold
						:color = !actioncolor - 16


				table
					:border-collapse collapse
					:white-space nowrap
					a
						:display block
					thead tr
						th
							:border 1px solid white
							:border-top none
							:text bold
							:padding .5ex
							:background = !tablecolor
							&.first
								:border-left none
							&.last
								:border-right none
							a:before
								:visibility hidden
								:content "\\\\/"
							a:hover, a:focus, a:active
								&:before
									:visibility visible
							&.reverse a
							&.sorted
								:background = !tablecolorsorted
								a:before
									:visibility visible
								a:hover, a:focus, a:active
									&:before
										:visibility visible
										:content "/\\\\"
								&.reverse
									a:before
										:visibility visible
										:content "/\\\\"
									a:hover, a:focus, a:active
										&:before
											:visibility visible
											:content "\\\\/"

					tbody tr
						td
							:border 1px solid white
							:padding .5ex
							&.first
								:border-left none
							&.last
								:border-right none
						&.last td
							:border-bottom none
						&.r1 td
							:background = !tablecolor
							&.sorted
								:background = !tablecolorsorted
						&.r0 td
							:background = !tablecolor - 16
							&.sorted
								:background = !tablecolorsorted - 16


				.select
					:position relative
					.subselect
						:display none
						:position absolute
						:background = !background
						:padding
							:right 1ex
							:left 1ex
						:border 1px black solid
					&:hover
						.subselect, .subselect *
							:display block
							.hide
								:display none
			STYLE
		}
	end

	def [] style
		Sass::Engine.new( @styles[ style.to_sym]).render
	end
end
