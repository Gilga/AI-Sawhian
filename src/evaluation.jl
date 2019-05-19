# learn algorithm for evaluation of weightning function
# always evaluate at the end of the game
function evaluate(player::Player)
  list = scoreConfigurations(player)

  # evaluate per time
  previousScore = nothing
  for (score,timeS,konfiguration) in list.scroreList
    if previousScore != nothing && previousScore == score
      for (time,scoreT,konfigurationT) in list.timeList
        if score != scoreT continue end # ignore different score values
        WEIGHT_CONFIGURATION = 1+time # the greater the time the worse the configuration
        changeWeighting(player, konfiguration, WEIGHT_CONFIGURATION)
      end
    end
    previousScore = score
  end

  # other options
  # not sure how to change these per evaluation
  global WEIGHT_MULTIPLYER_BOARD = 1
  global WEIGHT_MULTIPLYER_STACK = 1
  global WEIGHT_MULTIPLYER_WINPOINT = 10
  global WEIGHT_MULTIPLYER_BLOCKED = 10

  global CUTOFF_WIN = MAX_STONES_COUNT * WEIGHT_MULTIPLYER_WINPOINT
  global CUTOFF_LOOSE = -MAX_STONES_COUNT * WEIGHT_MULTIPLYER_BLOCKED

  # save all configurations
  saveConfigurations(player)
end

# evaluate all players
evaluate() = for p in PLAYERINDEX evaluate(p) end
