
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require 'async'
require 'async/io/stream'
require 'async/http/endpoint'
require 'protocol/http2/client'
require 'pry'

Async.run do
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com/search?q=kittens")
	
	peer = endpoint.connect
	
	puts "Connected to #{peer.inspect}"
	
	# IO Buffering...
	stream = Async::IO::Stream.new(peer)
	
	framer = Protocol::HTTP2::Framer.new(stream)
	client = Protocol::HTTP2::Client.new(framer)
	
	puts "Sending connection preface..."
	client.send_connection_preface
	
	puts "Creating stream..."
	stream = client.create_stream
	
	headers = [
		[":scheme", endpoint.scheme],
		[":method", "GET"],
		[":authority", "www.google.com"],
		[":path", endpoint.path],
		["accept", "*/*"],
	]
	
	puts "Sending request on stream id=#{stream.id} state=#{stream.state}..."
	stream.send_headers(nil, headers, Protocol::HTTP2::END_STREAM)
	
	puts "Waiting for response..."
	$count = 0
	
	def stream.process_headers(frame)
		headers = super
		puts "Got response headers: #{headers} (#{frame.end_stream?})"
	end
	
	def stream.receive_data(frame)
		data = super
		
		$count += data.scan(/kittens/).count
		
		puts "Got response data: #{data.bytesize}"
	end
	
	until stream.closed?
		frame = client.read_frame
	end
	
	puts "Got #{$count} kittens!"
	
	binding.pry
	
	puts "Closing client..."
	client.close
end

puts "Exiting."
