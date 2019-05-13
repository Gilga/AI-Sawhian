#random_bitstring() = bitstring(UInt8(rand(0:4)))
random_bitstring() = bitstring(UInt8(rand(range(0,stop=typemax(UInt8)))))

zobrist_table = String[]
zobrist_file = "zobrist_table.jld2"
zobrist_hashmap = Dict{String, UInt32}()
zobrist_hashmap_file = "zobrist_hashmap.jld2"

function init_zobrist(size::Tuple; is_main_process=true)
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
  table = fill!(Array{String}(undef,size[1],size[2]),"")
  table = (x->random_bitstring()).(table) # loop over the board
  #for i=1:size[1]  # loop over the board
  #    for j=1:size[2]  # loop over the pieces
  #        table[i][j] = random_bitstring()
  #    end
  #end
  zobrist_table = table

  # Save file zobrist
  @save zobrist_file zobrist_table # JLD2 save

  pretty_table(table; hlines=findall(x->true,table[:,1]), noheader=true)
  table
end

function getKey(board::AbstractArray)
  h = 0
  for i=1:size(zobrist_table)[1] # loop over the board positions
     if board[i] != 0 #empty:
         j = board[i]
         h = h ⊻ zobrist_table[i][j] # ⊻ = XOR
    end
  end
  h
end

function getValue(board::AbstractArray, stonesOnStack::AbstractArray)
  weights = 0; i=0
  for w in weighting(board, stonesOnStack) weights |= (w << (4*i)); i+=1 end
  weights
end

function weighting(board::AbstractArray, stonesOnStack::AbstractArray) #for all players #bewertungsfunktion
  weights = zeros(MAX_PLAYER_COUNT)
  for p in PLAYERINDEX weights[p]+=stonesOnStack[p] end
  for p in board if p>0 weights[p]+=1 end end
  weights = (x->MAX_STONES_COUNT-x).(weights)
end

#saveBoard(board::AbstractArray, stonesOnStack::AbstractArray) = zobrist_hashmap[getKey(board)] = getValue(board,stonesOnStack)
#loadBoard(board::AbstractArray) = zobrist_hashmap[getKey(board)]

#=
function convertBoardToConfiguration(_board::AbstractArray)
  board = UInt(0)
  for y=1:7
    for x=1:7
      player = 4 #rand(0:4) #getFieldValue((x=x,y=y))
      board = board | (player << (3*((y-1)*7+(x-1))))
    end
  end
  bits=bitstring(board)
  println(bits)
  i=0;j=0
  for c in reverse(bits)
    i+=1
    j+=1
    print(c)
    if i >= 3 print(" "); i=0 end
    if j >= 21 println(); j=0 end
  end
  board
end

function convertConfigurationToBoard(bitboard::UInt)
  board=fill!(Array{UInt}(undef,7,7),0)
  for y=1:7
    for x=1:7
      player = (bitboard >> (3*(x-1)+(y-1)*7)) & 0x7
      board[y,x] = player #(y-1)*7+x
      #setFieldValue((x=x,y=y), player)
    end
  end
  pretty_table(board; hlines=findall(x->true,board[:,1]), noheader=true)
  board
end
=#
