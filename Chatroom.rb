require 'socket'
require 'thread'

class ChatRoom

  def initialize(name)
    @cr_members = Hash.new
    @name = name
  end

  def add(nickname, client)
    if !@cr_members[nickname]
      @cr_members[nickname] = client

      @cr_members.each do |nn, client|
        if client and nn != nickname
          client.puts "#{nickname} has joined #{@name} chatroom"
        end
      end

    end
  end

  def broadcast(ref, nickname, message)
    text = message.join('\n')
    msg = 'CHAT: '+"#{ref}"
    msg += '\nCLIENT_NAME: '+"#{nickname}"
    msg += '\nMESSAGE: '+"#{text}"+'\n\n'
    puts "#{msg}"
    @cr_members.each do |nn, client|
      if client and nn != nickname
        client.puts msg
      end
    end
  end

  def leave(nickname)
    @cr_members[nickname] = nil

    @cr_members.each do |nn, client|
      if client and nn != nickname
        client.puts "#{nickname} has left #{@name} chatroom"
      end
    end

  end

  def check_members(nickname)
    c = 0
    @cr_members.each do |nn, client|
      if client and nn == nickname
        c += 1
        #leave(nn)
      end
    end
    return c
  end

end

class Pool


  def initialize(size)

    # Size thread pool and Queue for storing clients
    @size = size
    @jobs = Queue.new

    @@clientNum = 0
    @@roomNum = 0
    @@rooms = Hash.new
    @@c_rooms = Hash.new
    @@members = Hash.new
    @@memByID = Hash.new

    # Creating our pool of threads
    @pool = Array.new(@size) do |i|
      Thread.new do
        Thread.current[:id] = i

        catch(:exit) do
          loop do
            worker(i)
          end
        end

      end
    end

  end

  def worker(i)
    client = @jobs.pop
    sleep rand(i)                 # simulating different work loads
    @message = client.gets.chomp
    puts "#{@message}"

    case @message
      when /HELO .*\n/
        helo(client, @message)
      when /JOIN_CHATROOM:.*\n/
        join_cr(client, @message)
      when /CHAT:.*\n/
        chat(client, @message)
      when /LEAVE_CHATROOM:.*\n/
        leave_cr(client, @message)
      when /DISCONNECT:.*\n/
        disconnect(client, @message)
      when /KILL_SERVICE.*\n/
        kill_server
      else
        unknown(client, @message)
    end
  end

  def helo(client, msg)
    @ipAddr = client.peeraddr[3].to_s
    @reply = "#{msg}IP: "
    @reply += "#{@ipAddr}"
    @reply += '\nPort: '
    @reply += "#{@port}"
    @reply += '\nStudent Number: 98609335\n'
    client.puts("#{@reply}")
  end

  def join_cr(client, msg)

    @room = msg[/JOIN_CHATROOM:(.*)\n/,1]
    puts @room
    @nickname = msg[/CLIENT_NAME:(.*)\n/,1]

    if !@@rooms[@room]
      @roomID = @@roomNum += 1
      @@c_rooms[@roomID] = ChatRoom.new(@room)
      @@rooms[@room] = @roomID
    end

    if !@@members[@nickname]
      @clientID = @@clientNum +=1
      @@members[@nickname] = @clientID
      @@memByID[@clientID] = @nickname
    end

    @@c_rooms[@@rooms[@room]].add(@nickname, client)

    @ipAddr = client.peeraddr[3].to_s

    @reply = 'JOINED_CHATROOM: '
    @reply += "#{@room}"
    @reply += '\nSERVER_IP: '
    @reply += 'lg12l15.scss.tcd.ie' #{@ipAddr}
    @reply += '\nPort: '
    @reply += "#{@port}"
    @reply += '\nROOM_REF: '
    @reply += "#{@@rooms[@room]}"
    @reply += '\nJOIN_ID: '
    @reply += "#{@@members[@nickname]}"

    client.puts("#{@reply}")

    connected(client)
  end

  def connected(client)
    loop{
      @message = client.gets.chomp
      puts "#{@message}"

      if @message[/DISCONNECT:.*\n/]
      disconnect(client, @message)
        break
      end

      case @message
        when /HELO .*\n/
          helo(client, @message)
        when /JOIN_CHATROOM:.*\n/
          join_cr(client, @message)
        when /CHAT:.*\n/
          chat(client, @message)
        when /LEAVE_CHATROOM:.*\n/
          leave_cr(client, @message)
        when /KILL_SERVICE.*\n/
          kill_server
        else
          unknown(client, @message)
      end
    }
  end

  def chat(client, msg)
    @c_room = msg[/CHAT:(.*)\n/,1].to_i
    @clientID = msg[/JOIN_ID:(.*)\n/,1]
    @nickname = msg[/CLIENT_NAME:(.*)\n/,1]

    @checker = @@c_rooms[@c_room].check_members(@nickname)

    puts "#{@checker}"

    if @checker == 0
      client.puts('ERROR_CODE: 101\nERROR_DESCRIPTION: You have not joined this chatroom')
    else
      @chat_msg = msg[/MESSAGE:(.*)\n\n/,1]

      @@c_rooms[@c_room].broadcast(@c_room, @nickname, @chat_msg)
     end

  end

  def leave_cr(client, msg)

    @c_room = msg[/LEAVE_CHATROOM:(.*)\n/,1]
    @clientID = msg[/JOIN_ID:(.*)\n/,1]
    @nickname = msg[/CLIENT_NAME:(.*)\n/,1]

    @@c_rooms[@c_room].leave(@nickname)

    @reply = 'LEFT_CHATROOM: '
    @reply += "#{@c_room}"
    @reply += '\nJOIN_ID: '
    @reply += "#{@clientID}"

    client.puts("#{@reply}")
  end

  def disconnect(client, msg)
    @nickname = msg[/CLIENT_NAME:(.*)\n/,1]
    @checker = 0
    @@c_rooms.each_value do |cr|
      if cr
        @checker = cr.check_members(@nickname)
        if @checker
          cr.leave(@nickname)
        end

      end
    end
    client.puts('Goodbye '+"#{@nickname}")
    client.close
  end

  def kill_server
    abort('You just killed me!')
  end

  def unknown(client, msg)
    @reply = "You sent me #{msg}"
    client.puts("#{@reply}")
  end

  # ### Work scheduling
  def schedule(waitingClient)
    @jobs << waitingClient
  end

  # ### Port number to send
  def serverDetails( port )
    @port = port
  end

end

class Server

  # Open connection and create Pool instance
  def initialize( port )
    @server = TCPServer.open( port )
    puts "Server started on port #{port}"
    @serverPool = Pool.new(10)
    @serverPool.serverDetails( port )
    run
  end

  # Accept clients and put on queue
  def run
    loop{
      @client = @server.accept
      @serverPool.schedule(@client)
    }
  end

end

port = ARGV.shift
s = Server.new(port)
#s = Server.new(2000)