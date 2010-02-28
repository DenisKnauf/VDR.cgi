def Kernel.debug( line)
	STDERR.puts "#{caller[0]}: #{line}"
end

def debug_func c, f
	ff = case f
		when /^(.*)\?$/ then "#{$1}_f"
		when /^(.*)\!$/ then "#{$1}_a"
		when /^(.*)=$/ then "#{$1}_g"
		when "<<"       then "_s"
		when "+"        then "_p"
		when "-"        then "_m"
		when "@+"       then "_P"
		when "@-"       then "_M"
		else "#{f}_n"
		end
	wf = "__wrapped_#{c.object_id.to_s.sub /^-/, "x"}_#{ff}__".intern
	return "#{c}##{f} already exists"  if c.instance_methods.include? wf
	pre = "\#{\"%x\"%self.hash.abs}:#{c}##{f}"
	c.class_eval <<-EOF
		alias #{wf} #{f}
		def #{f} *args, &e
			ret = if e
					STDERR.puts "==>#{pre} \#{args.collect {|i| i.inspect }.join
", "}, &\#{e.inspect}"
					#{wf} *args, &e
				else
					STDERR.puts "==>#{pre} \#{args.collect {|i| i.inspect }.join
", "}"
					#{wf} *args
				end
			#STDERR.puts "<==#{pre}"
			ret
		rescue Object
			STDERR.puts "<==#{pre} EXCEPTION: \#{$!.inspect}"
			Kernel.raise
		end
	EOF
end

def debug_class c, fs
	c.instance_methods.grep fs do |f|
		debug_func c, f
	end
end
