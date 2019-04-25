module Client
  using Images
  using PrettyTables

  using sawhian
  #LOGGER_OUT = "out.log"
  #open(stream -> println(stream, args...), LOGGER_OUT, "a+")

  import Base.+, Base.-, Base.*, Base./

  RuntimeException(msg::String) = ErrorException(msg)
  const Position = NamedTuple{(:x, :y),Tuple{Int,Int}}
  const Player = Int
  const Stone = Int
  const Field = Int
  const Board = AbstractArray
  const Fields = AbstractArray
  const FieldType = Union{Nothing,String,Int}
  const MAX_PLAYER_COUNT = 4
  const MAX_STONES_COUNT = 7
  const FIELDS_RANGE = (x=1,y=7)
  const MAX_FIELDS_COUNT = FIELDS_RANGE.y*FIELDS_RANGE.y

  const COLORS = (
    reset = "\x1b[39m\x1b[49m"
    ,default = "\x1b[39m"
    ,black  = "\x1b[30m"
    ,white = "\x1b[97m"
    ,lightgray = "\x1b[90m"
    ,gray  = "\x1b[37m"
    ,red  = "\x1b[91m"
    ,darkred  = "\x1b[31m"
    ,green = "\x1b[92m"
    ,darkgreen = "\x1b[32m"
    ,blue = "\x1b[94m"
    ,darkblue = "\x1b[34m"
    ,yellow = "\x1b[93m"
    ,darkyellow = "\x1b[33m"
    ,cyan  = "\x1b[96m"
    ,darkcyan  = "\x1b[36m"
    ,magenta  = "\x1b[95m"
    ,darkmagenta  = "\x1b[35m"
  )

  +(p::Position,n::Number) = typeof(p)([p...].+(n))
  -(p::Position,n::Number) = typeof(p)([p...].-(n))
  *(p::Position,n::Number) = typeof(p)([p...].*(n))
  /(p::Position,n::Number) = typeof(p)([p...]./(n))

  +(p::Position,n::Position) = typeof(p)([p...]+[n...])
  -(p::Position,n::Position) = typeof(p)([p...]-[n...])
  *(p::Position,n::Position) = typeof(p)([p...]*[n...])
  /(p::Position,n::Position) = typeof(p)([p...]/[n...])

  output=Base.println
  setOutput(poutput) = global output = poutput

  error(msg) = output("Error for $(getName()): $msg")
  warn(msg) = output("Warning for $(getName()): $msg")
  info(msg) = output("Info for $(getName()): $msg")
  println(msg) = output("$(getName()): $msg")

  pid = 0
  name = nothing
  image  = nothing
  server = nothing
  client = NetworkClient()

  const colorNames = [
    COLORS.red*"red(1)"*COLORS.reset
    ,COLORS.green*"green(2)"*COLORS.reset
    ,COLORS.blue*"blue(3)"*COLORS.reset
    ,COLORS.yellow*"yellow(4)"*COLORS.reset
  ]

  removeColors(str) = begin for c in COLORS occursin(c, str) ? str=replace(str, c => "") : nothing end; str end

  convertToValidInput(move::Move) = Move(move.player+1,move.pos+1)
  convertToValidOutput(move::Move) = Move(move.player-1,move.pos-1)

  getID() = getMyPlayerNumber(client)+1 # convertToValidInput
  getColor() = colorNames[getID()]
  getName() = string("$name($pid)[$(getColor())]")

  convertToValidName() = replace(removeColors(colorNames[getID()]),r"[\\\\/:*?\"<>|]"=>"_")
  getErrorLogFile() = "error_$(convertToValidName()).log"

  outputBacktrace(ex) = open(getErrorLogFile(),"w+") do f Base.showerror(f, ex, catch_backtrace()) end

  board = FieldType[]
  const playerDirection=Position[(x=0,y=1),(x=1,y=0),(x=0,y=-1),(x=-1,y=0)]
  board_indicies=Position[]
  stonesOnStack=Int[]
  points=0 # for rating

  getPosition(field::Field) = begin field-=1; y=floor(Int,field/FIELDS_RANGE.y); (x=field-y*FIELDS_RANGE.y+1,y=y+1); end
  getFieldIndex(pos::Position) = (pos.y-1)*FIELDS_RANGE.y + (pos.x-1)

  getStoneCount(player::Player) = player > 0 && player <= MAX_PLAYER_COUNT ?
    stonesOnStack[player] :
    throw(RuntimeException("playerindex ($player) is wrong"))

  reduceStonesOnStack(player::Player) = player > 0 && player <= MAX_PLAYER_COUNT ?
    (stonesOnStack[player] -=1) :
    throw(RuntimeException("playerindex ($player) is wrong"))

  function reset()
    global board=fill!(Array{FieldType}(undef,7,7),nothing)
    global board_indicies=getPosition.(reshape(collect(1:MAX_FIELDS_COUNT),(FIELDS_RANGE.y,FIELDS_RANGE.y)))
    global stonesOnStack=fill!(Array{Int}(undef,MAX_PLAYER_COUNT),MAX_STONES_COUNT)
    global points=0 # for rating
  end

  getFieldValue(p::Position ;board=board) =
    p.x >= FIELDS_RANGE.x && p.x <= FIELDS_RANGE.y && p.y >= FIELDS_RANGE.x && p.y <= FIELDS_RANGE.y ?
    board[p.y,p.x] :
    throw(RuntimeException("one element of $p not in range of FIELDS_RANGE"))

  setFieldValue(p::Position, value::FieldType ;board=board) =
    p.x >= FIELDS_RANGE.x && p.x <= FIELDS_RANGE.y && p.y >= FIELDS_RANGE.x && p.y <= FIELDS_RANGE.y ?
    (board[p.y,p.x] = value) :
    throw(RuntimeException("one element of $p not in range of FIELDS_RANGE"))

  getFreeStartFields(board_indicies::Fields) =
    filter!(x->x!=nothing,[getFieldValue(p) == nothing ? p : nothing for p in board_indicies])

  function getFreeStartFields(player::Player)
    fields = eltype(board_indicies)[]
    if getStoneCount(player) <= 0 return fields end
    if player == 1 fields = board_indicies[:,1]
    elseif player == 2 fields = board_indicies[1,:]
    elseif player == 3 fields = board_indicies[:,7]
    elseif player == 4 fields = board_indicies[7,:]
    end
    fields = getFreeStartFields(fields)
    println(fields)
    fields
  end

  isValidFreeStartField(move::Move) = in(move.pos,getFreeStartFields(move.player))

  hasFreeStartFields(fields::Fields) = length(fields) > 0
  isOutside(pos::Position) = pos.x < 1 || pos.x > 7 || pos.y < 1 || pos.y > 7

  clearField(pos::Position) = setFieldValue(pos,nothing)
  const setPlayer = setFieldValue
  const getPlayer = getFieldValue

  isFieldEmpty(pos::Position) = getFieldValue(pos) == nothing

  function getNextField(move::Move)
    player = move.player
    current = move.pos
    while true
      previous=current
      current+=playerDirection[player]
      if isOutside(current) || isFieldEmpty(current) break #field has no player
      else
        current+=playerDirection[player]
        if !isOutside(current) && !isFieldEmpty(current) current=previous; break; end #field has player
      end
    end

    !isOutside(current) ? getFieldValue(current) : true
  end

  function addStone(move::Move)
    if getStoneCount(move.player) <= 0 throw(RuntimeException("No free stones on stack for $move")) end
    setFieldValue(move.pos, move.player)
    reduceStonesOnStack(move.player)
    println("Added new stone on $move")
  end

  function updateMove(move::Move)
    global points
    result=true
    new_pos = getNextField(move)

    if new_pos == true # is outside
      println("win point")
      clearField(move.pos)
      points += 1

    elseif new_pos != nothing && move.pos != new_pos
      println("set pos")
      clearField(move.pos)
      setPlayer(new_pos,move.player)

    elseif isValidFreeStartField(move)
      addStone(move)

    else
      throw(RuntimeException("Cannot update move: $move"))
      result=false # cannot update move
    end

    result
  end

#=
  function getStone(move::Move) # first(filter((x)->x==move.player,board[:,move.pos.x]))
    if isOutside(move.pos) return throw(RuntimeException("Move is outside of board: $move")) end
    player = getPlayer(move.pos)
    if player != 0 && move.player != player return throw(RuntimeException("Player not found on board: $move")) end # saved wrong player?
    #getField(move.pos;board=board_indicies)
    getFieldIndex(move.pos)
  end

  function updateStone(move::Move; is_start=false)
    if !isOutside(move.pos) return false end #is not on board

    if !is_start #is not start?
      pos = getStone(move)
      if pos == nothing return false end #invalid pos
      setField(pos,nothing) #remove
    end

    setField(move.pos,move.player)
    true
  end
=#

  function getMove(player::Player)
    fields = getFreeStartFields(player)
    field = nothing
    if length(fields)>0 field = rand(fields) #RNG positions
    else throw(RuntimeException("No free fields found for p$player"))
    end
    #updateMove(field)
    Move(player,field)

    #move = nothing
    #if player == 0 move = Move(player,0,0)
    #elseif player == 1 move = Move(player,0,6)
    #elseif player == 2 move = Move(player,6,6)
    #elseif player == 3 move = Move(player,6,0)
    #end
    #move
  end

  #=
  function update()
  end

  skipPlayer = Dict{Int,Bool}()
  playerExpected=1

  function getNextPlayer()
    global playerExpected
    if length(skipPlayer) < 4
      playerExpected+=1
      if playerExpected > 4 playerExpected=1 end
    else
      playerExpected=nothing
    end
    playerExpected
  end

  function removePlayer(player::Number)
    if !haskey(skipPlayer, player)
      warn("player $player got kicked!")
      skipPlayer[player]=true
      #removePlayerFromBoard()
    end
    getNextPlayer()
  end

  function playerIsAlive(player::Number)
    alive=false
    while true
        if player == playerExpected alive=true break end
        removePlayer(playerExpected)
        if playerExpected == nothing break end
      end
    end
    alive
  end
  =#

  function main(args::Array{String,1} ;output=Base.println)
    len = length(args)
    if len == 0 return end

    setOutput(Base.println)
    global pid = length(args[1])>0 ? parse(Int,args[1]) : 0
    global server = len>1 ? args[2] : "localhost"
    global name = len>2 ? args[3] : string("Client",pid)
    global image = len>3 ? args[4] : "logo.png"
    global client

    try
      image = Images.load("logo.png")
    catch ex
      warn("Could not load image: $ex")
      info("use default blank image instead")
      image = (x->RGBA{Normed{UInt8,8}}(0,0,0,0)).(Array{RGBA{N0f8}}(undef,256,256)) #similar to BufferedImage (java)
    end

    try
      client = NetworkClient(server, name, image)

      output(
      getColor()*":\n"*
      "My Number: $(getMyPlayerNumber(client)); "*
      "Time Limit: $(getTimeLimitInSeconds(client)); "*
      "Latency: $(getExpectedNetworkLatencyInMilliseconds(client))"
      )

      reset() # reset board etc...

      while true
        move = receiveMove(client)

        if move == nothing #my turn
          sendMove(client, convertToValidOutput(getMove(getID())))
        else
          move = convertToValidInput(move)
          println("Receive $move")
          if move.player == getID()
            println("is my move!")
          else
            updateMove(move)
            if pid <= 1
              #println(board)
              #data = fill!(Array{Union{String, Int}}(undef, 7, 7), "")
              #open("output.txt","w") do f pretty_table(f, data; hlines=findall(x->true,data[:,1]), noheader=true) end
              data = (x->x==nothing ? "" : x).(board)
              #@async begin
                println("Board: ")
                pretty_table(data; hlines=findall(x->true,data[:,1]), noheader=true)
              #end
            end
          end
          #player = getPlayer(move)
          #if playerIsAlive(player)
          #  update(player, move)
          #  getNextPlayer()
          #else
          #  warn("all players left the game")
          #  break
          #end
        end
      end

    catch ex
      outputBacktrace(ex)
      error("$(getColor()): NetworkClient error! For more details look in $(getErrorLogFile())")
    end

    closeClient(client)
  end

end #Client


  #img = Gray.(img)
  #imgMatrix = vec(UInt8.(reinterpret.(channelview(img))))
  #convert(Array{UInt8},Images.raw(grayImage))
  #grayimg = (c -> begin g=N0f8((c.r+c.g+c.b)/3); r=RGBA(g,g,g,N0f8(1.0)); end).(img)
  #save("_temp.png", img)
  #content=""
  #open("_temp.png") do file
  #   content=readstring(file)
  #end
  #data = convert(Vector{UInt8},content))
