∞ = Inf

# alpha beta pruning
function alphabeta(node, depth, α, β, maximizingPlayer)
  if depth == 0 || isTerminal(node) #or node is a terminal node then
      return node.value #the heuristic value of node
  end
  if maximizingPlayer
    value = -∞
    for child in node.childs
        value = max(value, alphabeta(child, depth - 1, α, β, FALSE))
        α = max(α, value)
        if α ≥ β break end #(* β cut-off *)
    end
  else
    value = +∞
    for child in node.childs
        value = min(value, alphabeta(child, depth - 1, α, β, TRUE))
        β = min(β, value)
        if α ≥ β break end #(* α cut-off *)
    end
  end
  value
end

# while true
#   for i=index:length(node.childs)
#     index=1;
#     depth -= 1;
#     break
#     continue
#   end
# end

winCutoff = 500000
timeLimit = 1000*4
startTime = 0
endTime = 0

mutable struct State
  player::Player
  maximizing::Bool #maximizing
end

# Run an iterative deepening search on a game state, taking no longrer than the given time limit
function iterativeDeepeningSearch(state::State)
  global winCutoff, timeLimit, startTime
  startTime = Dates.time()
  endTime = startTime + timeLimit
  depth = 1
  score = 0
  searchCutoff = false

  while true
    currentTime = Dates.time()
    if currentTime >= endTime break end
    searchResult = alphabetasearch(state, depth, -∞, +∞, currentTime, endTime - currentTime)

    # If the search finds a winning move, stop searching
    if searchResult >= winCutoff return searchResult end

    if !searchCutoff score = searchResult end
    depth+=1
  end

  score
end

# evaluate score for a player
function evaluateScore(player::Player)
  global board, stonesOnStack
  weights = weighting(board, stonesOnStack)
  weights[player]
end

# this function will perform minimax search with alpha-beta pruning
function alphabetasearch(state::State, depth, α, β, startTime, endTime)
  moves = getValidMoves(state.player)
  score = evaluateScore(state.player)

  #isTerminal(node)
  # If this is a terminal node or a win for either player, abort the search
  if (Dates.time() - startTime) >= endTime || depth == 0 || length(moves) == 0 || score >= winCutoff || score <= -winCutoff
    return score #node.value
  end

  if state.maximizing
    value = -∞
    for move in moves #child in node.childs
      makeMove(childState, move)
      value = max(value, alphabetasearch(state, depth - 1, α, β, startTime, endTime))
      α = max(α, value)
      #if β <= α break end
      if α ≥ β break end
    end

    return α
  else
    value = +∞
    for move in moves #child in node.childs
      makeMove(childState, move)
      #alphabeta(child, depth - 1, α, β, TRUE)
      value = min(value, alphabetasearch(state, depth - 1, α, β, startTime, endTime))
      β = min(β, value)
      #if β <= α break end
      if α ≥ β break end
    end

    return β
  end
end
