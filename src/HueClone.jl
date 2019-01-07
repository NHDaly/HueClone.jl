# Copyright © nhdalyMadeThis, LLC
# Released under MIT License

module HueClone

using Colors
using Rematch # For matching text-based user input

export play_blink, play_juno


rows,cols = 6,4

function create_colors_grid(rows,cols)
    corners = rand(RGB, 4)
    topleft,topright,bottomleft,bottomright = corners

    leftedge = range(topleft, stop=bottomleft, length=rows)
    rightedge = range(topright, stop=bottomright, length=rows)

    tiles = Array{RGB,2}(undef, (rows,cols));
    for r in 1:rows
        tiles[r,:] = range(leftedge[r], stop=rightedge[r], length=cols)
    end

    tiles
end

macro swap!(a,b)
    quote
        tmp = $(esc(a))
        $(esc(a)) = $(esc(b))
        $(esc(b)) = tmp
    end
end

fixed_tile_positions = [(1,1), (rows,1), (1,cols), (rows,cols)]

function user_attempt_swap!(a, b)
    global tiles
    a,b = Tuple(a), Tuple(b)
    if a == b || a in fixed_tile_positions || b in fixed_tile_positions
        return
    end
    @swap!(tiles[a...], tiles[b...])
end


function new_game(r,c)
    global rows,cols
    rows,cols = r,c
    global goal = create_colors_grid(rows, cols)
    global tiles = deepcopy(goal)
    for _ in 1:100
        user_attempt_swap!(rand(CartesianIndices(tiles)),
                           rand(CartesianIndices(tiles)))
    end
end

function play_game(io_device; size=(rows,cols))
    new_game(size...)
    while tiles != goal
        print_board(io_device, tiles)
        a,b = collect_userinput(io_device)
        user_attempt_swap!(a, b)
    end
    print_board(io_device, tiles)
    win_game(io_device)
end

# ------------------------------------
# ------ Juno-REPL based -------------
# ------------------------------------

struct JunoDisplay end

"""
    play_juno()

Play the game in Atom, with the Juno REPL and Juno Plots display
"""
play_juno(;size=(rows,cols)) = play_game(JunoDisplay(), size=size)

print_board(::JunoDisplay, tiles) = display(tiles)

function collect_userinput(::JunoDisplay)
    while true
        try
            println("Enter tile coordinates to swap (col,row):")
            # Read a and b from user input
            print("a: ")
            @match Expr(Tuple, a) = Meta.parse(readline())
            print("b: ")
            @match Expr(Tuple, b) = Meta.parse(readline())
            return reverse(a), reverse(b)
        catch e
            e isa InterruptException && rethrow()
            @warn("Must enter valid coordinate tuple (x,y)")
            @error(e)
        end
    end
end
function win_game(::JunoDisplay)
    println("Hooray you win! :)")
end

# ------------------------------------
# ------ Blink based -----------------
# ------------------------------------

using Blink

"""
    play_blink()

Play the game using a Blink html window.
"""
function play_blink(;size=(rows,cols))
    w = create_board(size...)
    handle(w, "click") do pos
        handle_click(pos)
    end

    play_game(w; size=size)
end

function create_board(rows,cols)
    sq_size = 50
    w = Blink.Window(Dict(:width => sq_size*cols + 4,
                          :height => sq_size*rows + 40),
                     async=false)
    body!(w, """
        <style>
        .square {
            height:$(sq_size)px;
            width:$(sq_size)px;
        }
        .grid {
            display: flex;
            border: 2px solid black;
            width: fit-content;
        }
        .column {
            display: flex;
            flex-direction: column;
        }
        body {
            background-color: lightgray;
        }
        </style>
        <script>
        function click_tile(r,c) {
            Blink.msg("click", [r,c]);
            console.log("HI")
        }
        </script>
        <div class="grid">
        </div>
        <div class="messages">
        </div>
    """, async=false)
    return w
end
function print_board(w::Blink.Window, tiles)
    content!(w, ".grid",
            join([
                """<div class="column">
                    $(join([
                        """<div class="square"
                                onclick="click_tile($r,$c)"
                                style="background-color:#$(hex(tiles[r,c]))"></div>"""
                        for r in 1:size(tiles)[1]
                        ], "")
                    )
                     </div>
                """
                for c in 1:size(tiles)[2]
                ], "")
        )
end

clicksChannel = Channel(2)
function handle_click(pos)
    global clicksChannel
    put!(clicksChannel, Tuple(pos))
end
function collect_userinput(w::Blink.Window)
    return (take!(clicksChannel), take!(clicksChannel))
end

function win_game(w::Blink.Window)
    content!(w, ".messages", "YOU WIN! 🤣")
end

end
