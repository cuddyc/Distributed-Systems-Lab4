
require 'socket'

class Client
  def initialize( server )
    @server = server
    @request = nil
    @response = nil
    @id = ''
    listen
    send_msg
    @request.join
    @response.join
  end

  def listen
    @response = Thread.new do
      loop {
        msg = @server.gets.chomp
        puts "#{msg}"
        if msg.split[0] == 'Goodbye'
          puts 'closing connection'
          @server.close
        end
      }
    end
  end

  def send_msg
    @num = 0
    puts 'Enter message:'
    @request = Thread.new do
      loop {
        msg = ''
        begin
          msg = $stdin.gets.chomp
        end while msg == ''

        case
          when msg == 'h'
            msg = 'HELO msg from C3\n'
          when msg == 'j'
            @num += 1
            msg = 'JOIN_CHATROOM: CR'+"#{@num}"
            msg += '\nCLIENT_IP: 0\nPORT: 0\nCLIENT_NAME: Cli3\n'
          when msg == 'l'
            msg = 'LEAVE_CHATROOM: '+"#{@num}"
            msg += '\nJOIN_ID: 3\n CLIENT_NAME: Cli3\n'
            @num -=1
          when msg == 'd'
            msg = 'DISCONNECT: 0\nPORT: 0\nCLIENT_NAME: Cli3'
          when msg == 'k'
            msg = 'KILL_SERVICE\n'
          else
            line = 0
            @temp_msg = Array.new
            @temp_msg[line] = msg[1..-1]
            begin
              line += 1
              @temp_msg[line] = $stdin.gets.chomp
            end while @temp_msg[line] != ''


            @cr = msg[0]
            msg = 'CHAT: ' + "#{@cr}"
            msg += '\nJOIN_ID: 3\nCLIENT_NAME: Cli3\nMESSAGE: '
            line_num = 0
            begin
              msg += "#{@temp_msg[line_num]}"+'\n'
              line_num += 1
            end while line_num < line
            msg += '\n'
        end

        @server.puts( msg )
      }
    end
  end
end

server = TCPSocket.open( 'localhost', 2000 )
Client.new( server )