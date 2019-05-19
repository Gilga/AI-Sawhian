#random_bitstring() = bitstring(UInt8(rand(0:4)))
random_bitstring() = bitstring(UInt8(rand(range(0,stop=typemax(UInt8)))))

zobrist_hashKeys = (x->0).(PLAYERINDEX)
zobrist_table = String[]
zobrist_file = joinpath(ROOT, "zobrist_table.jld2")
zobrist_hashmaps = (x->Dict{String, Array{UInt32,1}}()).(PLAYERINDEX)
zobrist_hashmap_file =joinpath(ROOT, "zobrist_hashmap_{playerID}.jld2")

createBackup() = (playerNumber, board, KickedPlayer, stonesOnStack, zobrist_hashKeys)

function loadBackup(backup)
  global playerNumber, board, KickedPlayer, stonesOnStack, zobrist_hashKeys
  (playerNumber, board, KickedPlayer, stonesOnStack, zobrist_hashKeys) = backup
end

function zobrist_init(is_main_process=true)
  global zobrist_table, zobrist_file

  # Read file zobrist
  if !is_main_process
    for i=1:120
      if isfile(zobrist_file) break end
      if i==1 println("Wait for file zobrist...") end
      print(".")
      sleep(1)
    end
    if !isfile(zobrist_file) throw(RuntimeException("Cannot read file zobrist")) end
  end

  if isfile(zobrist_file)
    zobrist_table = String[]
    @load zobrist_file zobrist_table # JLD2 load
    return zobrist_table
  end

  # fill a table of random numbers/bitstrings
  table = fill!(Array{String}(undef,MAX_FIELDS_COUNT,MAX_STONES_COUNT,MAX_PLAYER_COUNT),"")
  table = (x->random_bitstring()).(table) # loop over the board
  #for i=1:size[1]  # loop over the board
  #    for j=1:size[2]  # loop over the pieces
  #        table[i][j] = random_bitstring()
  #    end
  #end
  zobrist_table = table

  # Save file zobrist
  @save zobrist_file zobrist_table # JLD2 save

  # create hashkey
  zobrist_createHashKey()

  # load all previously saved configurations
  loadConfigurations(getID())

  pretty_table(table; hlines=findall(x->true,table[:,1]), noheader=true)
  table
end

function zobrist_updateHashKey(move::Move; configkey::ConfigurationKey=zobrist_hashKeys[move.player])
  index = move.pos.y*FIELDS_RANGE.y+move.pos.x
  player = move.player
  stones = stonesOnStack[player]
  zobrist_hashKeys[player] = configkey ⊻ zobrist_table[index][stones][player]
end

function zobrist_createHashKey()
  hash = 0
  for index=1:size(zobrist_table)[1] # loop over the board positions
     if board[index] != nothing && board[index] != 0
      player = board[index]
      stones = stonesOnStack[player]
      hash = hash ⊻ zobrist_table[index][stones][player] # ⊻ = XOR
    end
  end
  hash
end

# weights for all players
# increasing weight is good, decreasing is bad
function weights(config::Configuration) #for all players #bewertungsfunktion
  config.weights = (x->0).(config.stack) #copy array and set values to zero

  for p in config.board if p>0 config.weights[p] += 1 * WEIGHT_MULTIPLYER_BOARD end end # increase weight when stone is on board

  for stones in config.stack
    w = config.weights[p]

    if w == 0 # zero means not on board
      w = MAX_STONES_COUNT - stones # increase weight when stones are not on stack and not on board
      w = w >= MAX_STONES_COUNT ? CUTOFF_WIN : w * WEIGHT_MULTIPLYER_WINPOINT
    else
      w -= stones * WEIGHT_MULTIPLYER_STACK # decrease weight when stones are still on stack
    end

    config.weights[p] = w
  end

  # decrease weight when less valid moves
  for p in PLAYERINDEX
    w = config.weights[p]

    if w >= CUTOFF_WIN || w <= CUTOFF_LOOSE continue end

    count = config.validMoves[p]
    if count == 0 # no valid moves found
      w = CUTOFF_LOOSE
    else
      w -= (MAX_STONES_COUNT - config.countOfValidMoves[p]) * WEIGHT_MULTIPLYER_BLOCKED
    end

    config.weights[p] = w
  end

  config
end

# weighting function (Bewertungsfunktion)
function updateWeighting(player::Player, config::Configuration; WEIGHT_CONFIGURATION=1) #for all players #bewertungsfunktion
  playerWeight = 0
  enemyWeight = 0
  enemyCount = 0

  # update weights
  weights(config)

  p = 0
  for w in config.weights
    p+=1
    if p == player
      playerWeight=w
    else
      enemyWeight+=w
      enemyCount+=1
    end
  end
  # playerWeight vs enemyWeight
  # result = playerWeight - round(Integer, enemyWeight / enemyCount)
  # update weighting
  config.weighting = (player = playerWeight * WEIGHT_CONFIGURATION, enemies = round(Integer, enemyWeight / enemyCount)  * WEIGHT_CONFIGURATION)

  config
end

createConfiguration(player::Player) =
  (board = board, stack = stonesOnStack, validMoves = countOfAllValidMoves(), weights = [], weighting = [])

saveConfiguration(player::Player, config::Configuration; configkey::ConfigurationKey=zobrist_hashKeys[player]) =
  zobrist_hashmaps[player][configkey] = config

getConfiguration(player::Player; configkey::ConfigurationKey=zobrist_hashKeys[player]) =
  haskey(zobrist_hashmaps[player], configkey) ? zobrist_hashmaps[player][configkey] : nothing

function changeWeighting(player::Player, configkey::ConfigurationKey, WEIGHT_CONFIGURATION::Weight)
  config = getConfiguration(player; configkey=configkey)
  if config == nothing config = createConfiguration(player) end
  updateWeighting(player, config; WEIGHT_CONFIGURATION=WEIGHT_CONFIGURATION)
  saveConfiguration(player, config; configkey=configkey)
end

function changeTime(player::Player, time::Float32, configkey::ConfigurationKey=zobrist_hashKeys[player])
  config = getConfiguration(player; configkey=configkey)
  prevTime = 0
  if config == nothing
    config = createConfiguration(player)
    updateWeighting(player, config)
  else
    prevTime = config.time
  end
  config.time = (time + prevTime) / (prevTime>0 ? 2 : 1)
  saveConfiguration(player, config; configkey=configkey)
end

function scoreConfiguration(player::Player)
  config = getConfiguration(player)
  if config == nothing
    config = createConfiguration(player)
    updateWeighting(player, config)
    saveConfiguration(player, config)
  end
  score = config.weighting
end

function saveConfigurations(player::Player)
  zobrist_hashmap = zobrist_hashmaps[player]
  zobrist_file = replace(zobrist_hashmap_file,"{playerID}"=>player)

  # Save zobrist hashmap
  @save zobrist_file zobrist_hashmap # JLD2 save
end

function loadConfigurations(player::Player)
  zobrist_hashmap = zobrist_hashmaps[player]
  zobrist_file = replace(zobrist_hashmap_file,"{playerID}"=>player)

  if isfile(zobrist_file)
    # load zobrist hashmap
    @load zobrist_file zobrist_hashmap # JLD2 save
    zobrist_hashmaps[player] = zobrist_hashmap
  end
end

# score all configurations
function scoreConfigurations(player::Player)
  scroreList = []
  timeList = []
  for (konfiguration,config) in zobrist_hashmaps[player]
    score = config.weighting.player
    time = config.time
    push!(scroreList, (score, time, konfiguration))
    push!(timeList, (time, score, konfiguration))
  end

  (scroreList = sort(scroreList), timeList = sort(timeList))
end
