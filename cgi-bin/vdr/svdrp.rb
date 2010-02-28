require 'socket'

class Svdrp
	attr_reader :addr, :port, :sock, :firstline

#private
	def initialize addr = nil, port = nil
		@addr, @port, @sock = addr || 'localhost', port || 2001, nil
		self
	end

	def closed?
		@sock.nil? || @sock.closed?
	end

	def connect
		return true  unless closed?
		@sock = TCPSocket.new @addr, @port
		@firstline = self.cmd
	end

	def close
		@firstline = nil
		@sock.close
	end

	def puts line
		@sock.puts line  if connect
	rescue Errno::EPIPE
		close
		retry
	end

	def gets
		line = @sock.gets
		return nil  if line.nil?
		/^(\d\d\d)([ -])(.*?)[\n\r]*$/.match line
		[ $2 == ' ', $1.to_i, $3 ]
	end

	def Svdrp.vdr_command cmd, np = 0, op = 0
		cmd = cmd.to_s
		ps = (0...np).to_a.collect { |i| "p#{i}" }
		ps+= (np...(np+op)).to_a.collect { |i| "p#{i} = ''" }
		pu = [ "#{cmd}" ]
		pu+= (0...(np+op)).to_a.collect { |i| "\#\{p#{i}\}" }
		ps.push "&e"
		eval <<-EOC.gsub( /^\t+/, '')
			def #{cmd} #{ps.join ', '}
				if e.nil?
					self.cmd "#{pu.join( " ")}"
				else
					self.cmd "#{pu.join( " ")}", &e
				end
			end
		EOC
	end

public
	def cmd line = nil, &e
		unless e
			a = Array.new
			e = lambda do |last, err, line|
				a.push [err, line]
			end
		end
		ret = nil
		puts line  unless line.nil?
		last = false
		until last
			last, err, line = gets
			next  unless last
			ret = e.call last, err, line
		end
		ret
	end

	vdr_command :chan, 0, 1
	vdr_command :clre
	vdr_command	:delc, 1
	vdr_command :delr, 1
	vdr_command :delt, 1
	vdr_command :edit, 1
	vdr_command :grab, 1, 4
	vdr_command :help, 0, 1
	vdr_command :hitk, 0, 1
	vdr_command :lstc, 0, 1
	vdr_command :lste, 0, 2
	vdr_command :lstr, 0, 1
	vdr_command :lstt, 0, 1
	vdr_command :mesg, 0, 1
	vdr_command :modc, 2
	vdr_command :modt, 2
	vdr_command :movc, 2
	vdr_command :movt, 2
	vdr_command :newc, 1
	vdr_command :newt, 1
	vdr_command :next, 0, 1
	vdr_command :play, 1, 1
	vdr_command :plug, 1, 2
	vdr_command :pute
	vdr_command :scan
	vdr_command :stat, 1
	vdr_command :updt, 1
	vdr_command :volu, 0, 1
	vdr_command :quit
end
