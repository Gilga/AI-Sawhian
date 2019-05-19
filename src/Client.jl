"""
TESTIFY
"""
module Client
  using Images, PrettyTables, JLD2

  using sawhian # HTW lib from AI professor
  #LOGGER_OUT = "out.log"
  #open(stdout -> println(stdout, args...), LOGGER_OUT, "a+")

  include("constants.jl")

  # variables
  pid = 0 # process id
  playerNumber = 1
  name = nothing
  image  = nothing
  server = nothing
  client = NetworkClient()
  initalized = false
  output=Base.println
  board = FieldType[]
  const playerDirection=Position[(x=0,y=1),(x=1,y=0),(x=0,y=-1),(x=-1,y=0)]
  board_indicies=Position[]
  stonesOnStack=Int[]
  hashMap = Dict{String, UInt32}()
  USE_SERVER = false
  KickedPlayer = [0,0,0,0]
  timeLimitInSeconds = 4

  """
  should use some PPP
  """
  setOutput(poutput) = global output = poutput

  convertToValidInput(move::Move) = Move(move.player+1,move.pos+1)
  convertToValidOutput(move::Move) = Move(move.player-1,move.pos-1)

  getID() = playerNumber
  getColor() = colorNames[getID()]
  getName() = string("$name($pid)[$(getColor())]")

  convertToValidName() = replace(cleanColorNames[getID()],r"[\\\\/:*?\"<>|]"=>"_")
  getErrorLogFile() = joinpath(ROOT, "error_$(convertToValidName()).log")
  getLogFile() = joinpath(ROOT, "out_$(convertToValidName()).log")

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

  error(msg::String) = log(msg; mode="Error")
  warn(msg::String) = log(msg; mode="Warning")
  info(msg::String) = log(msg; mode="Info")
  println(msg::String) = log(msg)

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

  setFieldValue(mv::Move; board=board) = setFieldValue(mv.pos, mv.player; board=board)

  setFieldValue(pos::Position, value::FieldType; board=board) =
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

  clearField(mv::Move) = setFieldValue(mv.pos,nothing)

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

  getAllValidMoves() = (player->getValidMoves(player)).(PLAYERINDEX)
  countOfAllValidMoves() = (fields->length(fields)).(getAllValidMoves())

  checkPlayers() = USE_SERVER ? true : reduce(+,KickedPlayer) < 4

  function getNextPlayer()
    global playerNumber
    # circle through id
    playerNumber+=1
    if playerNumber >= 5 playerNumber=1 end
  end

  updateMove(move::Move) = nothing # pre definition

  #################################

  # some more includes
  include("configuration.jl")
  include("gameTree.jl")
  include("evaluation.jl")

  #################################
  #Base.println("dfd")
  #  zobrist_init()

  function getRandomMove(player::Player, fields::AbstractArray)
    field = rand(fields)
    move = Move(player,field)
  end

  function getMove(player::Player)
    fields = getValidMoves(player)
    if length(fields)<=0 throw(RuntimeException("No moves found for p$player")) end

    move = RANDOM_MOVES ? getRandomMove(player, fields) :
    getBestMoveBySearch(player).move # see gameTree.jl

    println("getMove: "*string(getNextField(move)))
    move
  end

  function getMoveSafe(id)
    move = nothing
    try
      move = getMove(id)
    catch e
      warn(string(e))
    end
    move
  end

  function getPlayeMoveFast()
    move = getMoveSafe(getID())
    if move == nothing KickedPlayer[getID()]=1 end
    # circle through id
    getNextPlayer()
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
    global KickedPlayer = [0,0,0,0]
    global board=fill!(Array{FieldType}(undef,7,7),nothing)
    global board_indicies=getPosition.(reshape(collect(1:MAX_FIELDS_COUNT),(FIELDS_RANGE.y,FIELDS_RANGE.y)))
    global stonesOnStack=fill!(Array{Int}(undef,MAX_PLAYER_COUNT),MAX_STONES_COUNT)

    is_main_process=pid==1
    zobrist_init(is_main_process) # see configuration.jl
  end

  redirect_NetworkClient(server, name, image) =
    USE_SERVER ? sawhian.NetworkClient(server, name, image) : nothing

  redirect_getMyPlayerNumber(client) =
    USE_SERVER ? sawhian.getMyPlayerNumber(client) : getID()-1

  redirect_getTimeLimitInSeconds(client) =
    USE_SERVER ? sawhian.getTimeLimitInSeconds(client) : 4

  redirect_getExpectedNetworkLatencyInMilliseconds(client) =
    USE_SERVER ? sawhian.getExpectedNetworkLatencyInMilliseconds(client) : 0

  redirect_closeClient(client) =
    USE_SERVER ? sawhian.closeClient(client) : nothing

  function redirect_receiveMove(client)
    if !USE_SERVER
      move = getPlayeMoveFast()
      println("Receive $(move != nothing ? move : "nothing")")
    else
      move = sawhian.receiveMove(client)
      if move != nothing
        move = convertToValidInput(move)
        println("Receive $move")
        if move.player == getID() println("is my move!") end
      end
    end
    move
  end

  function redirect_sendMove(client, move)
    println("Send $move")
    USE_SERVER ? sawhian.sendMove(client, move) : nothing
  end

  function updateMove(move::Move)
    result=true

    (status, new_pos) = getNextField(move)

    if status == FIELD_OUTSIDE # is outside
      println("win point")
      clearField(move)
      if !RANDOM_MOVES zobrist_updateHashKey(move) end # see configuration.jl

    elseif status == FIELD_FREE
      nextMove = Move(move.player,new_pos)
      if move.pos == nextMove.pos  throw(RuntimeException("Move did not change: $move")) end
      println("set pos")
      clearField(move)
      setPlayer(nextMove)
      if !RANDOM_MOVES zobrist_updateHashKey(move) end #remove old - see configuration.jl
      if !RANDOM_MOVES zobrist_updateHashKey(nextMove) end #add new old - see configuration.jl

    elseif status == FIELD_START
      if !isValidFreeStartField(move) throw(RuntimeException("Start move is not valid: $move")) end
      addStone(move)
      if !RANDOM_MOVES zobrist_updateHashKey(move) end # see configuration.jl

    else #status == FIELD_INVALID
      throw(RuntimeException("Cannot update move: $move"))
      result=false # cannot update move
    end

    if result printBoard() end

    result
  end

  function main(args::Array{String,1} ;output=Base.println)
    global playerNumber, timeLimitInSeconds, initalized

    len = length(args)
    if len == 0 throw(RuntimeException("No PID set!")) end # no pid? -> leave

    initalized = false

    setOutput(Base.println)

    global pid = length(args[1])>0 ? parse(Int,args[1]) : 0
    global server = len>1 ? args[2] : "localhost"
    global name = len>2 ? args[3] : string("Client",pid)
    global image = len>3 ? args[4] : "logo.png"
    global client

    try
      image = Images.load(joinpath(ROOT, "logo.png"))
    catch ex
      warn("Could not load image: $ex")
      info("use default blank image instead")
      image = (x->RGBA{Normed{UInt8,8}}(0,0,0,0)).(Array{RGBA{N0f8}}(undef,256,256)) #similar to BufferedImage (java)
    end

    try
      client = redirect_NetworkClient(server, name, image)
      playerNumber = 1
      playerNumber = redirect_getMyPlayerNumber(client)+1
      timeLimitInSeconds = redirect_getTimeLimitInSeconds(client)
      expectedNetworkLatencyInMilliseconds = redirect_getExpectedNetworkLatencyInMilliseconds(client)
      initalized = true
      clearLogFiles()

      output(
      getColor()*":\n"*
      "My Number: $(playerNumber); "*
      "Time Limit: $(timeLimitInSeconds); "*
      "Latency: $(expectedNetworkLatencyInMilliseconds)"
      )

      reset() # reset board etc...
      #closeClient(client); return

      while checkPlayers()
        move = redirect_receiveMove(client)

        if move == nothing #my turn
          if !USE_SERVER continue end #skip because its invalid
          move = getMove(getID())
          redirect_sendMove(client, convertToValidOutput(move))
        else
          updateMove(move)
        end
      end

      warn("all players left the game")

    catch ex
      outputBacktrace(ex)
      error("NetworkClient error! For more details look in $(getErrorLogFile())")
    end

    redirect_closeClient(client)

    # evaluation
    if !USE_SERVER && !RANDOM_MOVES evaluate(getID()) else evaluate() end  # see evaluation.jl
  end

end #Client
