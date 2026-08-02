local games = {
    [3541611379] = "https://raw.githubusercontent.com/minh597/Elfaria/refs/heads/main/Main.lua"
}

local url = games[game.PlaceId]

if url then
    loadstring(game:HttpGet(url))()
else
    warn("Game not supported: " .. game.PlaceId)
end
