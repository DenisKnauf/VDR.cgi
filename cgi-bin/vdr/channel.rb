require 'options'

class VDR::Channel
	attr_reader :vdr, :number, :names, :bouquet, :frequency, :parameters
	attr_accessor :source, :srate, :vpid, :apid, :tpid, :sid, :nid, :tid, :rid

	def initialize vdr, *pa
		@vdr = vdr
		self.number, self.names, self.frequency, self.parameters, self.source,
			self.srate, self.vpid, self.apid, self.tpid, self.sid, self.nid,
			self.tid, self.rid   =   if pa.size == 1 && pa[0].kind_of?( String)

				pa, n = pa[0], 0
				n, pa = $1, $2  if /^(\d+) +(.*)$/.match pa
				[ n ] + pa.split( ':')
			else
				pa
			end
	end

	def number= value
		value = value.to_i
		Kernel.expect Fixnum, value
		@number = value
	end

	def names= value
		value = value.split ','  if value.kind_of? String
		Kernel.expect Array, value
		value[-1], @bouquet = value[-1].split ';'
		@names = value
	end

	def bouquet= value
		Kernel.expect String, value
		@bouquet = value
	end

	def frequency= value
		value = value.to_i
		Kernel.expect Integer, value
		@frequency = value
	end

	def parameters= value
		value ||= ''
		Kernel.expect String, value
		@parameters = value
	end
end
