module sawhian

# Standard libs
using Dates
using Sockets
using Base64

# External libs
using Images

import Base.show

################################################################################

Socket = TCPSocket
BufferedImage = Union{Nothing,AbstractArray}
RuntimeException = ErrorException

################################################################################

mutable struct Move
  player::Int
  pos::NamedTuple{(:x, :y),Tuple{Int,Int}}

  Move(player::Int, pos::NamedTuple{(:x, :y),Tuple{Int,Int}}) = new(player,pos)
  Move(player::Int, x::Int, y::Int) = new(player,(x=x,y=y))
end
export Move

mutable struct NetworkClient #net.NetworkClient
  socket::Union{Nothing, Socket}
  playerNumber::Int
  timeLimitInSeconds::Int
  expectedNetworkLatencyInMilliseconds::Int
  NetworkClient() = new(nothing,0,0,0)
end
export NetworkClient

################################################################################
# override print output stream

Base.show(io::IO, this::NetworkClient) = print(io, string("Player $(this.playerNumber)"))
Base.show(io::IO, this::Move) = print(io, string("p$(this.player)->$(this.pos)"))

################################################################################

getMyPlayerNumber(this::NetworkClient) = this.playerNumber
export getMyPlayerNumber

getTimeLimitInSeconds(this::NetworkClient) = this.timeLimitInSeconds
export getTimeLimitInSeconds

getExpectedNetworkLatencyInMilliseconds(this::NetworkClient) = this.expectedNetworkLatencyInMilliseconds
export getExpectedNetworkLatencyInMilliseconds

function encodeImageBase64(image::BufferedImage)
  io = IOBuffer()
  save(Images.Stream(Images.format"PNG", io), image) # color image is still a gray image on server
  base64encode(io.data)
end
#export encodeImageBase64

systemCurrentTimeMillis() = round(time())
#export systemCurrentTimeMillis

function NetworkClient(hostname::String, teamName::String, logo::BufferedImage)
  this = NetworkClient()

  (width, height) = size(logo)

  if logo == nothing || width != 256 || height != 256
    throw(RuntimeException("You have to provide a 256x256 image as your team logo")) #RuntimeException
  end

  println("Connect...")
  this.socket = connect(hostname, 22135)

  if !isopen(this.socket) println("Connect: Socket is not open!") end

  println("Handshake...")
  write(this.socket, 1)
  flush(this.socket)

  if read(this.socket, UInt8) != 1 # probably will never get this value
    throw(RuntimeException("Outdated client software - update your client!"))
  end

  println("Send Name and Pic...")
  write(this.socket, teamName*"\n")
  write(this.socket, encodeImageBase64(logo)*"\n")
  flush(this.socket)

  hostname = read(this.socket, UInt8)
  this.playerNumber = (hostname & 0x3)
  this.timeLimitInSeconds = trunc(hostname / 4)

  println("PlayerNumber: $(this.playerNumber)")
  println("TimeLimitInSeconds: $(this.timeLimitInSeconds)")

  println("Test Network Latency...")
  old = systemCurrentTimeMillis()
  write(this.socket, UInt8(0))
  flush(this.socket)
  read(this.socket, UInt8)

  this.expectedNetworkLatencyInMilliseconds = trunc(Int(systemCurrentTimeMillis() - old) / 2)
  println("Expected network latency in milliseconds: $(this.expectedNetworkLatencyInMilliseconds)")

  this
end

closeClient(this::NetworkClient) = Base.close(this.socket)
export closeClient

function receiveMove(this::NetworkClient)
  n = 0
  while true
    try
      n = read(this.socket, UInt8)
      if n != 201 break end #no input
      return nothing
    catch IOException
      throw(RuntimeException(string("Failed to receive move: ", IOException)))
    end
  end
  if n == 207
    throw(RuntimeException(string("You got kicked because your move was invalid!")))
  end
  move=Move(Int(floor(n / 49)), (x = Int(floor(n / 7 % 7)), y = Int(floor(n % 7))))
  println("$this receives $move")
  move
end
export receiveMove

function sendMove(this::NetworkClient, move::Union{Nothing, Move})
  try
    if move == nothing #without Union{Nothing,...}: not needed because move will never be null?
      throw(RuntimeException(string("Cannot send null move")))
    end
    #sleep(0)  #bugfix: sometimes client is to fast?
    write(this.socket, UInt8(move.pos.x * 7 + move.pos.y))
    flush(this.socket)
    println("$this send $move")

  catch IOException
    throw(RuntimeException(string("Failed to send move: ", IOException)))
  end
end
export sendMove

end #sawhian
