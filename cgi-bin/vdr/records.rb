class VDR::Records
	attr_reader :number, :time, :seen, :title

	def initialize *opts
		self.number, self.time, self.seen, self.title = if opts.size == 1
				if m = /^(\d+)\s+(\d{1,2}\.\d{1,2}\.\d{1,4}\s+\d{1,2}:\d{1,2})(\S*)\s+(.*)$/.match( opts[0])
					m[1..-1]
				else Kernel.options opts, %W[num number], :time, :seen, :title
				end
			else opts
			end
	end

	def number= value
		value = value.to_i  if value.kind_of? String
		Kernel.expect Integer, value
		@number = value
	end

	def time= value
		if value.kind_of? String
			value = if m = /^\s*(\d{1,2})\.(\d{1,2})\.(\d{1,4})\s+(\d{1,2}):(\d{1,2})\s*$/.match( value)
				m = m[1..-1].collect do |i|
					i.to_i
				end
				Time.local( (m[2]<2000 ? m[2]+2000 : m[2]), m[1], m[0], m[3], m[4])
			else value.to_i
			end
		end
		value = Time.at value  if value.kind_of? Integer
		Kernel.expect Time, value
		@time = value
	end

	def title= value
		value = value.split /~/  if value.kind_of? String
		Kernel.expect Array, value
		def value.to_s()  join '/'  end
		@title = value
	end

	def seen= value
		@seen = value != ''
	end

	def seen?
		@seen
	end

	def to_i
		@number
	end
end
