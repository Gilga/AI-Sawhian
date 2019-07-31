[statusPic]: status.png "sawhian"

![statusPic][statusPic]

# sawhian
Study Project 1 (Turn-based Board Game): AI Game Client written in Julia

## Task Description
* Four players play in a clockwise direction.
* You may only draw your own pieces, either from the non-empty pile of stones to a free space on your own board edge or a stone already in the field.
* Stones in the field are always pulled forward (= away from the owner).
* Stones in the field are drawn as follows:
  * In the field immediately before them provided free OR
  * Get off the board when the board ends immediately in front of them OR
  * Jumping over an arbitrarily long chain of alternating non-own stones and empty fields. The move ends either on the last empty square of the chain or the stone is removed from the board if the chain ends at the board edge with a non-own stone.
* Each own stone taken from the board gives a point.
* If a player does not make a valid or no move within the given time limits, he will be eliminated from the game. His points are preserved and his stones lying on the board remain lying.
* The game ends immediately as soon as a player removes his last stone from the game board or no players participate in the game.

**Minimum Requirements:**
* Alpha beta game tree for four players
* Learning algorithm to improve the evaluation function

## Requirements
* Julia 1.1 or higher [download here](https://julialang.org/)
* Julia Packages See [REQUIRE](REQUIRE)
* [sawhian.zip](sawhian.zip.md)

### Windows
* Operating System: Windows 10 Home 64-bit (10.0, Build 17134 or newer)
* Processor: Intel(R) Core(TM) i7-4510U CPU @ 2.00GHz (4 CPUs), ~2.0GHz
* Memory: 8192MB RAM
* Graphics Card 1: Intel(R) HD Graphics Family
* Graphics Card 2: NVIDIA GeForce 840M

### Linux
* not tested
