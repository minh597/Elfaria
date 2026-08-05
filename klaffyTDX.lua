local AutoSkip = false
local SkipDelay = 0
local AutoSpeed = false
local AutoDifficulty = false
local SelectedDifficulty = ""
local AutoJoin = false
local TargetMap = ""
local MacroName = ""
local AutoPlayMacro = true
local RecordMacro = false

if makefolder then
    if not isfolder("Klaffy") then makefolder("Klaffy") end
    if not isfolder("Klaffy/Tower Defense X") then makefolder("Klaffy/Tower Defense X") end
end

local FolderPath = "Klaffy/Tower Defense X/"
local ConfigPath = FolderPath .. "Usernamesettings.json"
local LobbyPlaceId = 9503261072

local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Remotes = RS:FindFirstChild("Remotes")
local PlaceTower = Remotes and Remotes:FindFirstChild("PlaceTower")
local TowerUpgradeRequest = Remotes and Remotes:FindFirstChild("TowerUpgradeRequest")
local SellTower = Remotes and Remotes:FindFirstChild("SellTower")
local SkipRemote = Remotes and Remotes:FindFirstChild("SkipWaveVoteCast")
local AbilityRemote = Remotes and Remotes:FindFirstChild("TowerUseAbilityRequest")

local TowerData = {}
local TowerLevels = {}
local TowerIndexCounter = 0
local StartTime = 0
local DefaultPosition = Vector3.new(226.13, -27.72, 161.12)
local hasEntered = false
local state = "Start"
local hasVotedDifficulty = false
local hasVotedReady = false
local wasInLobby = true
local Logs = {}

local function SaveConfig()
    pcall(function()
        local data = {
            AutoSkip = AutoSkip,
            SkipDelay = SkipDelay,
            AutoSpeed = AutoSpeed,
            AutoDifficulty = AutoDifficulty,
            SelectedDifficulty = SelectedDifficulty,
            AutoJoin = AutoJoin,
            TargetMap = TargetMap,
            MacroName = MacroName,
            AutoPlayMacro = AutoPlayMacro
        }
        writefile(ConfigPath, HS:JSONEncode(data))
    end)
end

local function LoadConfig()
    pcall(function()
        if isfile and isfile(ConfigPath) then
            local raw = readfile(ConfigPath)
            local data = HS:JSONDecode(raw)
            if type(data) == "table" then
                AutoSkip = data.AutoSkip or false
                SkipDelay = data.SkipDelay or 0
                AutoSpeed = data.AutoSpeed or false
                AutoDifficulty = data.AutoDifficulty or false
                SelectedDifficulty = data.SelectedDifficulty or ""
                AutoJoin = data.AutoJoin or false
                TargetMap = data.TargetMap or ""
                MacroName = data.MacroName or ""
                AutoPlayMacro = data.AutoPlayMacro ~= nil and data.AutoPlayMacro or true
            end
        end
    end)
end

LoadConfig()

task.spawn(function()
    local ok, res = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/minh597/Elfaria/refs/heads/main/Tower.json")
    end)
    if ok and res then
        local decOk, dec = pcall(function() return HS:JSONDecode(res) end)
        if decOk and type(dec) == "table" then TowerData = dec end
    end
end)

local function GetTowerCash(name, path, level)
    for tName, t in pairs(TowerData) do
        if tName == name or (type(t) == "table" and (t.Name == name or t.Id == name or t.ID == name)) then
            if type(t) == "table" then
                if path == 1 or path == "1" or path == "top" then
                    if t.top_costs and t.top_costs[level] then return t.top_costs[level] end
                elseif path == 2 or path == "2" or path == "bottom" then
                    if t.bottom_costs and t.bottom_costs[level] then return t.bottom_costs[level] end
                end
                return t.placement_cost or 0
            end
        end
    end
    return 0
end

local leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
local cashValue = leaderstats and leaderstats:WaitForChild("Cash", 10)

local function GetCurrentCash()
    if not leaderstats or not leaderstats.Parent then leaderstats = LocalPlayer:FindFirstChild("leaderstats") end
    if leaderstats and (not cashValue or not cashValue.Parent) then cashValue = leaderstats:WaitForChild("Cash", 5) end
    return cashValue and cashValue.Value or 0
end

local function IsInLobby()
    if game.PlaceId == LobbyPlaceId then return true end
    return Workspace:FindFirstChild("APCs") ~= nil or Workspace:FindFirstChild("APCs2") ~= nil
end

task.spawn(function()
    pcall(function()
        local interface = LocalPlayer:WaitForChild("PlayerGui", 10):WaitForChild("Interface", 10)
        local gameOver = interface:WaitForChild("GameOverScreen", 10)
        if gameOver then
            gameOver:GetPropertyChangedSignal("Visible"):Connect(function()
                if gameOver.Visible then
                    task.wait(2)
                    TeleportService:Teleport(LobbyPlaceId, LocalPlayer)
                end
            end)
        end
    end)
end)

local function place(id, towerName, position, rotation)
    pcall(function() if PlaceTower then PlaceTower:InvokeServer(id, towerName, position, rotation or 0) end end)
end

local function upgrade(index, path, lv)
    pcall(function() if TowerUpgradeRequest then TowerUpgradeRequest:FireServer(index, path, lv) end end)
end

local function sell(index)
    pcall(function() if SellTower then SellTower:FireServer(index) end end)
end

local function skipWave()
    pcall(function()
        if SkipRemote then SkipRemote:FireServer(true)
        else RS.Remotes.SkipWaveVoteCast:FireServer(true) end
    end)
end

local function useAbility(index, ability)
    pcall(function() if AbilityRemote then AbilityRemote:InvokeServer(index, ability) end end)
end

local function WaitForCash(requiredCash)
    if not requiredCash or requiredCash <= 0 then return end
    while GetCurrentCash() < requiredCash do task.wait(0.1) end
end

local function loadMacro(file)
    local actualPath = FolderPath .. file .. ".json"
    if not isfile or not isfile(actualPath) then return end
    local raw = readfile(actualPath)
    local success, macro = pcall(function() return HS:JSONDecode(raw) end)
    if not success or type(macro) ~= "table" then return end

    task.spawn(function()
        local playStartTime = os.clock()
        for _, action in ipairs(macro) do
            if action.type == "Place" then
                if action.cash and action.cash > 0 then WaitForCash(action.cash) end
                local pos = action.pos
                if pos then place(action.id, action.name, Vector3.new(pos.x, pos.y, pos.z), action.rot or 0) end
            elseif action.type == "Upgrade" then
                if action.cash and action.cash > 0 then WaitForCash(action.cash) end
                upgrade(action.index, action.path, action.lv)
            elseif action.type == "Sell" or action.type == "skipWave" or action.type == "Ability" then
                local targetTime = action.time or 0
                while (os.clock() - playStartTime) < targetTime do task.wait(0.05) end
                if action.type == "Sell" then sell(action.index)
                elseif action.type == "skipWave" then skipWave()
                elseif action.type == "Ability" then useAbility(action.index, action.ability) end
            end
            task.wait(0.5)
        end
    end)
end

task.spawn(function()
    while true do
        if AutoSkip then
            skipWave()
            task.wait(SkipDelay or 1)
        else
            task.wait(1)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local currentInLobby = IsInLobby()
        if wasInLobby and not currentInLobby then
            hasVotedDifficulty = false
            hasVotedReady = false
            task.wait(2)
            local r = RS:WaitForChild("Remotes", 10)
            if r then
                if AutoDifficulty and not hasVotedDifficulty then
                    hasVotedDifficulty = true
                    local voteCast = r:WaitForChild("DifficultyVoteCast", 5)
                    if voteCast then
                        voteCast:FireServer(SelectedDifficulty)
                        task.wait(0.5)
                        voteCast:FireServer(SelectedDifficulty)
                        task.wait(0.5)
                    end
                end
                if not hasVotedReady then
                    hasVotedReady = true
                    local voteReady = r:FindFirstChild("DifficultyVoteReady")
                    if voteReady then
                        voteReady:FireServer()
                        task.wait(0.5)
                        voteReady:FireServer()
                        task.wait(0.5)
                    end
                end
                local speedControl = r:WaitForChild("SoloToggleSpeedControl", 5)
                if speedControl and AutoSpeed then speedControl:FireServer(true, true) end

                if AutoPlayMacro and MacroName ~= "" and MacroName ~= "None" and isfile and isfile(FolderPath .. MacroName .. ".json") then
                    task.spawn(function() loadMacro(MacroName) end)
                end
            end
        end
        wasInLobby = currentInLobby
    end
end)

local function countPlayers(apc)
    local count = 0
    local folder = apc:FindFirstChild("APC")
    local seats = folder and folder:FindFirstChild("Seats")
    if seats then
        for _, seat in ipairs(seats:GetChildren()) do
            if seat:IsA("Seat") and seat.Occupant then count += 1 end
        end
    end
    return count
end

local function moveTo(pos)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end

    local oldSpeed = hum.WalkSpeed
    hum.WalkSpeed = oldSpeed * 1.5
    local jumping = true

    task.spawn(function()
        while jumping do
            if (hrp.Position - pos).Magnitude > 6 then
                if hum.FloorMaterial ~= Enum.Material.Air then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
            task.wait(0.25)
        end
    end)

    while (hrp.Position - pos).Magnitude > 5 do
        if not AutoJoin or not IsInLobby() then break end
        hum:MoveTo(pos)
        task.wait(0.5)
    end

    jumping = false
    hum:ChangeState(Enum.HumanoidStateType.Landed)
    hum.WalkSpeed = oldSpeed
    return true
end

local function watchSeat(apc)
    task.spawn(function()
        while hasEntered and AutoJoin and IsInLobby() do
            if countPlayers(apc) > 1 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                break
            end
            task.wait(1)
        end
    end)
end

local function joinAPC(apc)
    if not AutoJoin or not IsInLobby() then return false end
    state = "Going"
    local folder = apc:FindFirstChild("APC")
    if not folder then return false end
    local ramp = folder:FindFirstChild("Ramp", true)
    if not ramp or countPlayers(apc) ~= 0 then return false end

    moveTo(ramp.Position)
    if not AutoJoin or not IsInLobby() then return false end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    local seats = folder:FindFirstChild("Seats")

    if hum and seats then
        for _, seat in ipairs(seats:GetChildren()) do
            if not AutoJoin or not IsInLobby() then break end
            if seat:IsA("Seat") and not seat.Occupant then
                hum.Sit = true
                seat:Sit(hum)
                task.wait(0.5)
                if seat.Occupant == hum then
                    hasEntered = true
                    state = "Joined"
                    watchSeat(apc)
                    return true
                end
            end
        end
    end
    return false
end

local function goWaiting()
    if not AutoJoin or not IsInLobby() then return end
    if state ~= "Waiting" then
        state = "Waiting"
        moveTo(DefaultPosition)
    end
end

local function findMap()
    if TargetMap == "" or TargetMap == "NONE" or not IsInLobby() then return nil end
    for _, folder in ipairs({ Workspace:FindFirstChild("APCs"), Workspace:FindFirstChild("APCs2") }) do
        if folder then
            for i = 1, 16 do
                local apc = folder:FindFirstChild(tostring(i))
                if apc then
                    local mapDisplay = apc:FindFirstChild("mapdisplay", true)
                    if mapDisplay then
                        local screen = mapDisplay:FindFirstChild("screen")
                        local display = screen and screen:FindFirstChild("displayscreen")
                        local mapObj = display and display:FindFirstChild("map")
                        if mapObj and mapObj.Text:lower():find(TargetMap:lower(), 1, true) then return apc end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        if not AutoJoin or not IsInLobby() then
            state = "Start"
            hasEntered = false
            task.wait(1)
            continue
        end
        if AutoJoin and IsInLobby() then
            if not hasEntered then
                local apc = findMap()
                if apc then
                    if countPlayers(apc) == 0 then joinAPC(apc) else goWaiting() end
                else
                    goWaiting()
                end
            end
        end
        task.wait(0.5)
    end
end)

local mt = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = { ... }

    if RecordMacro then
        if PlaceTower and self == PlaceTower and method == "InvokeServer" then
            TowerIndexCounter = TowerIndexCounter + 1
            local assignedIndex = TowerIndexCounter
            local towerName = args[2]
            local pos = args[3]
            local cashAmount = 0
            if TowerData then
                for tName, t in pairs(TowerData) do
                    if tName == towerName or (type(t) == "table" and (t.Name == towerName or t.Id == towerName or t.ID == tName)) then
                        if type(t) == "table" then cashAmount = t.placement_cost or 0 end
                        break
                    end
                end
            end
            TowerLevels[assignedIndex] = { name = towerName, top_level = 0, bottom_level = 0 }
            table.insert(Logs, {
                type = "Place",
                id = args[1],
                name = towerName,
                cash = cashAmount,
                pos = pos and { x = pos.X, y = pos.Y, z = pos.Z },
                rot = args[4] or 0,
                time = math.floor((os.clock() - StartTime) * 1000) / 1000
            })
        elseif TowerUpgradeRequest and self == TowerUpgradeRequest and method == "FireServer" then
            local targetIndex = args[1]
            local path = args[2]
            local currentData = TowerLevels[targetIndex]
            local levelJump = 1
            local upgradeCash = 0
            if currentData then
                if path == 1 or path == "1" or path == "top" then
                    currentData.top_level = currentData.top_level + 1
                    levelJump = currentData.top_level
                elseif path == 2 or path == "2" or path == "bottom" then
                    currentData.bottom_level = currentData.bottom_level + 1
                    levelJump = currentData.bottom_level
                end
                if GetTowerCash then upgradeCash = GetTowerCash(currentData.name, path, levelJump) end
            end
            table.insert(Logs, {
                type = "Upgrade",
                index = targetIndex,
                path = path,
                lv = levelJump,
                cash = upgradeCash,
                time = math.floor((os.clock() - StartTime) * 1000) / 1000
            })
        elseif SellTower and self == SellTower and method == "FireServer" then
            table.insert(Logs, { type = "Sell", index = args[1], time = math.floor((os.clock() - StartTime) * 1000) / 1000 })
        elseif self.Name == "SkipWaveVoteCast" and method == "FireServer" then
            table.insert(Logs, { type = "skipWave", time = math.floor((os.clock() - StartTime) * 1000) / 1000 })
        elseif AbilityRemote and self == AbilityRemote and method == "InvokeServer" then
            table.insert(Logs, { type = "Ability", index = args[1], ability = args[2], time = math.floor((os.clock() - StartTime) * 1000) / 1000 })
        end
    end
    return old(self, ...)
end)

setreadonly(mt, true)


local MapList = { "NONE" }
pcall(function()
    local mapDataRaw = game:HttpGet("https://raw.githubusercontent.com/minh597/Elfaria/refs/heads/main/MapData.txt")
    for line in mapDataRaw:gmatch("[^\r\n]+") do
        local cleanedName = line:match("^%s*(.-)%s*$")
        if cleanedName and cleanedName ~= "" then table.insert(MapList, string.upper(cleanedName)) end
    end
end)

local function GetMacroFiles()
    local files = { "None" }
    if listfiles and isfolder("Klaffy/Tower Defense X") then
        for _, filePath in pairs(listfiles("Klaffy/Tower Defense X")) do
            local fileName = filePath:match("Klaffy/Tower Defense X[/\\](.+)%.json$")
            if fileName and fileName ~= "Usernamesettings" then table.insert(files, fileName) end
        end
    end
    return files
end

local AuraPro = loadstring(game:HttpGet("https://raw.githubusercontent.com/minh597/Aura/refs/heads/main/Aura.lua"))()

local function Notify(title, content)
    pcall(function()
        if AuraPro and AuraPro.Notify then
            AuraPro:Notify({ Title = title, Content = content, Duration = 3 })
        end
    end)
end

local Window = AuraPro:CreateWindow({
    Name = "Aura UI - Tower Defense X",
    Theme = AuraPro.Themes and AuraPro.Themes.Dark or nil,
    ToggleKey = Enum.KeyCode.RightControl,
    Width = 560,
    Height = 380,
    Scale = 1.0,
    ConfigSave = "TDX_Config.json"
})

local InfoTab = Window:CreateTab("Info", "rbxassetid://6023426915")
InfoTab:CreateSection("Community & Support")
InfoTab:CreateButton({
    Name = "Join Discord",
    Callback = function()
        setclipboard("https://discord.gg/MUGFxNP4")
        Notify("Discord", "Copied Discord invite link to clipboard!")
    end
})

local MainTab = Window:CreateTab("Main", "rbxassetid://6023426915")
MainTab:CreateSection("Auto Features")

MainTab:CreateToggle({
    Name = "Auto Skip",
    Flag = "AutoSkipFlag",
    Default = AutoSkip,
    Callback = function(state)
        AutoSkip = state
        SaveConfig()
    end
})

MainTab:CreateSlider({
    Name = "Skip Delay (s)",
    Flag = "SkipDelayFlag",
    Min = 0,
    Max = 30,
    Default = SkipDelay,
    Increment = 1,
    Callback = function(val)
        SkipDelay = val
        SaveConfig()
    end
})

MainTab:CreateToggle({
    Name = "Auto Speed Up",
    Flag = "AutoSpeedFlag",
    Default = AutoSpeed,
    Callback = function(stateVal)
        AutoSpeed = stateVal
        SaveConfig()
    end
})

MainTab:CreateToggle({
    Name = "Auto Choose Difficulty",
    Flag = "AutoDifficultyFlag",
    Default = AutoDifficulty,
    Callback = function(stateVal)
        AutoDifficulty = stateVal
        SaveConfig()
    end
})

MainTab:CreateDropdown({
    Name = "Select Difficulty",
    Flag = "SelectedDifficultyFlag",
    Options = { "Easy", "Intermediate", "Elite", "Expert" },
    Default = SelectedDifficulty ~= "" and SelectedDifficulty or "Easy",
    MultiSelect = false,
    Searchable = false,
    Callback = function(selectedValue)
        SelectedDifficulty = selectedValue
        SaveConfig()
    end
})

local JoinTab = Window:CreateTab("Join", "rbxassetid://6023426915")
JoinTab:CreateSection("Auto Join Map")

JoinTab:CreateToggle({
    Name = "Enable Auto Join",
    Flag = "AutoJoinToggleFlag",
    Default = AutoJoin,
    Callback = function(stateVal)
        AutoJoin = stateVal
        SaveConfig()
        Notify("Auto Join", stateVal and "Auto Join Enabled" or "Auto Join Disabled")
    end
})

JoinTab:CreateDropdown({
    Name = "Select Map",
    Flag = "SelectedMapFlag",
    Options = MapList,
    Default = TargetMap ~= "" and TargetMap or "NONE",
    MultiSelect = false,
    Searchable = true,
    Callback = function(selectedValue)
        if selectedValue then
            TargetMap = selectedValue
            SaveConfig()
            Notify("Map", "Selected Map: " .. selectedValue)
        end
    end
})

local MacroTab = Window:CreateTab("Macro", "rbxassetid://6034287593")
MacroTab:CreateSection("Macro Management")

local MacroDropdown
MacroDropdown = MacroTab:CreateDropdown({
    Name = "Select Macro",
    Flag = "SelectedMacroDropdown",
    Options = GetMacroFiles(),
    Default = MacroName ~= "" and MacroName or "None",
    MultiSelect = false,
    Searchable = true,
    Callback = function(selectedValue)
        if selectedValue then
            MacroName = selectedValue
            SaveConfig()
        end
    end
})

MacroTab:CreateTextbox({
    Name = "Create New Macro",
    Placeholder = "Enter macro name...",
    Default = "",
    Callback = function(value)
        if value and value ~= "" then
            local actualPath = FolderPath .. value .. ".json"
            if writefile and not (isfile and isfile(actualPath)) then
                pcall(function() writefile(actualPath, HS:JSONEncode({})) end)
                if MacroDropdown and MacroDropdown.Refresh then
                    MacroDropdown:Refresh(GetMacroFiles(), true)
                elseif MacroDropdown and MacroDropdown.SetOptions then
                    MacroDropdown:SetOptions(GetMacroFiles())
                end
                Notify("Macro", "Created macro: " .. value)
            else
                Notify("Macro", "Macro already exists or cannot be created!")
            end
        end
    end
})

MacroTab:CreateButton({
    Name = "Refresh Macro List",
    Callback = function()
        if MacroDropdown and MacroDropdown.Refresh then
            MacroDropdown:Refresh(GetMacroFiles(), true)
        elseif MacroDropdown and MacroDropdown.SetOptions then
            MacroDropdown:SetOptions(GetMacroFiles())
        end
        Notify("Macro", "Macro list refreshed!")
    end
})

MacroTab:CreateButton({
    Name = "Delete Selected Macro",
    Callback = function()
        local selected = MacroName
        if selected and selected ~= "" and selected ~= "None" then
            local filePath = FolderPath .. selected .. ".json"
            if isfile and isfile(filePath) and delfile then
                delfile(filePath)
                MacroName = "None"
                SaveConfig()
                if MacroDropdown and MacroDropdown.Refresh then
                    MacroDropdown:Refresh(GetMacroFiles(), true)
                elseif MacroDropdown and MacroDropdown.SetOptions then
                    MacroDropdown:SetOptions(GetMacroFiles())
                end
                Notify("Macro", "Deleted macro: " .. selected)
            else
                Notify("Macro", "Macro file not found!")
            end
        else
            Notify("Macro", "No macro selected to delete!")
        end
    end
})

MacroTab:CreateSection("Record & Play Macro")

MacroTab:CreateButton({
    Name = "Run Selected Macro",
    Callback = function()
        if MacroName and MacroName ~= "" and MacroName ~= "None" then
            if isfile and isfile(FolderPath .. MacroName .. ".json") then
                task.spawn(function() loadMacro(MacroName) end)
                Notify("Macro", "Running macro: " .. MacroName)
            else
                Notify("Macro", "Macro file does not exist!")
            end
        else
            Notify("Macro", "Please select a macro first!")
        end
    end
})

MacroTab:CreateToggle({
    Name = "Record Macro",
    Flag = "RecordMacroToggle",
    Default = RecordMacro,
    Callback = function(stateVal)
        RecordMacro = stateVal
        if stateVal then
            StartTime = os.clock()
            TowerIndexCounter = 0
            TowerLevels = {}
            Logs = {}
            Notify("Record", "Started recording macro...")
        else
            if #Logs > 0 and writefile then
                local targetMacroName = (MacroName and MacroName ~= "None" and MacroName ~= "") and MacroName or ("Macro_" .. os.time())
                local filePath = FolderPath .. targetMacroName .. ".json"
                pcall(function() writefile(filePath, HS:JSONEncode(Logs)) end)
                if MacroDropdown and MacroDropdown.Refresh then
                    MacroDropdown:Refresh(GetMacroFiles(), true)
                elseif MacroDropdown and MacroDropdown.SetOptions then
                    MacroDropdown:SetOptions(GetMacroFiles())
                end
                Notify("Record", "Successfully saved macro: " .. targetMacroName)
            else
                Notify("Record", "No actions recorded to save!")
            end
        end
    end
})

MacroTab:CreateToggle({
    Name = "Auto Play Macro On Match Start",
    Flag = "AutoPlayMacroToggle",
    Default = AutoPlayMacro,
    Callback = function(stateVal)
        AutoPlayMacro = stateVal
        SaveConfig()
    end
})
