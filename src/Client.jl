"""
TESTIFY
"""
module Client
  using Images, PrettyTables, JLD2

  using sawhian # HTW lib from AI professor
  #LOGGER_OUT = "out.log"
  #open(stdout -> println(stdout, args...), LOGGER_OUT, "a+")

  include("constants.jl")
  include("configuration.jl")
  include("gameTree.jl")

  pid = 0
  playerNumber = 0
  name = nothing
  image  = nothing
  server = nothing
  client = NetworkClient()
  initalized = false
  output=Base.println

  """
  should use some PPP
  """
  setOutput(poutput) = global output = poutput

  removeColors(str) = begin for c in COLORS occursin(c, str) ? str=replace(str, c => "") : nothing end; str end

  convertToValidInput(move::Move) = Move(move.player+1,move.pos+1)
  convertToValidOutput(move::Move) = Move(move.player-1,move.pos-1)

  getID() = playerNumber
  getColor() = colorNames[getID()]
  getName() = string("$name($pid)[$(getColor())]")

  convertToValidName() = replace(removeColors(colorNames[getID()]),r"[\\\\/:*?\"<>|]"=>"_")
  getErrorLogFile() = "error_$(convertToValidName()).log"
  getLogFile() = "out_$(convertToValidName()).log"

  outputBacktrace(ex) = open(getErrorLogFile(),"w+") do f Base.showerror(f, ex, catch_backtrace()) end

  function clearLogFiles()
    open(getErrorLogFile(),"w+") do f write(f, "") end
    open(getLogFile(),"w+") do f write(f, "") end
  end

  function log(msg::String; mode="", wmode="a+")
    phead = getName()*": "
    whead = removeColors(phead)
    if mode != ""
      phead = mode*" for "*phead
      whead = mode*" for "*whead
    end
    output(phead*msg)
    if initalized open(getLogFile(),wmode) do f write(f, whead*msg*"\n") end; end
  end

  error(msg) = log("Error",msg)
  warn(msg) = log("Warning",msg)
  info(msg) = log("Info",msg)
  println(msg) = log(msg)

  board = FieldType[]
  const playerDirection=Position[(x=0,y=1),(x=1,y=0),(x=0,y=-1),(x=-1,y=0)]
  board_indicies=Position[]
  stonesOnStack=Int[]
  points=0 # for rating
  hashMap = Dict{String, UInt32}()

  @enum FIELD_RESULT FIELD_INVALID=-1 FIELD_START FIELD_FREE FIELD_OUTSIDE

  getPosition(field::Field) = begin field-=1; y=floor(Int,field/FIELDS_RANGE.y); (x=field-y*FIELDS_RANGE.y+1,y=y+1); end
  getFieldIndex(pos::Position) = (pos.y-1)*FIELDS_RANGE.y + (pos.x-1)

  getStoneCount(player::Player) = player > 0 && player <= MAX_PLAYER_COUNT ?
    stonesOnStack[player] :
    throw(RuntimeException("playerindex ($player) is wrong"))

  reduceStonesOnStack(player::Player) = player > 0 && player <= MAX_PLAYER_COUNT ?
    (stonesOnStack[player] -=1) :
    throw(RuntimeException("playerindex ($player) is wrong"))

  #p.x >= FIELDS_RANGE.x && p.x <= FIELDS_RANGE.y && p.y >= FIELDS_RANGE.x && p.y <= FIELDS_RANGE.y
  isOutside(pos::Position) = pos.x < 1 || pos.x > 7 || pos.y < 1 || pos.y > 7
  isValid(pos::Position) = !isOutside(pos)

  getFieldValue(pos::Position ;board=board) =
    isValid(pos) ? board[pos.y,pos.x] :
    throw(RuntimeException("one element of $pos not in range of FIELDS_RANGE"))

  setFieldValue(pos::Position, value::FieldType ;board=board) =
    isValid(pos) ? (board[pos.y,pos.x] = value) :
    throw(RuntimeException("one element of $pos not in range of FIELDS_RANGE"))

  getFreeStartFields(board_indicies::Fields) =
    filter(x->x!=nothing,[getFieldValue(p) == nothing ? p : nothing for p in board_indicies])

  function getFreeStartFields(player::Player)
    fields = eltype(board_indicies)[]
    if getStoneCount(player) <= 0 return fields end
    if player == 1 fields = board_indicies[:,1]
    elseif player == 2 fields = board_indicies[1,:]
    elseif player == 3 fields = board_indicies[:,7]
    elseif player == 4 fields = board_indicies[7,:]
    end
    fields = getFreeStartFields(fields)
    println(string(fields))
    fields
  end

  isValidFreeStartField(move::Move) = in(move.pos,getFreeStartFields(move.player))

  hasFreeStartFields(fields::Fields) = length(fields) > 0

  clearField(pos::Position) = setFieldValue(pos,nothing)
  const setPlayer = setFieldValue
  const getPlayer = getFieldValue

  isFieldEmpty(pos::Position) = getFieldValue(pos) == nothing
  isPlayerOnField(pos::Position) = !isFieldEmpty(pos)
  isSamePlayer(pos::Position, player::Player) = getFieldValue(pos) == player

  function getNextField(move::Move)
    player = move.player
    current = move.pos
    next = current

    if isFieldEmpty(current) return (FIELD_START, current) end # start field

    jumped=false
    while true
      next = current + playerDirection[player]
      after_next = next + playerDirection[player]
      if isValid(next) && isPlayerOnField(next) && !isSamePlayer(next, player) && (isOutside(after_next) || isFieldEmpty(after_next))
        current = after_next # jump to field
        jumped=true
      else break # cannot jump
      end
    end

    if !jumped && isOutside(next) result=(FIELD_OUTSIDE, next)
    elseif !jumped && isFieldEmpty(next) result=(FIELD_FREE, next)
    else
      if isOutside(current) result=(FIELD_OUTSIDE, current)
      else result=(FIELD_FREE, current) # cannot continue move
      end
    end

    if move.pos == result[2] result=(FIELD_INVALID, nothing) end
    result
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
    (status, new_pos) = getNextField(move)

    if status == FIELD_OUTSIDE # is outside
      println("win point")
      clearField(move.pos)
      points += 1

    elseif status == FIELD_FREE
      if move.pos == new_pos  throw(RuntimeException("Move did not change: $move")) end
      println("set pos")
      clearField(move.pos)
      setPlayer(new_pos,move.player)

    elseif status == FIELD_START
      if !isValidFreeStartField(move) throw(RuntimeException("Start move is not valid: $move")) end
      addStone(move)

    else #status == FIELD_INVALID
      throw(RuntimeException("Cannot update move: $move"))
      result=false # cannot update move
    end

    if result printBoard() end

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

  getStones(player::Player) = filter(x->getFieldValue(x) == player, board_indicies)
  getMoveableStones(player::Player) = filter(x->getNextField(Move(player,x))[1] != FIELD_INVALID, getStones(player))

  function getValidMoves(player::Player)
    fields = getFreeStartFields(player)
    moveable_stones = getMoveableStones(player)
    stone_fields = filter(x->!in(x, fields),moveable_stones)
    fields = vcat(fields,stone_fields)

    #println("Start Fields: "*string(fields))
    #println("Stones: "*string(getStones(player)))
    #println("Moveable Stones: "*string(moveable_stones))

    fields
  end

  function getMove(player::Player)
    filds = getValidMoves(player)
    if length(fields)<=0 throw(RuntimeException("No moves found for p$player")) end
    field = rand(fields)
    move = Move(player,field)
    println("getMove: "*string(getNextField(move)))
    move
  end

  function printBoard()
    #if pid <= 1
      #println(board)
      #data = fill!(Array{Union{String, Int}}(undef, 7, 7), "")
      #open("output.txt","w") do f pretty_table(f, data; hlines=findall(x->true,data[:,1]), noheader=true) end
    #end
    data = (x->x==nothing ? "" : x).(board)
    #@async begin
      open(getLogFile(),"a+") do f pretty_table(f, data; hlines=findall(x->true,data[:,1]), noheader=true) end
    #end
  end

  function reset()
    global board=fill!(Array{FieldType}(undef,7,7),nothing)
    global board_indicies=getPosition.(reshape(collect(1:MAX_FIELDS_COUNT),(FIELDS_RANGE.y,FIELDS_RANGE.y)))
    global stonesOnStack=fill!(Array{Int}(undef,MAX_PLAYER_COUNT),MAX_STONES_COUNT)
    global points=0 # for rating
    init_zobrist((MAX_FIELDS_COUNT,MAX_PLAYER_COUNT);is_main_process=pid==1) # see configuration.jl
  end

  function main(args::Array{String,1} ;output=Base.println)
    global initalized
    len = length(args)
    if len == 0 return end
    initalized = false

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
      global playerNumber = getMyPlayerNumber(client)+1
      initalized = true
      clearLogFiles()

      output(
      getColor()*":\n"*
      "My Number: $(getMyPlayerNumber(client)); "*
      "Time Limit: $(getTimeLimitInSeconds(client)); "*
      "Latency: $(getExpectedNetworkLatencyInMilliseconds(client))"
      )

      reset() # reset board etc...
      closeClient(client)
      return

      while true
        move = receiveMove(client)

        if move == nothing #my turn
          move = getMove(getID())
          println("Send $move")
          sendMove(client, convertToValidOutput(move))
        else
          move = convertToValidInput(move)
          println("Receive $move")
          if move.player == getID()
            println("is my move!")
          end
          updateMove(move)
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
      error("NetworkClient error! For more details look in $(getErrorLogFile())")
    end

    closeClient(client)
  end

end #Client
