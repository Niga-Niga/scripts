repeat task.wait() until game:IsLoaded()

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new(0, 0))
end)

local folderName = "Shouko_ARX"
local playerName = game.Players.LocalPlayer.Name
local fileName = playerName .. "_data.json"

if not isfolder(folderName) then
    makefolder(folderName)
end

local defaultSettings = {
    autoPlay = false,
    autoUpgrade = false,
    autoStart = false,
    autoNext = false,
    autoRetry = false,
    autoLeave = false,
    webhookURL = "",
    webhookEnabled = false,
    playAfterUpgrade = false,
    selectedActs = {},
    autoClaimQuest = false,
    autoEvolveRare = false,
    slots = { place = {true, true, true, true, true, true}, upgrade = {0, 0, 0, 0, 0, 0} },
    selectPotential = {},
    selectStats = {},
    selectUnit = "",
    startRoll = false,
    autoReloadOnTeleport = false,
    autoJoinChallenge = false,
    deleteMap = false,
    autoPortal = false,
    autoRejoin = false,
    autoJoinPortal = false,
    selectedPortals = {},
    selectBanner = "Standard",
    autoSellTiers = {},
    autoSummonX10 = false,
    autoSummonX1 = false,
    autoJoinInfinityCastle = false,
    autoJoinMap = false,
    autoJoinMode = "Story",
    autoJoinWorldName = nil,
    autoJoinChapterKey = nil,
}

local function loadSettings()
    if isfile(folderName.."/"..fileName) then
        return game:GetService("HttpService"):JSONDecode(readfile(folderName.."/"..fileName))
    else
        writefile(folderName.."/"..fileName, game:GetService("HttpService"):JSONEncode(defaultSettings))
        return defaultSettings
    end
end
local function saveSettings(tbl)
    writefile(folderName.."/"..fileName, game:GetService("HttpService"):JSONEncode(tbl))
end
local settings = loadSettings()

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local function clickScreen()
    local viewport = workspace.CurrentCamera.ViewportSize
    local x = viewport.X / 2
    local y = viewport.Y / 2
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function nativeClick(button)
    if not button or not button:IsA("GuiButton") then return end
    if not button.Visible or not button.Active then return end
    if button.Name == "Retry" and button.Text:match("0/") then return end
    GuiService.SelectedObject = button
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    task.wait(0.3)
    GuiService.SelectedObject = nil
end

local function handleGameEndedUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local _ = LocalPlayer:FindFirstChild("Summon_Maximum") or LocalPlayer:WaitForChild("Summon_Maximum", 5)
    while LocalPlayer:FindFirstChild("Summon_Maximum") do
        clickScreen()
        task.wait(0.25)
    end
    task.wait(0.5)
    local success, buttonContainer = pcall(function()
        return playerGui:WaitForChild("RewardsUI", 5):WaitForChild("Main", 5):WaitForChild("LeftSide", 5):WaitForChild("Button", 5)
    end)
    if not success or not buttonContainer then return end
    repeat
        local clicked = false
        local retryBtn = buttonContainer:FindFirstChild("Retry")
        local nextBtn = buttonContainer:FindFirstChild("Next")
        local leaveBtn = buttonContainer:FindFirstChild("Leave")
        local ar, an, al = settings.autoRetry, settings.autoNext, settings.autoLeave
        if ar and an and al then
            if nextBtn and nextBtn.Visible and nextBtn.Active then nativeClick(nextBtn) clicked = true task.wait(1) end
            if leaveBtn and leaveBtn.Visible and leaveBtn.Active then nativeClick(leaveBtn) clicked = true task.wait(1) end
            if retryBtn and retryBtn.Visible and retryBtn.Active then nativeClick(retryBtn) clicked = true task.wait(1) end
        elseif an and ar and not al then
            if retryBtn and retryBtn.Visible and retryBtn.Active then nativeClick(retryBtn) clicked = true task.wait(1) end
            if nextBtn and nextBtn.Visible and nextBtn.Active then nativeClick(nextBtn) clicked = true task.wait(1) end
        elseif an and al and not ar then
            if nextBtn and nextBtn.Visible and nextBtn.Active then nativeClick(nextBtn) clicked = true task.wait(1) end
            if leaveBtn and leaveBtn.Visible and leaveBtn.Active then nativeClick(leaveBtn) clicked = true task.wait(1) end
        elseif al and ar and not an then
            if retryBtn and retryBtn.Visible and retryBtn.Active then nativeClick(retryBtn) clicked = true task.wait(1) end
            if leaveBtn and leaveBtn.Visible and leaveBtn.Active then nativeClick(leaveBtn) clicked = true task.wait(1) end
        else
            if an and nextBtn and nextBtn.Visible and nextBtn.Active then nativeClick(nextBtn) clicked = true end
            if al and leaveBtn and leaveBtn.Visible and leaveBtn.Active then nativeClick(leaveBtn) clicked = true end
            if ar and retryBtn and retryBtn.Visible and retryBtn.Active then nativeClick(retryBtn) clicked = true end
        end
        task.wait(0.5)
        if not playerGui:FindFirstChild("GameEndedAnimationUI") then break end
        if not clicked then task.wait(0.5) end
    until not playerGui:FindFirstChild("GameEndedAnimationUI")
end

task.spawn(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("GameEndedAnimationUI")
    if existing then task.wait(1) handleGameEndedUI() end
    playerGui.ChildAdded:Connect(function(child)
        if child:IsA("ScreenGui") and child.Name == "GameEndedAnimationUI" then
            task.wait(1) handleGameEndedUI()
        end
    end)
end)

task.spawn(function()
    while true do
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local endUI = playerGui and playerGui:FindFirstChild("GameEndedAnimationUI")
        local ready = endUI and not LocalPlayer:FindFirstChild("Summon_Maximum")
        if ready and (settings.autoRetry or settings.autoNext or settings.autoLeave) then
            handleGameEndedUI()
            repeat task.wait(0.5) until not playerGui:FindFirstChild("GameEndedAnimationUI")
        end
        task.wait(1)
    end
end)

task.spawn(function()
    local hasFired = false
    while true do
        if settings.autoStart and not workspace:FindFirstChild("Lobby") and not hasFired then
            task.wait(2)
            game.ReplicatedStorage.Remote.Server.OnGame.Voting.VotePlaying:FireServer()
            hasFired = true
        elseif workspace:FindFirstChild("Lobby") then
            hasFired = false
        end
        task.wait(1)
    end
end)

local ActMapping = {
    OnePiece_RangerStage1 = "Voocha Village Act 1",
    OnePiece_RangerStage2 = "Voocha Village Act 2",
    OnePiece_RangerStage3 = "Voocha Village Act 3",
    Namek_RangerStage1 = "Green Planet Act 1",
    Namek_RangerStage2 = "Green Planet Act 2",
    Namek_RangerStage3 = "Green Planet Act 3",
    DemonSlayer_RangerStage1 = "Demon Forest Act 1",
    DemonSlayer_RangerStage2 = "Demon Forest Act 2",
    DemonSlayer_RangerStage3 = "Demon Forest Act 3",
    Naruto_RangerStage1 = "Leaf Village Act 1",
    Naruto_RangerStage2 = "Leaf Village Act 2",
    Naruto_RangerStage3 = "Leaf Village Act 3",
    OPM_RangerStage1 = "Z City Act 1",
    OPM_RangerStage2 = "Z City Act 2",
    OPM_RangerStage3 = "Z City Act 3",
    TokyoGhoul_RangerStage1 = "Ghoul Act 1",
    TokyoGhoul_RangerStage2 = "Ghoul Act 2",
    TokyoGhoul_RangerStage3 = "Ghoul Act 3",
    TokyoGhoul_RangerStage4 = "Ghoul Act 4",
    TokyoGhoul_RangerStage5 = "Ghoul Act 5",
}

local HttpService = game:GetService("HttpService")
local raw = game:HttpGet("https://cdn.shouko.dev/RokidManager/neyoshiiuem/main/world.txt")
local DataWorld = HttpService:JSONDecode(raw)

local function getModeBuckets(mode)
    if mode == "Story" then
        return DataWorld and DataWorld.Story, "Chapter", "Chapter"
    elseif mode == "Ranger Stage" then
        return DataWorld and DataWorld.Ranger, "RangerChapter", "Stage"
    elseif mode == "Raids Stage" then
        return DataWorld and DataWorld.Raid, "RaidChapter", "Stage"
    end
end
local SPECIAL_PREFIX_TO_WORLDKEY = { SBR = "SteelBlitzRush" }
local function resolveWorldKey(worldName, mode)
    local bucket, arrField = getModeBuckets(mode)
    local entry = bucket and bucket[worldName]
    local arr = entry and entry[arrField]
    local first = arr and arr[1]
    if not first then return nil end
    local prefix = first:match("^(.-)_")
    if SPECIAL_PREFIX_TO_WORLDKEY[prefix] then return SPECIAL_PREFIX_TO_WORLDKEY[prefix] end
    return prefix
end
local function buildMapListForMode(mode)
    local bucket
    if mode == "Story" then
        bucket = DataWorld.Story
    elseif mode == "Ranger Stage" then
        bucket = DataWorld.Ranger
    elseif mode == "Raids Stage" then
        bucket = DataWorld.Raid
    end
    local out = {}
    if bucket then
        for worldName,_ in pairs(bucket) do table.insert(out, worldName) end
    end
    table.sort(out)
    return out
end
local function buildChapterOptions(worldName, mode)
    local bucket, arrField
    if mode == "Story" then
        bucket, arrField = DataWorld.Story, "Chapter"
    elseif mode == "Ranger Stage" then
        bucket, arrField = DataWorld.Ranger, "RangerChapter"
    elseif mode == "Raids Stage" then
        bucket, arrField = DataWorld.Raid, "RaidChapter"
    end
    local entry = bucket and bucket[worldName]
    local arr = entry and entry[arrField] or {}
    local labels, mapLabelToKey = {}, {}
    for i,key in ipairs(arr) do
        local n = tonumber(key:match("(%d+)$")) or i
        local label = (mode == "Story") and ("Chapter "..n) or ("Stage "..n)
        table.insert(labels, label)
        mapLabelToKey[label] = key
    end
    return labels, mapLabelToKey
end
function AutoJoinMap()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local PlayRoomEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")

    task.spawn(function()
        while settings.autoJoinMap do
            if workspace:FindFirstChild("Lobby") then
                local mode       = settings.autoJoinMode
                local worldName  = settings.autoJoinWorldName
                local chapterKey = settings.autoJoinChapterKey
                if mode and worldName and chapterKey then
                    local worldKey = resolveWorldKey(worldName, mode)
                    if worldKey then
                        pcall(function()
                            PlayRoomEvent:FireServer("Create")
                            PlayRoomEvent:FireServer("Change-Mode",   { Mode = mode })
                            PlayRoomEvent:FireServer("Change-World",  { World = worldKey })
                            PlayRoomEvent:FireServer("Change-Chapter",{ Chapter = chapterKey })
                            PlayRoomEvent:FireServer("Submit")
                            PlayRoomEvent:FireServer("Start")
                        end)
                        local hasSystemMessage = PlayerGui:FindFirstChild("SystemMessage")
                        if hasSystemMessage and hasSystemMessage.Enabled then return end
                        task.wait(1)
                    end
                end
            else
                task.wait(1)
            end
            task.wait(0.5)
        end
    end)
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayRoomEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")

local MapLabelToName = {
    ["Voocha Village"] = "OnePiece",
    ["Green Planet"] = "Namek",
    ["Demon Forest"] = "DemonSlayer",
    ["Leaf Village"] = "Naruto",
    ["Z City"] = "OPM",
    ["Ghoul City"] = "TokyoGhoul",
}

local function getGameEndedInfo()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    local endedUI = playerGui:FindFirstChild("RewardsUI") if not endedUI then return nil end
    local mainFrame = endedUI:FindFirstChild("Main") if not mainFrame then return nil end
    local leftSide = mainFrame:FindFirstChild("LeftSide") if not leftSide then return nil end
    local worldText, chapterText, difficultyText = "", "", ""
    if leftSide:FindFirstChild("World") and leftSide.World:IsA("TextLabel") then worldText = leftSide.World.Text end
    if leftSide:FindFirstChild("Chapter") and leftSide.Chapter:IsA("TextLabel") then chapterText = leftSide.Chapter.Text end
    if leftSide:FindFirstChild("Difficulty") and leftSide.Difficulty:IsA("TextLabel") then difficultyText = leftSide.Difficulty.Text end
    local mapKey = MapLabelToName[worldText] or nil
    local chapterNum = chapterText and chapterText:match("Chapter%s*(%d+)") or nil
    local chapterKey = (mapKey and chapterNum) and (mapKey .. "_Chapter" .. chapterNum) or nil
    if not mapKey or not chapterKey or not difficultyText then return nil end
    return { MapKey = mapKey, ChapterKey = chapterKey, Difficulty = difficultyText }
end

local function autoCreateRoom(info)
    if not info then return end
    if workspace:FindFirstChild("Lobby") then
        PlayRoomEvent:FireServer("Create"); task.wait(0.2)
        PlayRoomEvent:FireServer("Change-World", { World = info.MapKey }); task.wait(0.2)
        PlayRoomEvent:FireServer("Change-Chapter", { Chapter = info.ChapterKey }); task.wait(0.2)
        PlayRoomEvent:FireServer("Change-Difficulty", { Difficulty = info.Difficulty }); task.wait(0.2)
        PlayRoomEvent:FireServer("Submit"); task.wait(0.2)
        PlayRoomEvent:FireServer("Start")
    end
end

local latestGameInfo = nil

LocalPlayer.PlayerGui.ChildAdded:Connect(function(gui)
    if gui.Name == "GameEndedAnimationUI" then
        task.wait(2)
        latestGameInfo = getGameEndedInfo()
    end
end)

local serverStartTime = os.time()
local function getServerUptime() return os.time() - serverStartTime end

local function checkFPS(durationSeconds)
    local frameCount = 0
    local startTime = tick()
    local conn = RunService.Heartbeat:Connect(function() frameCount = frameCount + 1 end)
    task.wait(durationSeconds)
    conn:Disconnect()
    local elapsed = tick() - startTime
    if elapsed > 0 then return frameCount / elapsed else return 0 end
end

local function fpsMonitorLoop()
    while settings.autoRejoin do
        if workspace:FindFirstChild("Lobby") then
            task.wait(5)
        else
            local uptime = getServerUptime()
            if uptime >= 1000 then
                local fps = checkFPS(1)
                if fps <= 10 and latestGameInfo then
                    pcall(function() autoCreateRoom(latestGameInfo) end)
                    task.wait(15)
                else
                    task.wait(10)
                end
            else
                task.wait(30)
            end
        end
    end
end

local unitNames = {}
local function getEquippedUnits()
    unitNames = {}
    for i = 1, 6 do
        local slotPath = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
        if slotPath and slotPath:FindFirstChild("Frame") and slotPath.Frame:FindFirstChild("UnitFrame") then
            local info = slotPath.Frame.UnitFrame:FindFirstChild("Info")
            if info and info:FindFirstChild("Folder") and info.Folder:IsA("ObjectValue") and info.Folder.Value then
                table.insert(unitNames, info.Folder.Value.Name)
            end
        end
    end
end

local function deployUnits()
    local player = game.Players.LocalPlayer
    local yen = player:FindFirstChild("Yen") and player.Yen.Value or 0
    for i = 1, 6 do
        if settings.slots.place[i] then
            local slot = player.PlayerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
            if slot then
                local frame = slot:FindFirstChild("Frame")
                local unitFrame = frame and frame:FindFirstChild("UnitFrame")
                local info = unitFrame and unitFrame:FindFirstChild("Info")
                local folderObj = info and info:FindFirstChild("Folder")
                local costLabel = info and info:FindFirstChild("Cost")
                local isCooledDown = frame and not frame:FindFirstChild("CD_FRAME")
                if folderObj and folderObj:IsA("ObjectValue") and folderObj.Value and costLabel and isCooledDown then
                    local costText = costLabel.Text
                    local costNumber = tonumber(costText:match("%d+"))
                    if costNumber and yen >= costNumber then
                        game.ReplicatedStorage.Remote.Server.Units.Deployment:FireServer(folderObj.Value)
                    end
                end
            end
        end
    end
end

local function getYen()
    local success, yen = pcall(function()
        return game.Players.LocalPlayer.PlayerGui.HUD.InGame.Main.Stats.Yen.YenValue.Value
    end)
    return success and yen or 0
end

function tryUpgradeSlot(i)
    local player = game.Players.LocalPlayer
    local unitsFolder = player:WaitForChild("UnitsFolder")
    local upgradeInput = settings.slots.upgrade
    local targetUpgrade = upgradeInput[i]
    if not settings.slots.place[i] or targetUpgrade <= 0 then return false end
    local slot = player.PlayerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
    if not slot then return false end
    local folderObj = slot:FindFirstChild("Frame") and slot.Frame:FindFirstChild("UnitFrame") and slot.Frame.UnitFrame:FindFirstChild("Info") and slot.Frame.UnitFrame.Info:FindFirstChild("Folder")
    if not folderObj or not folderObj:IsA("ObjectValue") or not folderObj.Value then return false end
    local unitName = folderObj.Value.Name
    local unitObject = unitsFolder:FindFirstChild(unitName)
    if not unitObject then return false end
    local upgradeFolder = unitObject:FindFirstChild("Upgrade_Folder")
    if not upgradeFolder then return false end
    local level = upgradeFolder:FindFirstChild("Level")
    local cost = upgradeFolder:FindFirstChild("Upgrade_Cost")
    if not level or not cost then return false end
    local currentLevel = level.Value
    if currentLevel >= targetUpgrade then return false end
    local yen = getYen()
    if yen < cost.Value then return false end
    local success = pcall(function()
        game.ReplicatedStorage.Remote.Server.Units.Upgrade:FireServer(unitObject)
    end)
    return success
end

local isUpgrading = false

local function waitForGameEndToDisappear()
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    if not playerGui:FindFirstChild("GameEndedAnimationUI") then return false end
    while playerGui:FindFirstChild("GameEndedAnimationUI") do task.wait(0.5) end
    return true
end

function upgradeUnits()
    if isUpgrading then return end
    isUpgrading = true
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local unitsFolder = player:WaitForChild("UnitsFolder")
    local preGameUI = playerGui:FindFirstChild("HUD") and playerGui.HUD:FindFirstChild("UnitSelectBeforeGameRunning_UI")
    if preGameUI then isUpgrading = false return end
    local paused = waitForGameEndToDisappear()
    if paused then task.wait(1) end
    while true do
        local anyNeedsUpgrade = false
        for i = 1, 6 do
            if settings.slots.place[i] then
                local slot = playerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
                if slot then
                    local folderObj = slot:FindFirstChild("Frame") and slot.Frame:FindFirstChild("UnitFrame") and slot.Frame.UnitFrame:FindFirstChild("Info") and slot.Frame.UnitFrame.Info:FindFirstChild("Folder")
                    if folderObj and folderObj:IsA("ObjectValue") and folderObj.Value then
                        local unitName = folderObj.Value.Name
                        local unitObject = unitsFolder:FindFirstChild(unitName)
                        if unitObject then
                            local level = unitObject:WaitForChild("Upgrade_Folder"):WaitForChild("Level").Value
                            local targetUpgrade = settings.slots.upgrade[i]
                            if level < targetUpgrade then
                                anyNeedsUpgrade = true
                                local didUpgrade = tryUpgradeSlot(i)
                                if didUpgrade then task.wait(0.5) break end
                            end
                        end
                    end
                end
            end
        end
        if not anyNeedsUpgrade then break end
        task.wait(0.3)
    end
    isUpgrading = false
end

local HttpService = game:GetService("HttpService")

local function collectData()
    local d = {}
    local expBar = LocalPlayer.PlayerGui:WaitForChild("HUD"):FindFirstChild("ExpBar")
    if expBar and expBar:FindFirstChild("Numbers") then
        local raw = expBar.Numbers.Text
        local lvl = raw:match("Level%s*(%d+)") or "0"
        local xp  = raw:match("%[(.-)%]</font>") or "0/0"
        d.levelText = "Level " .. lvl .. " [" .. xp .. "]"
    else
        d.levelText = "Level 0 [0/0]"
    end
    local menu = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("MenuFrame") and LocalPlayer.PlayerGui.HUD.MenuFrame:FindFirstChild("LeftSide") and LocalPlayer.PlayerGui.HUD.MenuFrame.LeftSide:FindFirstChild("Frame")
    d.gems = (menu and menu:FindFirstChild("Gems") and menu.Gems:FindFirstChildWhichIsA("TextLabel").Text) or "0"
    d.gold = (menu and menu:FindFirstChild("Gold") and menu.Gold:FindFirstChildWhichIsA("TextLabel").Text) or "0"
    d.egg  = (menu and menu:FindFirstChild("Egg") and menu.Egg:FindFirstChildWhichIsA("TextLabel").Text) or "0"
    d.matchInfo = {}
    local leftSide = LocalPlayer.PlayerGui:FindFirstChild("RewardsUI") and LocalPlayer.PlayerGui.RewardsUI:FindFirstChild("Main") and LocalPlayer.PlayerGui.RewardsUI.Main:FindFirstChild("LeftSide")
    if leftSide then
        for _, key in ipairs({"GameStatus","Chapter","Difficulty","Mode","World","TotalTime"}) do
            local lbl = leftSide:FindFirstChild(key)
            d.matchInfo[key] = (lbl and lbl:IsA("TextLabel") and lbl.Text) or ""
        end
    end
    d.rewardsList = {}
    local rewardsRoot = LocalPlayer:FindFirstChild("RewardsShow")
    local playerData = game:GetService("ReplicatedStorage"):FindFirstChild("Player_Data")
    local itemsFolder = playerData and playerData:FindFirstChild(LocalPlayer.Name) and playerData[LocalPlayer.Name]:FindFirstChild("Items")
    if rewardsRoot and itemsFolder then
        for _, folder in ipairs(rewardsRoot:GetChildren()) do
            if folder:IsA("Folder") then
                local name = folder.Name
                local amt = (folder:FindFirstChild("Amount") and folder.Amount.Value) or 0
                local itemData = itemsFolder:FindFirstChild(name)
                local total = (itemData and itemData:FindFirstChild("Amount") and itemData.Amount.Value) or 0
                table.insert(d.rewardsList, "+" .. amt .. " " .. name .. " [total: " .. total .. "]")
            end
        end
    end
    return d
end

local function sendWebhook()
    if not settings.webhookURL or settings.webhookURL == "" then return end
    local d = collectData()
    local status = (d.matchInfo.GameStatus or ""):lower()
    local color = 0xffff00
    if status:find("won") then color = 0x00ff00 elseif status:find("defect") then color = 0xff0000 end
    local fields = {
        { name="Stats",  value=string.format("%s\nGems: %s\nGold: %s\nEgg: %s", d.levelText, d.gems, d.gold, d.egg), inline=false },
        { name="Rewards", value=#d.rewardsList > 0 and table.concat(d.rewardsList, "\n") or "None", inline=true },
        { name="Match Info", value=table.concat({ d.matchInfo.GameStatus, d.matchInfo.Chapter, d.matchInfo.Difficulty, d.matchInfo.Mode, d.matchInfo.World, d.matchInfo.TotalTime }, "\n"), inline=false },
    }
    local payload = { embeds = {{ title = "Anime Rangers X - Shouko.Dev", color = color, fields = fields, footer = { text = "Send " .. os.date("%Y-%m-%d %H:%M:%S") }, }} }
    local ok, err = pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if not req then error("No HTTP request function available") end
        req({ Url = settings.webhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload), })
    end)
    if not ok then warn("Webhook failed:", err) end
end

LocalPlayer.PlayerGui.ChildAdded:Connect(function(gui)
    if gui.Name == "GameEndedAnimationUI" and settings.webhookEnabled then
        task.wait(2)
        sendWebhook()
    end
end)

local TierUnitNames = {
    "Naruto","Naruto:Shiny","Zoro","Zoro:Shiny","Chaozi:Shiny","Chaozi","Goku","Goku:Shiny",
    "Krillin","Luffy","Nezuko","Sanji","Usopp","Yamcha","Krillin:Shiny","Luffy:Shiny",
    "Nezuko:Shiny","Sanji:Shiny","Usopp:Shiny","Yamcha:Shiny",
}

local function evolveRareUnits()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local collection = ReplicatedStorage:FindFirstChild("Player_Data") and ReplicatedStorage.Player_Data:FindFirstChild(LocalPlayer.Name) and ReplicatedStorage.Player_Data[LocalPlayer.Name]:FindFirstChild("Collection")
    if not collection then return end
    for _, unitFolder in ipairs(collection:GetChildren()) do
        if unitFolder:IsA("Folder") and table.find(TierUnitNames, unitFolder.Name) then
            local tag = unitFolder:FindFirstChild("Tag")
            local evolveTier = unitFolder:FindFirstChild("EvolveTier")
            if tag and tag:IsA("StringValue") and tag.Value ~= "" then
                local tier = evolveTier and evolveTier.Value or ""
                if tier == "" then
                    local args = { tag.Value, "Hyper" }
                    ReplicatedStorage.Remote.Server.Units.EvolveTier:FireServer(unpack(args))
                    task.wait(0.1)
                end
            end
        end
    end
end

local isRolling = false
local startRollToggle

local function autoRoll()
    local rs  = game:GetService("ReplicatedStorage")
    local plr = game:GetService("Players").LocalPlayer
    local collection = rs:WaitForChild("Player_Data"):WaitForChild(plr.Name):WaitForChild("Collection")
    local rerollRemote = rs:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Gambling"):WaitForChild("RerollPotential")
    local unitEntry = settings.selectUnit
    local unitName = unitEntry:match("^(.-)%s*%[") or unitEntry
    local folder = collection:FindFirstChild(unitName)
    if not folder then warn("Unit folder not found:", unitName) return end
    local pending = {}
    for _, potential in ipairs(settings.selectPotential) do
        local resultNV = folder:FindFirstChild(potential .. "Potential")
        local resultVal = resultNV and resultNV.Value or ""
        local matched = false
        for _, desired in ipairs(settings.selectStats) do
            if resultVal == desired then matched = true break end
        end
        if not matched then pending[potential] = true end
    end
    if not next(pending) then
        if startRollToggle then startRollToggle:Set({Default=false}) end
        settings.startRoll = false
        saveSettings(settings)
        return
    end
    isRolling = true
    while isRolling and next(pending) do
        for potential in pairs(pending) do
            if not isRolling then break end
            local tagNV = folder:FindFirstChild("Tag")
            if not tagNV then warn("Unit tag not found:", unitName) isRolling=false return end
            local tagStr = tagNV.Value
            rerollRemote:FireServer(potential, tagStr, "Selective")
            task.wait(0.3)
            local resultNV = folder:FindFirstChild(potential .. "Potential")
            local resultVal = resultNV and resultNV.Value or ""
            for _, desired in ipairs(settings.selectStats) do
                if resultVal == desired then pending[potential] = nil break end
            end
        end
    end
    isRolling = false
    if startRollToggle then startRollToggle:Set({Default=false}) end
    settings.startRoll = false
    saveSettings(settings)
end

local rerollConfig = { unit = nil, trail = {}, start = false }
function autoRollTrail(unitEntry, desiredTrails)
    local rs = game:GetService("ReplicatedStorage")
    local plr = game:GetService("Players").LocalPlayer
    local unitName = unitEntry:match("^(.-)%s*%[") or unitEntry
    local collection = rs:WaitForChild("Player_Data"):WaitForChild(plr.Name):WaitForChild("Collection")
    local rerollRemote = rs:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Gambling"):WaitForChild("RerollTrait")
    local folder = collection:FindFirstChild(unitName)
    if not folder then warn("Unit not found:", unitName) return end
    local function hasDesiredTrail()
        local primary = folder:FindFirstChild("PrimaryTrait")
        local secondary = folder:FindFirstChild("SecondaryTrait")
        local pVal = primary and primary.Value or ""
        local sVal = secondary and secondary.Value or ""
        for _, desired in ipairs(desiredTrails) do
            if pVal == desired or sVal == desired then return true end
        end
        return false
    end
    if hasDesiredTrail() then return end
    while rerollConfig.start do
        rerollRemote:FireServer(folder, "Reroll", "Main", "Shards")
        task.wait(0.3)
        if hasDesiredTrail() then
            rerollConfig.start = false
            break
        end
    end
end

local function autoPortalFunc()
    local player = Players.LocalPlayer
    local function getCharacter()
        local char = player.Character or player.CharacterAdded:Wait()
        while not char:FindFirstChild("HumanoidRootPart") do char.ChildAdded:Wait() end
        return char
    end
    local function getAllParts(folder)
        local parts = {}
        for _, obj in ipairs(folder:GetChildren()) do if obj:IsA("Part") then table.insert(parts, obj) end end
        return parts
    end
    local function activatePrompt(prompt)
        for _ = 1, 10 do
            if prompt:IsA("ProximityPrompt") then fireproximityprompt(prompt) end
            task.wait(0.1)
        end
    end
    task.spawn(function()
        local character = getCharacter()
        local hrp = character:WaitForChild("HumanoidRootPart")
        while settings.autoPortal do
            local portalFolder = workspace:FindFirstChild("Portal")
            if portalFolder then
                local parts = getAllParts(portalFolder)
                if #parts > 0 then
                    local selectedPart = parts[math.random(1, #parts)]
                    hrp.CFrame = selectedPart.CFrame + Vector3.new(0, 5, 0)
                    local prompt = selectedPart:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then activatePrompt(prompt) end
                end
            end
            task.wait(1)
        end
    end)
end

local RemoteItemUse = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Lobby"):WaitForChild("ItemUse")
local RemotePortalEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Lobby"):WaitForChild("PortalEvent")

function autoJoinPortalLoop()
    while settings.autoJoinPortal do
        if not workspace:FindFirstChild("Lobby") then
            task.wait(1)
        else
            local playerData = ReplicatedStorage:FindFirstChild("Player_Data")
            if not playerData then task.wait(1) continue end
            local clone = playerData:FindFirstChild(LocalPlayer.Name)
            if not clone then task.wait(1) continue end
            local items = clone:FindFirstChild("Items")
            if not items then task.wait(1) continue end
            for _, portalName in ipairs(settings.selectedPortals) do
                local portalItem = items:FindFirstChild(portalName)
                if portalItem then
                    pcall(function() RemoteItemUse:FireServer(portalItem) end)
                    task.wait(1)
                    pcall(function() RemotePortalEvent:FireServer("Start") end)
                    task.wait(3)
                end
            end
            task.wait(2)
        end
    end
end

local function autoClaimQuestLoop()
    while settings.autoClaimQuest do
        local lobbyFolder = workspace:FindFirstChild("Lobby")
        if lobbyFolder and lobbyFolder:IsA("Folder") then
            local args = { "ClaimAll" }
            game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Gameplay"):WaitForChild("QuestEvent"):FireServer(unpack(args))
        end
        task.wait(10)
    end
end

local function startAutoPlayLoop()
    getEquippedUnits()
    task.spawn(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        while settings.autoPlay do
            local isPreGame = playerGui:FindFirstChild("HUD") and playerGui.HUD:FindFirstChild("UnitSelectBeforeGameRunning_UI")
            local isEndGame = playerGui:FindFirstChild("GameEndedAnimationUI")
            if isPreGame or isEndGame then
                repeat task.wait(0.5)
                    isPreGame = playerGui:FindFirstChild("HUD") and playerGui.HUD:FindFirstChild("UnitSelectBeforeGameRunning_UI")
                    isEndGame = playerGui:FindFirstChild("GameEndedAnimationUI")
                until not isPreGame and not isEndGame
                task.wait(1.5)
            end
            if settings.playAfterUpgrade and settings.autoUpgrade then
                if not isUpgrading then upgradeUnits() end
                while isUpgrading do task.wait(0.2) end
            end



    if settings.pathDeployEnabled then
        deployUnitsWithPath()
    else
        deployUnits()
    end

            task.wait(1)
        end
    end)
end

local function startAutoUpgradeLoop()
    task.spawn(function()
        while settings.autoUpgrade do
            upgradeUnits()
            task.wait(1)
        end
    end)
end

local function setAutoReloadOnTeleport(val)
    if val then
        queue_on_teleport([[repeat task.wait() until game:IsLoaded()
loadstring(game:HttpGet('https://cdn.shouko.dev/RokidManager/neyoshiiuem/main/arx_main.lua'))()]])
    end
end

local function handleDeleteMapToggle(val)
    if val then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/junggamyeon/MyScript/refs/heads/main/betterfps.lua"))()
    end
end

local function autoSummonX10Loop()
    task.spawn(function()
        while settings.autoSummonX10 do
            local args = { "x10", settings.selectBanner or "Standard" }
            if settings.autoSellTiers and next(settings.autoSellTiers) ~= nil then
                table.insert(args, settings.autoSellTiers)
            end
            game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Gambling"):WaitForChild("UnitsGacha"):FireServer(unpack(args))
            task.wait(0.3)
        end
    end)
end

local function autoSummonX1Loop()
    task.spawn(function()
        while settings.autoSummonX1 do
            local args = { "x1", settings.selectBanner or "Standard" }
            if settings.autoSellTiers and next(settings.autoSellTiers) ~= nil then
                table.insert(args, settings.autoSellTiers)
            end
            game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Gambling"):WaitForChild("UnitsGacha"):FireServer(unpack(args))
            task.wait(0.3)
        end
    end)
end


local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
pcall(function() MacLib:SetFolder(folderName) end)
local Window = MacLib:Window({
    Title = "Shouko.Dev - ARX",
    Subtitle = "Shouko.Dev game script",
    Size = UDim2.fromOffset(650, 500),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = false,
    AcrylicBlur = false,
})pcall(function() Window.Instance.Name = "ShoukoDev" end)

local RootSection = Window:CreateTabSection("Shouko.ARX")

local MainTab = RootSection:Tab({ Name = "Main",     Icon = NebulaIcons:GetIcon('layout-grid','Lucide'), Columns = 2 })
local AutoPlayTab = RootSection:Tab({ Name = "Auto Play", Icon = NebulaIcons:GetIcon('gamepad-2','Lucide'), Columns = 2 })
local WebhookTab = RootSection:Tab({ Name = "Webhook",   Icon = NebulaIcons:GetIcon('link','Material'), Columns = 2 })
local ShopTab = RootSection:Tab({ Name = "Shop",      Icon = NebulaIcons:GetIcon('shopping-basket','Lucide'), Columns = 2 })
local PortalTab = RootSection:Tab({ Name = "Portal",    Icon = NebulaIcons:GetIcon('badge','Lucide'), Columns = 2 })

MainTab:Header({ Text = "Automation" })
local controlGB = MainTab:Section({ Side = "Left" })
controlGB:Toggle({
    Name = "Auto Start",
    Default = settings.autoStart,
    Callback = function(val) settings.autoStart = val; saveSettings(settings) end
}, "MAIN_AUTOSTART")
controlGB:Toggle({
    Name = "Auto Next",
    Default = settings.autoNext,
    Callback = function(val) settings.autoNext = val; saveSettings(settings) end
}, "MAIN_AUTONEXT")
controlGB:Toggle({
    Name = "Auto Retry",
    Default = settings.autoRetry,
    Callback = function(val) settings.autoRetry = val; saveSettings(settings) end
}, "MAIN_AUTORETRY")
controlGB:Toggle({
    Name = "Auto Leave",
    Default = settings.autoLeave,
    Callback = function(val) settings.autoLeave = val; saveSettings(settings) end
}, "MAIN_AUTOLEAVE")

controlGB:Toggle({
    Name = "Auto Execute",
    Default = settings.autoReloadOnTeleport or false,
    Callback = function(val)
        settings.autoReloadOnTeleport = val
        saveSettings(settings)
        setAutoReloadOnTeleport(val)
    end
}, "MAIN_AUTOEXECUTE")

controlGB:Toggle({
    Name = "Delete Map",
    Default = settings.deleteMap or false,
    Callback = function(val)
        settings.deleteMap = val
        saveSettings(settings)
        handleDeleteMapToggle(val)
    end
}, "MAIN_DELETEMAP")

MainTab:Header({ Text = "Misc" })
local miscGB = MainTab:Section({ Side = "Left" })
miscGB:Toggle({
    Name = "Auto Claim Quest",
    Default = settings.autoClaimQuest or false,
    Callback = function(val)
        settings.autoClaimQuest = val; saveSettings(settings)
        if val then task.spawn(autoClaimQuestLoop) end
    end
}, "MAIN_CLAIMQUEST")

MainTab:Header({ Text = "Auto Join Map" })
local gb = MainTab:Section({ Side = "Right" })
gb:Header({ Text = "Select Mode" })
local modeLabel = gb
gb:Header({ Text = "Select Map" })
local mapLabel = gb
gb:Header({ Text = "Select Chapter" })
local chapLabel = gb
local modeDD, mapDD, chapDD

modeDD = modeLabel:Dropdown({
    Options = {"Story","Ranger Stage","Raids Stage"},
    Default = { settings.autoJoinMode or "Story" },
    Multi = false,
    Placeholder = "--",
    Callback = function(sel)
        local choice = (type(sel)=="table" and sel[1]) or sel
        settings.autoJoinMode = choice
        saveSettings(settings)

        if mapDD then mapDD:Destroy() end
        local maps = buildMapListForMode(choice)
        mapDD = mapLabel:Dropdown({
            Options = maps,
            Default = settings.autoJoinWorldName and { settings.autoJoinWorldName } or {},
            Multi = false,
            Placeholder = "--",
            Callback = function(sel2)
                local worldName = (type(sel2)=="table" and sel2[1]) or sel2
                settings.autoJoinWorldName = worldName
                saveSettings(settings)
                if chapDD then chapDD:Destroy() end
                local labels, mapLabelToKey = buildChapterOptions(worldName, settings.autoJoinMode)
                _G.__AJM_CHAPTERMAP = mapLabelToKey
                chapDD = chapLabel:Dropdown({
                    Options = labels,
                    Default = settings.autoJoinChapterLabel and { settings.autoJoinChapterLabel } or {},
                    Multi = false,
                    Placeholder = "--",
                    Callback = function(sel3)
                        local label = (type(sel3)=="table" and sel3[1]) or sel3
                        local raw = (_G.__AJM_CHAPTERMAP or {})[label] or label
                        settings.autoJoinChapterKey = raw
                        settings.autoJoinChapterLabel = label
                        saveSettings(settings)
                    end
                }, "AJM_CHAPTER")
            end
        }, "AJM_MAP")

        if chapDD then chapDD:Destroy() chapDD = nil end
        settings.autoJoinWorldName = nil
        settings.autoJoinChapterKey = nil
        settings.autoJoinChapterLabel = nil
    end
}, "AJM_MODE")

local initialMaps = buildMapListForMode(settings.autoJoinMode or "Story")
if #initialMaps > 0 then
    mapDD = mapLabel:Dropdown({
        Options = initialMaps,
        Default = settings.autoJoinWorldName and { settings.autoJoinWorldName } or {},
        Multi = false,
        Placeholder = "--",
        Callback = function(sel2)
            local worldName = (type(sel2)=="table" and sel2[1]) or sel2
            settings.autoJoinWorldName = worldName
            saveSettings(settings)

            if chapDD then chapDD:Destroy() end
            local labels, mapLabelToKey = buildChapterOptions(worldName, settings.autoJoinMode)
            _G.__AJM_CHAPTERMAP = mapLabelToKey
            chapDD = chapLabel:Dropdown({
                Options = labels,
                Default = settings.autoJoinChapterLabel and { settings.autoJoinChapterLabel } or {},
                Multi = false,
                Placeholder = "--",
                Callback = function(sel3)
                    local label = (type(sel3)=="table" and sel3[1]) or sel3
                    local raw = (_G.__AJM_CHAPTERMAP or {})[label] or label
                    settings.autoJoinChapterKey = raw
                    settings.autoJoinChapterLabel = label
                    saveSettings(settings)
                end
            }, "AJM_CHAPTER")
        end
    }, "AJM_MAP")

    if settings.autoJoinWorldName and settings.autoJoinChapterLabel then
        local labels, mapLabelToKey = buildChapterOptions(settings.autoJoinWorldName, settings.autoJoinMode)
        _G.__AJM_CHAPTERMAP = mapLabelToKey
        chapDD = chapLabel:Dropdown({
            Options = labels,
            Default = { settings.autoJoinChapterLabel },
            Multi = false,
            Placeholder = "--",
            Callback = function(sel3)
                local label = (type(sel3)=="table" and sel3[1]) or sel3
                local raw = (_G.__AJM_CHAPTERMAP or {})[label] or label
                settings.autoJoinChapterKey = raw
                settings.autoJoinChapterLabel = label
                saveSettings(settings)
            end
        }, "AJM_CHAPTER")
    end
end

gb:Toggle({
    Name = "Auto Join",
    Default = settings.autoJoinMap or false,
    Callback = function(v)
        settings.autoJoinMap = v
        saveSettings(settings)
        if v then task.spawn(AutoJoinMap) end
    end
}, "AJM_TOGGLE")


settings.autoJoinEventEnabled = settings.autoJoinEventEnabled or false
settings.autoJoinEventName    = settings.autoJoinEventName or ""


MainTab:Header({ Text = "Auto Join Event" })
local eventGB = MainTab:Section({ Side = "Right" })


eventGB:Header({ Text = "Select Event" })
local eventLabel = eventGB


local EVENT_ARG = {
    ["Boss Rush"]   = "BossRush",
    ["Rift Storm"]  = "RiftStorm",
    ["Swarm Event"] = "Swarm Event",
}


eventLabel:Dropdown({
    Options = { "Boss Rush", "Rift Storm", "Swarm Event" },
    Default = (settings.autoJoinEventName ~= "" and { settings.autoJoinEventName } or {}),
    Multi = false,
    Placeholder = "--",
    Callback = function(sel)
        local choice = (type(sel)=="table" and sel[1]) or sel
        settings.autoJoinEventName = choice or ""
        saveSettings(settings)
    end
}, "MAIN_EVENT_DD")



function AutoJoinEvent()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local PlayRoomEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")


    local EVENT_ARG = {
        ["Boss Rush"]   = "BossRush",
        ["Rift Storm"]  = "RiftStorm",
        ["Swarm Event"] = "Swarm Event",
    }

    task.spawn(function()
        while settings.autoJoinEventEnabled do
            if workspace:FindFirstChild("Lobby") then
                local displayName = settings.autoJoinEventName
                local arg1 = displayName and EVENT_ARG[displayName] or nil
                if arg1 then
                    pcall(function()

                        PlayRoomEvent:FireServer(arg1)
                        task.wait(0.4)

                        PlayRoomEvent:FireServer("Start")
                    end)


                    local hasSystemMessage = PlayerGui:FindFirstChild("SystemMessage")
                    if hasSystemMessage and hasSystemMessage.Enabled then
                        return
                    end
                    task.wait(1)
                end
            else
                task.wait(1)
            end
            task.wait(0.5)
        end
    end)
end



eventGB:Toggle({
    Name = "Auto Join",
    Default = settings.autoJoinEventEnabled,
    Callback = function(val)
        settings.autoJoinEventEnabled = val
        saveSettings(settings)
        if val then task.spawn(AutoJoinEvent) end
    end
}, "MAIN_EVENT_TOGGLE")

MainTab:Header({ Text = "Challenge" })
local challengeGB = MainTab:Section({ Side = "Right" })
challengeGB:Toggle({
    Name = "Auto Join Challenge",
    Default = settings.autoJoinChallenge or false,
    Callback = function(val)
        settings.autoJoinChallenge = val; saveSettings(settings)
        if val then
            task.spawn(function()
                local PlayRoomEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")
                while settings.autoJoinChallenge do
                    if workspace:FindFirstChild("Lobby") then
                        PlayRoomEvent:FireServer("Create", { CreateChallengeRoom = true })
                        task.wait(0.5)
                        PlayRoomEvent:FireServer("Start")
                    end
                    task.wait(3)
                end
            end)
        end
    end
}, "MAIN_AUTOCHALLENGE")
function AutoJoinHighCastle()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local PlayRoomEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")

    task.spawn(function()
        while settings.autoJoinInfinityCastle do
            if workspace:FindFirstChild("Lobby") then
                local pd = ReplicatedStorage:FindFirstChild("Player_Data")
                local clone = pd and pd:FindFirstChild(LocalPlayer.Name)
                local profile = clone and clone:FindFirstChild("Profile")
                local hic = profile and profile:FindFirstChild("HighestInfinityCastle")
                local highest = hic and hic.Value or 0
                if highest == 0 then
                    local args = {
                        [1] = "Infinity-Castle",
                        [2] = { ["Floor"] = 1 }
                    }
                    pcall(function()
                        PlayRoomEvent:FireServer(unpack(args))
                    end)
                    local hasSystemMessage = PlayerGui:FindFirstChild("SystemMessage")
                    if hasSystemMessage and hasSystemMessage.Enabled then
                        return
                    end

                    task.wait(1)
                end
            end
            task.wait(0.5)
        end
    end)
end
MainTab:Header({ Text = "Infinity Castle" })
local infGB = MainTab:Section({ Side = "Right" })
infGB:Toggle({
    Name = "Join Inf Castle",
    Default = settings.autoJoinInfinityCastle or false,
    Callback = function(val)
        settings.autoJoinInfinityCastle = val
        saveSettings(settings)
        if val then task.spawn(AutoJoinHighCastle) end
    end
}, "MAIN_JOININFK")

settings.gameSpeedValue = settings.gameSpeedValue or 2
settings.autoGameSpeedEnabled = settings.autoGameSpeedEnabled or false

AutoPlayTab:Header({ Text = "Auto Game Speed" })
local speedGB = AutoPlayTab:Section({ Side = "Left" })

local function triggerSpeed(val)
    val = tonumber(val) or 2
    local args = { [1] = val }
    local ok, err = pcall(function()
        game:GetService("ReplicatedStorage").Remote.SpeedGamepass:FireServer(unpack(args))
    end)
    if not ok then
        warn("[Auto Game Speed] FireServer failed:", err)
    end
end

local function autoSpeedLoop()
    while settings.autoGameSpeedEnabled do
        triggerSpeed(settings.gameSpeedValue or 2)
        task.wait(8)
    end
end

speedGB:Header({ Text = "Select speed" })
local speedLabel = speedGB

speedLabel:Dropdown({
    Options = { "2", "3" },
    Default = { tostring(settings.gameSpeedValue) },
    Multi = false,
    Placeholder = "--",
    Callback = function(sel)
        local choice = (type(sel) == "table" and sel[1]) or sel
        settings.gameSpeedValue = tonumber(choice) or 2
        saveSettings(settings)
        if settings.autoGameSpeedEnabled then
            triggerSpeed(settings.gameSpeedValue)
        end
    end
}, "AP_SPEED_DD")

speedGB:Toggle({
    Name = "Enable Auto Speed",
    Default = settings.autoGameSpeedEnabled,
    Callback = function(val)
        settings.autoGameSpeedEnabled = val
        saveSettings(settings)
        if val then
            task.spawn(autoSpeedLoop)
        end
    end
}, "AP_SPEED_TOGGLE")

if settings.autoGameSpeedEnabled then
    task.spawn(autoSpeedLoop)
end


AutoPlayTab:Header({ Text = "Auto Options" })
local apLeft = AutoPlayTab:Section({ Side = "Left" })

apLeft:Toggle({
    Name = "Auto Play",
    Default = settings.autoPlay,
    Callback = function(val)
        settings.autoPlay = val; saveSettings(settings)
        if val then startAutoPlayLoop() end
    end
}, "AP_AUTOPLAY")

apLeft:Toggle({
    Name = "Auto Upgrade",
    Default = settings.autoUpgrade,
    Callback = function(val)
        settings.autoUpgrade = val; saveSettings(settings)
        if val then startAutoUpgradeLoop() end
    end
}, "AP_AUTOUPGRADE")

apLeft:Toggle({
    Name = "Play After Upgrade",
    Default = settings.playAfterUpgrade,
    Callback = function(val) settings.playAfterUpgrade = val; saveSettings(settings) end
}, "AP_PLAYAFTERUPG")

AutoPlayTab:Header({ Text = "Place Slot" })
local placeGB = AutoPlayTab:Section({ Side = "Right" })
for i = 1, 6 do
    placeGB:Toggle({
        Name = ("Slot %d"):format(i),
        Default = settings.slots.place[i],
        Callback = function(val) settings.slots.place[i] = val; saveSettings(settings) end
    }, "AP_PLACE_"..i)
end

AutoPlayTab:Header({ Text = "Upgrade Slot" })
local upgGB = AutoPlayTab:Section({ Side = "Left" })
for i = 1, 6 do
    upgGB:Input({
        Name = ("Slot %d Target Level"):format(i),
        Default = tostring(settings.slots.upgrade[i] or 0),
        PlaceholderText = "0",
        Numeric = true,
        Callback = function(value)
            local num = tonumber(value) or 0
            settings.slots.upgrade[i] = num
            saveSettings(settings)
        end
    }, "AP_UPG_"..i)
end

settings.pathDeployEnabled = settings.pathDeployEnabled or false
settings.numPaths = settings.numPaths or 1
settings.slotPaths = settings.slotPaths or {0,0,0,0,0,0}

local function getManyWayPathNumber()
    local plr = game:GetService("Players").LocalPlayer
    local pg = plr:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    local inGame = hud and hud:FindFirstChild("InGame")
    local main = inGame and inGame:FindFirstChild("Main")
    local mws = main and main:FindFirstChild("ManyWaySelect")
    if not (mws and mws.Visible) then return nil end
    local frame = mws:FindFirstChild("Frame")
    local label = frame and frame:FindFirstChild("TextLabel")
    local text = label and label.Text or ""
    local n = tonumber(text:match("Path%s*(%d+)")) or tonumber(text:match("(%d+)"))
    return n
end

local function ensurePathSelected(pathNum, timeoutSec)
    local rs = game:GetService("ReplicatedStorage")
    local selWay = rs:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("Units"):WaitForChild("SelectWay")
    pcall(function() selWay:FireServer(pathNum, false) end)
    local t0 = tick()
    repeat task.wait(0.1)
    until getManyWayPathNumber() == pathNum or (tick()-t0) > (timeoutSec or 2)
end

local function isUnitAliveByName(unitName)
    local agent = workspace:FindFirstChild("Agent")
    local unitT = agent and agent:FindFirstChild("UnitT")
    if not unitT then return false end
    for _, obj in ipairs(unitT:GetChildren()) do
        local info = obj:FindFirstChild("Info")
        local nv = info and info:FindFirstChild("UnitName")
        if nv and nv.Value == unitName then
            return true
        end
    end
    return false
end

local function getSlotUnitGuiInfo(i)
    local plr = game:GetService("Players").LocalPlayer
    local slot = plr.PlayerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
    if not slot then return nil end
    local frame = slot:FindFirstChild("Frame")
    local unitFrame = frame and frame:FindFirstChild("UnitFrame")
    local info = unitFrame and unitFrame:FindFirstChild("Info")
    local folderObj = info and info:FindFirstChild("Folder")
    local costLabel = info and info:FindFirstChild("Cost")
    local cooled = frame and not frame:FindFirstChild("CD_FRAME")
    local unitObj = (folderObj and folderObj:IsA("ObjectValue")) and folderObj.Value or nil
    local unitName = unitObj and unitObj.Name or nil
    local costText = costLabel and costLabel.Text or ""
    local costNum = tonumber(costText:match("%d+")) or 0
    return {
        unitObj = unitObj, unitName = unitName,
        cost = costNum, cooled = cooled
    }
end

local function getCurrentYen()
    local ok, yen = pcall(function()
        return game.Players.LocalPlayer.PlayerGui.HUD.InGame.Main.Stats.Yen.YenValue.Value
    end)
    return ok and yen or 0
end


local function deploySlotWithPath(i)
    if not settings.slots.place[i] then return end
    local desiredPath = tonumber(settings.slotPaths[i] or 0) or 0
    if desiredPath <= 0 then return end
    if settings.numPaths and desiredPath > (tonumber(settings.numPaths) or 1) then return end


    local currentPath = getManyWayPathNumber()
    if not currentPath then return end

    local info = getSlotUnitGuiInfo(i)
    if not info or not info.unitObj or not info.unitName then return end


    if isUnitAliveByName(info.unitName) then return end


    if currentPath ~= desiredPath then
        ensurePathSelected(desiredPath, 2)
        currentPath = getManyWayPathNumber()
    end


    if currentPath ~= desiredPath then return end


    local yen = getCurrentYen()
    if info.cooled and yen >= (info.cost or 0) then
        pcall(function()
            game:GetService("ReplicatedStorage").Remote.Server.Units.Deployment:FireServer(info.unitObj)
        end)
    end
end


function deployUnitsWithPath()
    for i = 1, 6 do
        deploySlotWithPath(i)
        task.wait(1)
    end
end

AutoPlayTab:Header({ Text = "Deploy with Path" })
local pathGB = AutoPlayTab:Section({ Side = "Right" })

pathGB:Toggle({
    Name = "Enable",
    Default = settings.pathDeployEnabled,
    Callback = function(v)
        settings.pathDeployEnabled = v
        saveSettings(settings)
    end
}, "AP_DP_ENABLE")

pathGB:Input({
    Name = "Number of Paths",
    Default = tostring(settings.numPaths or 1),
    PlaceholderText = "1",
    Numeric = true,
    Callback = function(value)
        local n = math.max(1, tonumber(value) or 1)
        settings.numPaths = n
        saveSettings(settings)
    end
}, "AP_DP_NUMPATHS")


for i = 1, 6 do
    pathGB:Input({
        Name = ("Slot %d Path (0=off)"):format(i),
        Default = tostring(settings.slotPaths[i] or 0),
        PlaceholderText = "0",
        Numeric = true,
        Callback = function(v)
            local num = tonumber(v) or 0
            if num < 0 then num = 0 end
            settings.slotPaths[i] = num
            saveSettings(settings)
        end
    }, "AP_DP_SLOT_"..i)
end


WebhookTab:Header({ Text = "Webhook Settings" })
local whGB = WebhookTab:Section({ Side = "Left" })
whGB:Input({
    Name = "Webhook URL",
    Default = settings.webhookURL or "",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    Callback = function(value) settings.webhookURL = value; saveSettings(settings) end
}, "WH_URL")

whGB:Toggle({
    Name = "Send Result Webhook",
    Default = settings.webhookEnabled,
    Callback = function(val) settings.webhookEnabled = val; saveSettings(settings) end
}, "WH_ENABLE")

whGB:Button({
    Name = "Test Webhook",
    Callback = function() sendWebhook() end
}, "WH_TEST")

ShopTab:Header({ Text = "Auto Tier (Rare)" })
local rareGB = ShopTab:Section({ Side = "Left" })
rareGB:Toggle({
    Name = "Auto Evolve Tier (Rare)",
    Default = settings.autoEvolveRare,
    Callback = function(val)
        settings.autoEvolveRare = val; saveSettings(settings)
        if val then evolveRareUnits() end
    end
}, "SHOP_AUTORARE")

ShopTab:Header({ Text = "Summon" })
local summonGB = ShopTab:Section({ Side = "Left" })

summonGB:Header({ Text = "Select Banner" })
local bannerLabel = summonGB
bannerLabel:Dropdown({
    Options = {"Standard", "Rateup"},
    Default = {settings.selectBanner or "Standard"},
    Multi = false,
    Placeholder = "--",
    Callback = function(opts)
        local choice = (type(opts) == "table" and opts[1]) or opts
        settings.selectBanner = choice or "Standard"
        saveSettings(settings)
    end
}, "SHOP_BANNER")

summonGB:Header({ Text = "Select Auto Sell" })
local autosellLabel = summonGB
autosellLabel:Dropdown({
    Options = { "Rare", "Epic", "Legendary", "Shiny" },
    Default = (function()
        local t = {}
        for k,v in pairs(settings.autoSellTiers or {}) do if v == true then table.insert(t, k) end end
        if #t == 0 and type(settings.autoSellTiers) == "table" then
            for _,k in ipairs(settings.autoSellTiers) do table.insert(t, k) end
        end
        return t
    end)(),
    Multi = true,
    Placeholder = "None",
    Callback = function(opts)
        settings.autoSellTiers = {}
        for _,v in ipairs(opts) do table.insert(settings.autoSellTiers, v) end
        saveSettings(settings)
    end
}, "SHOP_AUTOSELL")

summonGB:Toggle({
    Name = "Auto Summon x10",
    Default = settings.autoSummonX10 or false,
    Callback = function(val)
        settings.autoSummonX10 = val
        saveSettings(settings)
        if val then autoSummonX10Loop() end
    end
}, "SHOP_SUMMON10")

summonGB:Toggle({
    Name = "Auto Summon x1",
    Default = settings.autoSummonX1 or false,
    Callback = function(val)
        settings.autoSummonX1 = val
        saveSettings(settings)
        if val then autoSummonX1Loop() end
    end
}, "SHOP_SUMMON1")

ShopTab:Header({ Text = "Stats" })
local statsGB = ShopTab:Section({ Side = "Right" })

statsGB:Header({ Text = "Select Potential" })
local potentialsLabel = statsGB
potentialsLabel:Dropdown({
    Options = { "Damage", "Health", "Speed", "Range", "AttackCooldown" },
    Default = settings.selectPotential or {},
    Multi = true,
    Placeholder = "None",
    Callback = function(opts) settings.selectPotential = opts; saveSettings(settings) end
}, "SHOP_POTENTIAL")

statsGB:Header({ Text = "Select Grades" })
local statsLabel = statsGB
statsLabel:Dropdown({
    Options = { "S", "SS", "SSS", "O-", "O", "O+" },
    Default = settings.selectStats or {},
    Multi = true,
    Placeholder = "None",
    Callback = function(opts) settings.selectStats = opts; saveSettings(settings) end
}, "SHOP_STATGRADES")

statsGB:Header({ Text = "Select Unit" })
local unitLabel = statsGB
unitLabel:Dropdown({
    Options = (function()
        local rs  = game:GetService("ReplicatedStorage")
        local plr = game:GetService("Players").LocalPlayer
        local col = rs:WaitForChild("Player_Data"):WaitForChild(plr.Name):WaitForChild("Collection")
        local names = {}
        for _, folder in ipairs(col:GetChildren()) do
            local lvlNV = folder:FindFirstChild("Level")
            local lvl = (lvlNV and lvlNV.Value) or 0
            table.insert(names, string.format("%s [%d]", folder.Name, lvl))
        end
        table.sort(names)
        return names
    end)(),
    Default = { settings.selectUnit or "" },
    Multi = false,
    Placeholder = "--",
    Callback = function(opts)
        local choice = (type(opts) == "table" and opts[1]) or opts
        settings.selectUnit = choice or ""
        saveSettings(settings)
    end
}, "SHOP_UNIT")
startRollToggle = statsGB:Toggle({
    Name = "Start Potential Reroll",
    Default = settings.startRoll or false,
    Callback = function(val)
        settings.startRoll = val; saveSettings(settings)
        if val then if not isRolling then isRolling = true; coroutine.wrap(autoRoll)() end else isRolling = false end
    end
}, "SHOP_STARTROLL")

ShopTab:Header({ Text = "Trait Reroll" })
local trailGB = ShopTab:Section({ Side = "Right" })

trailGB:Header({ Text = "Select Unit" })
local trailUnitLabel = trailGB
trailUnitLabel:Dropdown({
    Options = (function()
        local rs = game:GetService("ReplicatedStorage")
        local plr = game:GetService("Players").LocalPlayer
        local collection = rs:WaitForChild("Player_Data"):WaitForChild(plr.Name):WaitForChild("Collection")
        local unitList = {}
        for _, unit in ipairs(collection:GetChildren()) do
            local levelVal = unit:FindFirstChild("Level")
            local label = unit.Name
            if levelVal then label = label .. " [" .. levelVal.Value .. "]" end
            table.insert(unitList, label)
        end
        table.sort(unitList)
        return unitList
    end)(),
    Default = rerollConfig.unit and {rerollConfig.unit} or {},
    Multi = false,
    Placeholder = "--",
    Callback = function(opts)
        local choice = (type(opts) == "table" and opts[1]) or opts
        rerollConfig.unit = choice
    end
}, "SHOP_TRAIL_UNIT")

trailGB:Header({ Text = "Select Trait" })
local trailLabel = trailGB
trailLabel:Dropdown({
    Options = { "Blitz", "Juggernaut", "Millionaire", "Violent", "Seraph", "Capitalist", "Duplicator", "Sovereign" },
    Default = {},
    Multi = true,
    Placeholder = "None",
    Callback = function(selected) rerollConfig.trail = selected end
}, "SHOP_TRAIL_PICK")

trailGB:Toggle({
    Name = "Start Trait Reroll",
    Default = false,
    Callback = function(val)
        rerollConfig.start = val
        if val and rerollConfig.unit and rerollConfig.trail and #rerollConfig.trail > 0 then
            coroutine.wrap(function() autoRollTrail(rerollConfig.unit, rerollConfig.trail) end)()
        end
    end
}, "SHOP_TRAIL_START")


PortalTab:Header({ Text = "Portal Helper" })
local portalGB = PortalTab:Section({ Side = "Left" })
portalGB:Toggle({
    Name = "Auto Click Portal",
    Default = settings.autoPortal or false,
    Callback = function(val)
        settings.autoPortal = val; saveSettings(settings)
        if val then task.spawn(autoPortalFunc) end
    end
}, "PORTAL_CLICK")

PortalTab:Header({ Text = "Auto Join Portal" })
local portalJoinGB = PortalTab:Section({ Side = "Left" })

local function buildPortalOptions()
    local opts = {}
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local pd = ReplicatedStorage:FindFirstChild("Player_Data")
    local clone = pd and pd:FindFirstChild(LocalPlayer.Name)
    local items = clone and clone:FindFirstChild("Items")
    if not items then return opts end

    for _, child in ipairs(items:GetChildren()) do
        if child:IsA("Folder") and string.find(string.lower(child.Name), "portal", 1, true) then
            local amount = child:FindFirstChild("Amount")
            if amount and amount:IsA("NumberValue") and amount.Value > 0 then
                table.insert(opts, child.Name)
            end
        end
    end

    table.sort(opts)
    return opts
end

portalJoinGB:Header({ Text = "Select Portal" })
local portalLabel = portalJoinGB

local portalDD

local function renderPortalDropdown()
    if portalDD then portalDD:Destroy() end
    local opts = buildPortalOptions()

    portalDD = portalLabel:Dropdown({
        Options = opts,
        Default = settings.selectedPortals or {},
        Multi = true,
        Placeholder = "None",
        Callback = function(selected)
            settings.selectedPortals = selected
            saveSettings(settings)
        end
    }, "PORTAL_SELECT")
end
renderPortalDropdown()

task.spawn(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local pd = ReplicatedStorage:WaitForChild("Player_Data")
    local clone = pd:WaitForChild(LocalPlayer.Name)
    local items = clone:WaitForChild("Items")
    items.ChildAdded:Connect(renderPortalDropdown)
    items.ChildRemoved:Connect(renderPortalDropdown)

    local function watchFolder(folder)
        if folder:IsA("Folder") and string.find(string.lower(folder.Name), "portal", 1, true) then
            local amt = folder:FindFirstChild("Amount")
            if amt and amt:IsA("NumberValue") then
                amt:GetPropertyChangedSignal("Value"):Connect(function()
                    renderPortalDropdown()
                end)
            end
        end
    end
    for _, f in ipairs(items:GetChildren()) do watchFolder(f) end
    items.ChildAdded:Connect(watchFolder)
end)

portalJoinGB:Toggle({
    Name = "Auto Join",
    Default = settings.autoJoinPortal or false,
    Callback = function(val)
        settings.autoJoinPortal = val; saveSettings(settings)
        if val then task.spawn(autoJoinPortalLoop) end
    end
}, "PORTAL_AUTOJOIN")








settings.autoFarmEnabled = settings.autoFarmEnabled or false
settings.autoFarmTarget  = tonumber(settings.autoFarmTarget or 1) or 1
settings.autoFarmGear    = settings.autoFarmGear or ""

local CRAFT_URL = "https://cdn.shouko.dev/RokidManager/neyoshiiuem/main/craft.txt"
local LOBBY_PLACE_ID = 72829404259339

local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TeleportService   = game:GetService("TeleportService")
local LocalPlayer       = Players.LocalPlayer


local function getGoldNumber()
    local pd = ReplicatedStorage:FindFirstChild("Player_Data")
    local me = pd and pd:FindFirstChild(LocalPlayer.Name)
    local dataFolder = me and me:FindFirstChild("Data")
    local goldValue = dataFolder and dataFolder:FindFirstChild("Gold")
    return (goldValue and goldValue:IsA("NumberValue") and goldValue.Value) or 0
end


local function stripTags(s)
    if type(s) ~= "string" then return s end
    return s:gsub("<.->", ""):gsub("%s+%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
end


local __CRAFT, __GEAR_INDEX
local function loadCraftData()
    local ok, raw = pcall(function() return game:HttpGet(CRAFT_URL) end)
    if not ok then return {} end
    local ok2, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    return ok2 and parsed or {}
end
local function ensureCraftLoaded()
    if __CRAFT then return end
    __CRAFT = loadCraftData()
    __GEAR_INDEX = {}
    for _, item in ipairs(__CRAFT) do
        local n = stripTags(item.Name or "")
        if n ~= "" then __GEAR_INDEX[n] = item end
    end
end
local function getCraftInfo(gearName)
    ensureCraftLoaded()
    local entry = __GEAR_INDEX[gearName]
    if not entry then return nil end
    local price = entry.Price or 0

    return { price = price, req = entry.Requirement or {} }
end
local function buildGearList()
    ensureCraftLoaded()
    local names = {}
    for _, item in ipairs(__CRAFT) do
        local n = stripTags(item.Name or "")
        if n and n ~= "" then table.insert(names, n) end
    end
    table.sort(names)
    return names
end


local function getItemsFolder()
    local pd = ReplicatedStorage:FindFirstChild("Player_Data")
    local me = pd and pd:FindFirstChild(LocalPlayer.Name)
    return me and me:FindFirstChild("Items") or nil
end
local function getItemAmount(items, itemName)
    local f = items and items:FindFirstChild(itemName)
    local nv = f and f:FindFirstChild("Amount")
    return (nv and nv:IsA("NumberValue") and nv.Value) or 0
end


local function extractWorldAndChapter(worldStr)
    if type(worldStr) ~= "string" or worldStr == "" then return nil, nil end
    local underscore = string.find(worldStr, "_")
    local worldKey = underscore and string.sub(worldStr, 1, underscore - 1) or worldStr
    local chapterKey = worldStr
    return worldKey, chapterKey
end


local function joinMapWithWorldString(worldStr)
    local worldKey, chapterKey = extractWorldAndChapter(worldStr)
    if not worldKey or not chapterKey then return end
    local Remote = ReplicatedStorage:WaitForChild("Remote")
    local Server = Remote:WaitForChild("Server")
    local PlayRoomEvent = Server:WaitForChild("PlayRoom"):WaitForChild("Event")
    pcall(function()
        PlayRoomEvent:FireServer("Create")
        PlayRoomEvent:FireServer("Change-Mode",    { Mode = "Ranger Stage" })
        PlayRoomEvent:FireServer("Change-World",   { World = worldKey })
        PlayRoomEvent:FireServer("Change-Chapter", { Chapter = chapterKey })
        PlayRoomEvent:FireServer("Submit")
        PlayRoomEvent:FireServer("Start")
    end)
end


local function craftOnce(gearName)
    local args = { [1] = gearName, [2] = "1", [3] = "1" }
    pcall(function()
        ReplicatedStorage.Remote.Server.Crafting.Event:FireServer(unpack(args))
    end)
end


local function inLobby()
    return workspace:FindFirstChild("Lobby") ~= nil
end


local __TP_PENDING = false
local function teleportToLobby()
    if __TP_PENDING then return end
    __TP_PENDING = true
    task.spawn(function()
        pcall(function()
            TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
        end)
        task.wait(3)
        __TP_PENDING = false
    end)
end



local __LAST_IN_LOBBY = nil
local __MAP_MISSING_SNAPSHOT = nil




local __AF_RUNNING = false
local function autoFarmLoop()
    if __AF_RUNNING then return end
    __AF_RUNNING = true

    while settings.autoFarmEnabled do
        local gearName = settings.autoFarmGear or ""
        local target   = tonumber(settings.autoFarmTarget or 1) or 1

        local nowInLobby = inLobby()

        if __LAST_IN_LOBBY ~= nil and __LAST_IN_LOBBY == true and nowInLobby == false then
            __MAP_MISSING_SNAPSHOT = nil
        end

        if __LAST_IN_LOBBY ~= nil and __LAST_IN_LOBBY == false and nowInLobby == true then
            __MAP_MISSING_SNAPSHOT = nil
        end
        __LAST_IN_LOBBY = nowInLobby

        if gearName == "" or target <= 0 then
            task.wait(0.4)
            goto continue
        end

        local info = getCraftInfo(gearName)
        if not info then
            warn("[AutoFarm] Gear not found in craft.json:", gearName)
            task.wait(0.8)
            goto continue
        end

        local items = getItemsFolder()
        if not items then
            task.wait(0.6)
            goto continue
        end

        if nowInLobby then


            __MAP_MISSING_SNAPSHOT = nil

            local haveGear = getItemAmount(items, gearName)
            if haveGear >= target then
                task.wait(0.8)
                goto continue
            end


            local chosenWorldStr
            local anyMissing = false
            for reqName, v in pairs(info.req) do
                local need = (type(v)=="table") and (tonumber(v.Amount) or 0) or (tonumber(v) or 0)
                local worldStr = (type(v)=="table") and v.World or nil
                if need > 0 and getItemAmount(items, reqName) < need then
                    anyMissing = true
                    if not chosenWorldStr then
                        chosenWorldStr = worldStr
                    end
                end
            end

            if anyMissing and chosenWorldStr and chosenWorldStr ~= "" then
                joinMapWithWorldString(chosenWorldStr)
                task.wait(1.0)
            else

                if getGoldNumber() >= (tonumber(info.price or 0) or 0) then
                    craftOnce(gearName)
                    task.wait(0.5)
                else
                    task.wait(1.0)
                end
            end

        else


            if not __MAP_MISSING_SNAPSHOT then
                __MAP_MISSING_SNAPSHOT = {}
                for reqName, v in pairs(info.req) do
                    local need = (type(v)=="table") and (tonumber(v.Amount) or 0) or (tonumber(v) or 0)
                    if need > 0 then
                        local have = getItemAmount(items, reqName)
                        if have < need then

                            __MAP_MISSING_SNAPSHOT[reqName] = need
                        end
                    end
                end

                if next(__MAP_MISSING_SNAPSHOT) == nil then
                    teleportToLobby()
                    task.wait(0.6)
                    goto continue
                end
            end


            for reqName, need in pairs(__MAP_MISSING_SNAPSHOT) do
                local have = getItemAmount(items, reqName)
                if have >= (tonumber(need) or 0) then
                    teleportToLobby()
                    break
                end
            end

            task.wait(0.4)
        end

        ::continue::
        task.wait(0.15)
    end

    __AF_RUNNING = false
end



local AutoFarmTab = RootSection:Tab({ Name = "Auto Farm", Icon = NebulaIcons:GetIcon('factory','Lucide'), Columns = 2 })

AutoFarmTab:Header({ Text = "Auto Farm" })
local afGB = AutoFarmTab:Section({ Side = "Left" })

afGB:Header({ Text = "Select Gear" })
local gearLabel = afGB
gearLabel:Dropdown({
    Options = (function()
        local ok, list = pcall(buildGearList)
        return ok and list or {}
    end)(),
    Default = (settings.autoFarmGear ~= "" and { settings.autoFarmGear } or {}),
    Multi = false,
    Placeholder = "--",
    Callback = function(sel)
        local choice = (type(sel)=="table" and sel[1]) or sel
        settings.autoFarmGear = choice or ""
        saveSettings(settings)
    end
}, "AF_GEAR_DD")

afGB:Input({
    Name = "Input Amount",
    Default = tostring(settings.autoFarmTarget or 1),
    PlaceholderText = "1",
    Numeric = true,
    Callback = function(v)
        local n = math.max(1, tonumber(v) or 1)
        settings.autoFarmTarget = n
        saveSettings(settings)
    end
}, "AF_AMOUNT")

afGB:Toggle({
    Name = "Toggle Auto Get Gear",
    Default = settings.autoFarmEnabled or false,
    Callback = function(val)
        settings.autoFarmEnabled = val
        saveSettings(settings)
        if val then task.spawn(autoFarmLoop) end
    end
}, "AF_TOGGLE")
