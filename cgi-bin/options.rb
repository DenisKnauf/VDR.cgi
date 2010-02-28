module Kernel
	def expect expect, get, message = nil
		if expect.class == Array
			ret = true
			expect.each do |expect|
				return  if expect === get
			end
		else
			return  if expect === get
		end
		raise ArgumentError, message || "Expected: #{expect.inspect}, Got: #{get.inspect}", caller  unless expect === get
	end

	def str_options opts, *list
		if opts[-1].kind_of?(Hash)
			o = opts.pop
			list = o.options *list
			(0...list.size).to_a.collect do |i|
				opts[i] || list[i]
			end.push o
		else opts
		end
	end

	def options opts, *list
		opts = opts[0].options *list  if opts.size == 1 && opts[0].kind_of?( Hash)
		opts
	end

	def consts_multiset i, *names
		names = names.split /\s+/  if names.kind_of? String
		names = names[0].split /\s+/  if names.kind_of?( Array) && names.length == 1 && names[0].kind_of?( String)
		names.each do |n|
			next  if n.empty?
			remove_const n  if const_defined? n
			const_set n, i
		end
	end
end

class Hash
	def options *list
		list.collect do |l|
			if l.kind_of? Array
				self[ (l & opts.keys)[0] ]
			else self[l]
			end
		end
	end
end

class Options <Hash
	attr_reader :data, :over
	def initialize over, data
		@over, @data = over, data
	end

	def [] key
		v = super key
		if v  then v
		elsif @over[key]
			self[key] = @over[key]
		else
			@data[key]
		end
	end

	def to_h
		@data.update self
	end
end
