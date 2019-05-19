mutable struct State
  player::Player
  currentPlayer::Player
  move::Union{Nothing, Move}
  maximizing::Bool #maximizing
  startTime::Number
  endTime::Number
  time::Number
  score::Number
end

function getNextTurn(state::State)
  if state.move == nothing KickedPlayer[getID()]=1 end
  updateMove(state.move)
  getNextPlayer()
  state.currentPlayer = getID()
  state.maximizing = state.player == state.currentPlayer
  state
end

# Run an iterative deepening search on a game state, taking no longrer than the given time limit
function getBestMoveBySearch(player::Player)
  depth = 0 # depth 3 max
  score = 0
  state = State(player,0,nothing,true,0,0,0,0)

  state.startTime = Dates.time()
  state.endTime = state.startTime + 1000*timeLimitInSeconds

  stopped = false

  @async begin
     while score < CUTOFF_WIN # win condition
      depth+=1
      currentTime = Dates.time()
      if currentTime >= state.endTime break end # time
      score = alphabetasearch(state, depth, -∞, +∞, currentTime, state.endTime - currentTime; start=true)
    end
    stopped = true
  end

  # wait until result or time limit reached
  while !stopped && Dates.time() < state.endTime sleep(0.01) end

  #time: how long it took to get to the final result
  state.time = Dates.time() - state.startTime

  # save score
  state.score = score

  # update time for this configuration
  changeTime(player, state.time)

  state
end


# get score for a player and his enemies
function getScore(state::State)
  weight = scoreConfiguration(state.player)
  if state.maximizing
    score = weight.player
  else
    score = weight.enemies
  end
  score
end

# this function will perform minimax search with alpha-beta pruning
function alphabetasearch(state::State, depth, α, β, startTime, endTime; start=false)
  backup = createBackup()

  if !start state = getNextTurn(state) end
  moves = getValidMoves(state.player)
  score = getScore(state)
  bestmove = nothing

  #isTerminal(node)
  # If this is a terminal node or a win for either player, abort the search
  if (Dates.time() - startTime) >= endTime || depth <= 0 || length(moves) == 0 || score >= CUTOFF_WIN || score <= CUTOFF_LOOSE
    return score #node.value
  end

  if state.maximizing # play for current player
    value = -∞

    for move in moves #child in node.childs
      bestmove = move
      #makeMove(childState, move)
      newvalue = alphabetasearch(state, depth - 1, α, β, startTime, endTime)

      if newvalue > value bestmove = move end

      value = max(value, newvalue)
      α = max(α, value)
      #if β <= α break end
      if α ≥ β break end # dont continue to lookup childs because we can prune
    end

    if state.move == nothing state.move = bestmove end

    result = α

  else # play for enemies
    value = +∞

    for move in moves #child in node.childs
      #makeMove(childState, move)
      #alphabeta(child, depth - 1, α, β, TRUE)
      newvalue = alphabetasearch(state, depth - 1, α, β, startTime, endTime)

      if newvalue < value bestmove = move end

      value = min(value, newvalue)
      β = min(β, value)
      #if β <= α break end
      if α ≥ β break end # dont continue to lookup childs because we can prune
    end

    if state.move == nothing state.move = bestmove end

    result = β
  end

  loadBackup(backup)
  result
end
