local oldHttpGet = game.HttpGet
local oldHttpGetAsync = game.HttpGetAsync
local oldHttpPost = game.HttpPost
local oldHttpPostAsync = game.HttpPostAsync

game.HttpGet = function(...)
    error("HttpGet blocked")
end

game.HttpGetAsync = function(...)
    error("HttpGetAsync blocked")
end

game.HttpPost = function(...)
    error("HttpPost blocked")
end

game.HttpPostAsync = function(...)
    error("HttpPostAsync blocked")
end
loadstring(game:HttpGet("https://raw.githubusercontent.com/minh597/Elfaria/refs/heads/main/klaffyTDX.lua"))()
