local games = {
    [3541611379] = "https://raw.githubusercontent.com/minh597/Elfaria/refs/heads/main/Main.lua",
    [10375105020] = "https://raw.githubusercontent.com/minh597/Elfaria/refs/heads/main/SpeedBoatTsunami.lua"
}

local url = games[game.GameId]

if url then
    loadstring(game:HttpGet(url))()
else
    warn("Game not supported: " .. tostring(game.GameId))
end
