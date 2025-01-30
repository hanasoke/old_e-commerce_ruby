require 'webrick'

# Running on localhost:3001
server = WEBrick::HTTPServer.new(Port: 3301)

server.mount_proc '/' do |req, res|
    res.body = 'Hello, this is a different server!'
end 

trap 'INT' do 
    server.shutdown
end 

server.start