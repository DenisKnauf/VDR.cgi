#TODO
class V2H::Timer <V2H::V2HModule
	def [] k
		case k[0]
		#when /^\d+$/ then self.timer k
		#when 'new' then self.new k[1..-1]
		#when 'form' then self.form k[1..-1]
		#when 'delete' then self.del k[1..-1]
		when 'list', nil then self.list
		else @conf.unknown_page
		end
	end

	def list
		
	end
end
