const ROOT = joinpath(@__DIR__,"../")

const Position = NamedTuple{(:x, :y),Tuple{Int,Int}}
const Configuration = NamedTuple{(:board, :stack, :validMoves, :weights, :weighting, :time),Tuple{AbstractArray,AbstractArray,AbstractArray, AbstractArray, AbstractArray, Float32}}
const ConfigurationKey = Int

import Base.+, Base.-, Base.*, Base./

+(p::Position,n::Number) = typeof(p)([p...].+(n))
-(p::Position,n::Number) = typeof(p)([p...].-(n))
*(p::Position,n::Number) = typeof(p)([p...].*(n))
/(p::Position,n::Number) = typeof(p)([p...]./(n))

+(p::Position,n::Position) = typeof(p)([p...]+[n...])
-(p::Position,n::Position) = typeof(p)([p...]-[n...])
*(p::Position,n::Position) = typeof(p)([p...]*[n...])
/(p::Position,n::Position) = typeof(p)([p...]/[n...])

const Player = Int
const Stone = Int
const Field = Int
const Weight = Int
const Board = AbstractArray
const Fields = AbstractArray
const FieldType = Union{Nothing,String,Int}
const MAX_PLAYER_COUNT = 4
const MAX_STONES_COUNT = 7
const FIELDS_RANGE = (x=1,y=7)
const MAX_FIELDS_COUNT = FIELDS_RANGE.y*FIELDS_RANGE.y
const PLAYERINDEX = collect(range(1,stop=MAX_PLAYER_COUNT))
const RANDOM_MOVES = true
const ∞ = Inf

WEIGHT_MULTIPLYER_BOARD = 1
WEIGHT_MULTIPLYER_STACK = 1
WEIGHT_MULTIPLYER_WINPOINT = 10
WEIGHT_MULTIPLYER_BLOCKED = 10

CUTOFF_WIN = MAX_STONES_COUNT * WEIGHT_MULTIPLYER_WINPOINT
CUTOFF_LOOSE = -MAX_STONES_COUNT * WEIGHT_MULTIPLYER_BLOCKED

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

const colorNames = [
  COLORS.red*"red(1)"*COLORS.reset
  ,COLORS.green*"green(2)"*COLORS.reset
  ,COLORS.blue*"blue(3)"*COLORS.reset
  ,COLORS.yellow*"yellow(4)"*COLORS.reset
]

RuntimeException(msg::String) = ErrorException(msg)
removeColors(str) = begin for c in COLORS occursin(c, str) ? str=replace(str, c => "") : nothing end; str end

const cleanColorNames = (name->removeColors(name)).(colorNames)
