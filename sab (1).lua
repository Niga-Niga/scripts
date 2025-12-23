repeat wait() until game:IsLoaded()


local player = game:GetService("Players").LocalPlayer
local vu = game:GetService("VirtualUser")
player.Idled:connect(function()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
    vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    wait(1)
    vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

pcall(function()
    getconnections(player.Idled)[1]:Disable()
end)


local startTime = tick()

local cancelCollectFlag = false
local pathfindToken = 0
local currentTween = nil

local function waitForCharacter()
    if not game.Players.LocalPlayer.Character or not game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        game.Players.LocalPlayer.CharacterAdded:Wait()
        game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
    end
end

local TaskManager = {
    currentTask = nil,
    taskQueue = {},
    pausedTasks = {},
    priorities = {
        LOCK = 1,
        SELL = 2,
        BUY = 3,
        OPEN = 4,
        COLLECT = 5,
        WAIT = 6
    },
    isProcessing = false,
    taskLock = false
}

local function createTask(taskType, priority, action, data)
    return {
        type = taskType,
        priority = priority,
        action = action,
        data = data or {},
        cancelled = false
    }
end

local function isDuplicateTask(newTask)
    if TaskManager.currentTask and TaskManager.currentTask.type == newTask.type then
        if newTask.type == "BUY" and TaskManager.currentTask.data.Info and newTask.data.Info then
            if TaskManager.currentTask.data.Info.Name == newTask.data.Info.Name and
                TaskManager.currentTask.data.Info.Price == newTask.data.Info.Price then
                return true
            end
        elseif newTask.type == TaskManager.currentTask.type and newTask.action == TaskManager.currentTask.action then
            if newTask.type == "COLLECT" or newTask.type == "WAIT" or newTask.type == "LOCK" or newTask.type == "SELL" or newTask.type == "OPEN" then
                return true
            end
        end
    end

    for _, task in pairs(TaskManager.taskQueue) do
        if task.type == newTask.type then
            if newTask.type == "BUY" and task.data.Info and newTask.data.Info then
                if task.data.Info.Name == newTask.data.Info.Name and
                    task.data.Info.Price == newTask.data.Info.Price then
                    return true
                end
            elseif newTask.type == task.type and newTask.action == task.action then
                if newTask.type == "COLLECT" or newTask.type == "WAIT" or newTask.type == "LOCK" or newTask.type == "SELL" or newTask.type == "OPEN" then
                    return true
                end
            end
        end
    end

    for _, task in pairs(TaskManager.pausedTasks) do
        if task.type == newTask.type then
            if newTask.type == "BUY" and task.data.Info and newTask.data.Info then
                if task.data.Info.Name == newTask.data.Info.Name and
                    task.data.Info.Price == newTask.data.Info.Price then
                    return true
                end
            elseif newTask.type == task.type and newTask.action == task.action then
                if newTask.type == "COLLECT" or newTask.type == "WAIT" or newTask.type == "LOCK" or newTask.type == "SELL" or newTask.type == "OPEN" then
                    return true
                end
            end
        end
    end

    return false
end

local function addTask(task)
    if isDuplicateTask(task) then
        return false
    end

    table.insert(TaskManager.taskQueue, task)
    table.sort(TaskManager.taskQueue, function(a, b)
        if a.priority == b.priority and a.type == "BUY" and b.type == "BUY" then
            local aPriority = a.data.buyPriority or 0
            local bPriority = b.data.buyPriority or 0
            return aPriority > bPriority
        end
        return a.priority < b.priority
    end)
    return true
end

local function cancelTasks(taskType)
    if TaskManager.currentTask and TaskManager.currentTask.type == taskType then
        TaskManager.currentTask.cancelled = true
        cancelCollectFlag = true
        pathfindToken = pathfindToken + 1
        if currentTween then
            currentTween:Cancel()
        end
    end

    for i = #TaskManager.taskQueue, 1, -1 do
        if TaskManager.taskQueue[i].type == taskType then
            table.remove(TaskManager.taskQueue, i)
        end
    end
end

local function pauseBuyTasks()
    if TaskManager.currentTask and TaskManager.currentTask.type == "BUY" then
        TaskManager.currentTask.cancelled = true
        cancelCollectFlag = true
        pathfindToken = pathfindToken + 1
        if currentTween then
            currentTween:Cancel()
        end
        TaskManager.currentTask.cancelled = false
        table.insert(TaskManager.pausedTasks, TaskManager.currentTask)
        TaskManager.currentTask = nil
    end

    for i = #TaskManager.taskQueue, 1, -1 do
        if TaskManager.taskQueue[i].type == "BUY" then
            local task = table.remove(TaskManager.taskQueue, i)
            task.cancelled = false
            table.insert(TaskManager.pausedTasks, task)
        end
    end
end

local function resumeBuyTasks()
    local tasksToResume = {}

    for i = #TaskManager.pausedTasks, 1, -1 do
        local task = TaskManager.pausedTasks[i]
        if task.type == "BUY" then
            table.remove(TaskManager.pausedTasks, i)
            task.cancelled = false
            table.insert(tasksToResume, task)
        end
    end

    for _, task in pairs(tasksToResume) do
        if not isDuplicateTask(task) then
            table.insert(TaskManager.taskQueue, task)
        end
    end

    table.sort(TaskManager.taskQueue, function(a, b)
        if a.priority == b.priority and a.type == "BUY" and b.type == "BUY" then
            local aPriority = a.data.buyPriority or 0
            local bPriority = b.data.buyPriority or 0
            return aPriority > bPriority
        end
        return a.priority < b.priority
    end)
end

local function getNextTask()
    if #TaskManager.taskQueue > 0 then
        return table.remove(TaskManager.taskQueue, 1)
    end
    return nil
end

local function getQueueStatus()
    local status = {}
    local taskCounts = {}

    for _, task in pairs(TaskManager.taskQueue) do
        taskCounts[task.type] = (taskCounts[task.type] or 0) + 1
    end

    local pausedCounts = {}
    for _, task in pairs(TaskManager.pausedTasks) do
        pausedCounts[task.type] = (pausedCounts[task.type] or 0) + 1
    end

    return taskCounts, pausedCounts
end

local function processTasks()
    spawn(function()
        if not TaskManager.isProcessing and not TaskManager.taskLock and #TaskManager.taskQueue > 0 then
            TaskManager.isProcessing = true
            TaskManager.taskLock = true
            local task = getNextTask()
            if task and not task.cancelled then
                TaskManager.currentTask = task
                task.action(task.data)
                TaskManager.currentTask = nil
            end
            TaskManager.isProcessing = false
            TaskManager.taskLock = false

            if #TaskManager.taskQueue > 0 then
                processTasks()
            end
        end
    end)
end

function getBase()
    for i, v in pairs(workspace.Plots:GetDescendants()) do
        if v.Name == "YourBase" and v.Enabled then
            return v.Parent.Parent
        end
    end
    return false
end

local Base = getBase()

function getSlots()
    local base = getBase()
    if base then
        local animalPodiums = base:WaitForChild("AnimalPodiums", 5)

        if animalPodiums then
            return #animalPodiums:GetChildren()
        end
    end
    return 0
end

local function d(v)
    pcall(function()
        waitForCharacter()
        if v:IsA("BasePart") or v:IsA("Part") or v:IsA("MeshPart") then
            v.Transparency = 1
            if v:FindFirstChildOfClass("Decal") then for _, v in ipairs(v:GetChildren()) do if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end end end
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("Sound") then
            v.Volume = 0
            v.Playing = false
        elseif v:IsA("ParticleEmitter") or v:IsA("Beam") then
            v.Enabled = false
        elseif v:IsA("ScreenGui") or v:IsA("Frame") or v:IsA("Clouds") then
            v.Enabled = false
        elseif v.Name and v.Name:find("Effect") then
            v.Enabled = false
        end
    end)
end


getgenv().cfg = getgenv().cfg or {}
getgenv().cfg["Settings"] = getgenv().cfg["Settings"] or {}
getgenv().cfg["Important Brainrot"] = getgenv().cfg["Important Brainrot"] or {}
if getgenv().cfg["Settings"]["BoostFPS"] then
    for _, vq in ipairs({ workspace, game.Lighting, game.ReplicatedStorage, game.ReplicatedFirst, game.Players.LocalPlayer.PlayerScripts, game.Players.LocalPlayer.Character, game.Players.LocalPlayer.Backpack }) do
        waitForCharacter()
        local a = vq:GetDescendants()
        for i = 1, #a do d(a[i]) end
        vq.DescendantAdded:Connect(function(v) task.defer(d, v) end)
    end
end

local l_Shared_0 = game:GetService("ReplicatedStorage"):WaitForChild("Shared");
local v1 = require(l_Shared_0.Updates);
local Animals = require(game:GetService("ReplicatedStorage").Datas.Animals)
local RebirthData = require(game:GetService("ReplicatedStorage").Datas.Rebirth)
local Synchronizer = require(game:GetService("ReplicatedStorage").Packages.Synchronizer)
local CurrentRebirths = game:GetService("Players").LocalPlayer.leaderstats.Rebirths.Value
local CurrentCash = game:GetService("Players").LocalPlayer.leaderstats.Cash.Value
game:GetService("Players").LocalPlayer.leaderstats.Rebirths.Changed:Connect(function()
    CurrentRebirths = game:GetService("Players").LocalPlayer.leaderstats.Rebirths.Value
end)
game:GetService("Players").LocalPlayer.leaderstats.Cash.Changed:Connect(function()
    CurrentCash = game:GetService("Players").LocalPlayer.leaderstats.Cash.Value
end)


local function getTPTime(inputCFrame, fromCFrame)
    inputCFrame = type(inputCFrame) == "vector" and CFrame.new(inputCFrame) or inputCFrame

    if not fromCFrame then
        waitForCharacter()
        if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            fromCFrame = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame
        else
            return 1
        end
    end

    fromCFrame = type(fromCFrame) == "vector" and CFrame.new(fromCFrame) or fromCFrame
    return (inputCFrame.Position - fromCFrame.Position).Magnitude / 20
end


local function getNearestCarpetCFrame(inputCFrame)
    local CarpetCFrame = CFrame.new(-410.752014, -9.75000381, 59.4064789)
    local CarpetSize = Vector3.new(20, 0.5, 401)

    local Distance = (inputCFrame.Position - CarpetCFrame.Position).Magnitude
    local relativePos = CarpetCFrame:PointToObjectSpace(inputCFrame.Position)

    local fixedX = 0
    local clampedY = math.clamp(relativePos.Y, -CarpetSize.Y / 2, CarpetSize.Y / 2)
    local clampedZ = math.clamp(relativePos.Z, -CarpetSize.Z / 2, CarpetSize.Z / 2)

    local nearestMiddlePoint = CarpetCFrame:PointToWorldSpace(Vector3.new(fixedX, clampedY, clampedZ))
    nearestMiddlePoint = nearestMiddlePoint + Vector3.new(0, 3, 0)

    return nearestMiddlePoint
end


local val = nil

local function Tween(Pos, Time)
    waitForCharacter()
    local character = game.Players.LocalPlayer.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")

    if not humanoidRootPart or not humanoid then
        return
    end

    Pos = type(Pos) == "vector" and CFrame.new(Pos) or Pos
    if currentTween then
        currentTween:Cancel()
    end
    if val then
        val:Destroy()
        val = nil
    end
    val = Instance.new("CFrameValue")
    val.Value = humanoidRootPart.CFrame

    local tween = game:GetService("TweenService"):Create(
        val,
        TweenInfo.new((humanoidRootPart.Position - Pos.p).magnitude / getgenv().cfg.Settings["Speed"],
            Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0),
        { Value = Pos }
    )

    currentTween = tween
    tween:Play()
    local completed = false
    local connection

    connection = tween.Completed:Connect(function()
        completed = true
        if connection then
            connection:Disconnect()
            connection = nil
        end
    end)

    while not completed do
        waitForCharacter()
        character = game.Players.LocalPlayer.Character
        humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        humanoid = character and character:FindFirstChild("Humanoid")

        if not humanoidRootPart or not humanoid then
            if connection then
                connection:Disconnect()
                connection = nil
            end
            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end
            if val then
                val:Destroy()
                val = nil
            end
            return
        end

        if humanoid.Sit == true then
            humanoid.Sit = false
        end
        if val then
            humanoidRootPart.CFrame = val.Value
        end
        task.wait()
    end

    currentTween = nil
    if val then
        val:Destroy()
        val = nil
    end
end




local function ExtractNumber(input)
    if not input then return 0 end

    if type(input) == "number" then
        return math.floor(input)
    end

    local numberPart, suffix = string.match(input, "%$?(%d+%.?%d*)(%a*)")
    if numberPart then
        local num = tonumber(numberPart)
        if not num then return nil end

        local multipliers = {
            [""] = 1,
            K    = 1e3,
            M    = 1e6,
            B    = 1e9,
            T    = 1e12,
            Qa   = 1e15,
            Qi   = 1e18,
            Sx   = 1e21,
            Sp   = 1e24,
            Oc   = 1e27,
            No   = 1e30,
            Dc   = 1e33,
        }

        return math.floor(num * (multipliers[suffix] or 1))
    end

    local rawInt = tonumber(input)
    if rawInt then
        return math.floor(rawInt)
    end

    return nil
end

local heightFromLeg = 0

local function updateHeightFromLeg()
    local character = game.Players.LocalPlayer.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local leg = character:FindFirstChild("LeftLeg") or character:FindFirstChild("LeftFoot")

        if humanoidRootPart and leg then
            heightFromLeg = humanoidRootPart.Position.Y - leg.Position.Y
        else
            heightFromLeg = 0
        end
    end
end

game.Players.LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")

    cancelTasks("COLLECT")
    cancelTasks("BUY")
    cancelTasks("SELL")
    cancelTasks("LOCK")
end)

updateHeightFromLeg()


local function PathfindTo(destination)
    waitForCharacter()
    pathfindToken = pathfindToken + 1
    local myToken = pathfindToken
    destination = type(destination) == 'userdata' and destination.Position
        or destination

    local character = game.Players.LocalPlayer.Character
    local humanoidRootPart = character
        and character:FindFirstChild('HumanoidRootPart')
    local humanoid = character and character:FindFirstChild('Humanoid')

    if not humanoidRootPart or not humanoid then
        return
    end

    local path = game:GetService('PathfindingService'):CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4,
    })

    local success, err = pcall(function()
        path:ComputeAsync(humanoidRootPart.Position, destination)
    end)

    if not success then
        warn(err)
        return
    end

    if
        path.Status == Enum.PathStatus.Success
        or path.Status == Enum.PathStatus.ClosestNoPath
        or path.Status == Enum.PathStatus.ClosestOutOfRange
    then
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if myToken ~= pathfindToken then
                return
            end

            character = game.Players.LocalPlayer.Character
            humanoidRootPart = character
                and character:FindFirstChild('HumanoidRootPart')
            humanoid = character and character:FindFirstChild('Humanoid')

            if not humanoidRootPart or not humanoid then
                return
            end

            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end

            local pos = waypoint.Position
            humanoid:MoveTo(pos)

            local moveFinished = false
            local connection
            connection = humanoid.MoveToFinished:Connect(function(reached)
                moveFinished = true
                connection:Disconnect()
            end)

            local startTime = tick()
            local lastPosition = humanoidRootPart.Position

            while not moveFinished and tick() - startTime < 5 do
                if myToken ~= pathfindToken then
                    if connection then
                        connection:Disconnect()
                    end
                    return
                end

                local currentPos = humanoidRootPart.Position
                local distance = (currentPos - pos).Magnitude

                if distance < 3 then
                    break
                end

                if (currentPos - lastPosition).Magnitude < 0.1 then
                    if tick() - startTime > 1 then
                        break
                    end
                else
                    lastPosition = currentPos
                end

                task.wait(0.1)
            end

            if connection then
                connection:Disconnect()
            end
        end
    end
end


local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local onPathfind = false
local function PathfindTo2(destination)
    waitForCharacter()
    destination = type(destination) == "userdata" and destination.Position or destination

    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not humanoidRootPart then
        warn("PathfindTo: Humanoid or HumanoidRootPart not found.")
        return
    end


    local path = PathfindingService:CreatePath({
        AgentRadius = 4,
        AgentHeight = 6,
        AgentCanJump = true,
        AgentCanClimb = true,
    })


    local success, err = pcall(function()
        path:ComputeAsync(humanoidRootPart.Position, destination)
    end)

    if not success then
        warn("PathfindTo failed to compute path:", err)
        onPathfind = false
        return
    end

    pathfindToken = pathfindToken + 1
    local myToken = pathfindToken
    onPathfind = true

    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()

        task.spawn(function()
            local ok, threadErr = pcall(function()
                for i = 2, #waypoints do
                    local waypoint = waypoints[i]

                    if myToken ~= pathfindToken then
                        return
                    end


                    local currentHumanoid = Players.LocalPlayer.Character and
                    Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if not currentHumanoid or currentHumanoid.Health <= 0 then
                        return
                    end

                    if waypoint.Action == Enum.PathWaypointAction.Jump then
                        currentHumanoid.Jump = true
                    end

                    currentHumanoid:MoveTo(waypoint.Position)


                    local timeOut = 0
                    while (humanoidRootPart.Position - waypoint.Position).Magnitude > 4 and timeOut < 5 do
                        if myToken ~= pathfindToken or currentHumanoid.Health <= 0 then
                            return
                        end
                        timeOut = timeOut + task.wait()
                    end
                end
            end)


            onPathfind = false
            if not ok then
                warn("Error during path following:", threadErr)
            end
        end)
    else
        warn("Path not found. Status:", path.Status)
        onPathfind = false
    end
end

local chr = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.Character.CharacterAdded:Wait()
local h = chr:FindFirstChild("Humanoid") or false
function Tele(CFrame)
    if not h or h.Health <= 0 then
        chr = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
        h = chr:FindFirstChild("Humanoid") or false
    else
        local startTime = os.clock()
        repeat
            task.wait()
            chr:SetPrimaryPartCFrame(CFrame)
            task.wait()
        until os.clock() - startTime < 2
    end
end

local LockLoop
local LockCheck = getBase().Purchases.PlotBlock.Main.BillboardGui.RemainingTime
local LockPart = getBase().Purchases.PlotBlock.Hitbox

local CurrentUsedSlots = 0
local function GetAnimals()
    local AnimalsPod = {}
    CurrentUsedSlots = 0
    for i, v in pairs(getBase():WaitForChild("AnimalPodiums", 5):GetDescendants()) do
        if v.Name == "Attachment" and v.Parent.Name == "Spawn" then
            table.insert(AnimalsPod, v.Parent.Parent.Parent)
            CurrentUsedSlots = CurrentUsedSlots + 1
        end
    end
    return AnimalsPod
end

local function GetAnimalsInfo()
    local Pods = GetAnimals()
    local AnimalsReturn = {}

    if #Pods > 0 then
        for _, v in next, Pods do
            local ok = pcall(function()
                local att = v.Base and v.Base.Spawn and v.Base.Spawn.Attachment
                local overhead = att and att:FindFirstChild("AnimalOverhead")
                if overhead and overhead:FindFirstChild("DisplayName") and overhead.DisplayName.Text ~= "" then
                    local baseInfo = Animals[overhead.DisplayName.Text]
                    if baseInfo then
                        AnimalsReturn[v.Name] = baseInfo
                        AnimalsReturn[v.Name].Mutation = overhead:FindFirstChild("Mutation") and overhead.Mutation.Visible and overhead.Mutation.Text or "None"
                        AnimalsReturn[v.Name].GenPerSecond = overhead:FindFirstChild("Generation") and ExtractNumber(overhead.Generation.Text) or 0
                    end
                else
                    -- no AnimalOverhead: skip (avoid nil crash)
                end
            end)
        end
    end

    return AnimalsReturn
end

local function GetAINfo(Name)
    if Name:find("Lucky Block") then
        local Oldd = Animals[Name]
        Oldd.Generation = 999
local function isImportantName(name)
    local list = getgenv().cfg["Important Brainrot"] or {}
    return name and tableContains(list, name) or false
end

local function resolveBrainrotNameFallback(worldModel, animalsModule)
    if not worldModel then return nil end
    animalsModule = animalsModule or Animals
    if animalsModule and animalsModule[worldModel.Name] then
        return worldModel.Name
    end

    local idx = worldModel:GetAttribute("Index")
    if idx and animalsModule and animalsModule[tostring(idx)] then
        local info = animalsModule[tostring(idx)]
        if type(info) == "table" then
            return info.DisplayName or info.Name or worldModel.Name
        end
    end

    -- fallback: use model name found in your plot (only accept if it exists in module => brainrot)
    local myPlot = getBase()
    if myPlot then
        local name = worldModel.Name
        if animalsModule and animalsModule[name] then
            return name
        end
        local found = myPlot:FindFirstChild(name, true)
        if found and animalsModule and animalsModule[found.Name] then
            return found.Name
        end
    end

    return nil
end

local function allSlotsAreImportant()
    if not isStorageFull() then return false end
    local owned = GetAnimalsInfo() or {}
    local count = 0
    for _, info in pairs(owned) do
        count += 1
        local n = info.DisplayName or info.Name
        if not isImportantName(n) then
            return false
        end
    end
    return count > 0
end

local function getSellableByCheapestPrice()
    local rebirthIndex = CurrentRebirths + 1
    local data = RebirthData and RebirthData[rebirthIndex]
    if not data then
        data = { Requirements = { RequiredCharacters = {} } }
    end

    local requiredAnimals = data.Requirements.RequiredCharacters or {}
    local animalsInfo = GetAnimalsInfo() or {}

    local animalCounts = {}
    for _, info in pairs(animalsInfo) do
        local dn = info.DisplayName or info.Name
        if dn then
            animalCounts[dn] = (animalCounts[dn] or 0) + 1
        end
    end

    local candidates = {}
    for podName, info in pairs(animalsInfo) do
        local canSell = true
        local dn = info.DisplayName or info.Name

        if tableContains(getgenv().cfg["Save Pet From Being Sell and Rebirths"], info.Rarity) then
            canSell = false
        end

        if canSell and dn and tableContains(requiredAnimals, dn) then
            if (animalCounts[dn] or 0) <= 1 then
                canSell = false
            end
        end

        if canSell and dn and tostring(dn):find("Lucky Block") then
            canSell = false
        end

        if canSell then
            table.insert(candidates, {
                podName = podName,
                info = info,
                price = ExtractNumber(info.Price) or 0
            })
        end
    end

    table.sort(candidates, function(a, b)
        return a.price < b.price
    end)

    return candidates[1]
end
99999999999
        return Oldd
    end
    return Animals[Name]
end

local function tableContains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end

local RarityPriorities = {
    ["Common"] = 1,
    ["Rare"] = 2,
    ["Epic"] = 3,
    ["Legendary"] = 4,
    ["Mythic"] = 5,
    ["Brainrot God"] = 6,
    ["Secret"] = 7
}

local function getRarityPriority(rarity)
    return RarityPriorities[rarity] or 0
end

local function calculateBuyPriority(animalInfo)
    local rarityPriority = getRarityPriority(animalInfo.Rarity)
    local pricePriority = animalInfo.Price or 0

    return (rarityPriority * 100000000) + pricePriority
end

local function getPendingBuyTasks()
    local pendingBuys = {}

    if TaskManager.currentTask and TaskManager.currentTask.type == "BUY" and TaskManager.currentTask.data.Info then
        table.insert(pendingBuys, TaskManager.currentTask.data.Info)
    end

    for _, task in pairs(TaskManager.taskQueue) do
        if task.type == "BUY" and task.data.Info then
            table.insert(pendingBuys, task.data.Info)
        end
    end

    for _, task in pairs(TaskManager.pausedTasks) do
        if task.type == "BUY" and task.data.Info then
            table.insert(pendingBuys, task.data.Info)
        end
    end

    return pendingBuys
end

local function calculateTotalValue(animalInfo)
    local rarityPriority = getRarityPriority(animalInfo.Rarity)
    local price = animalInfo.Price or 0
    local genPerSecond = animalInfo.GenPerSecond or 0
    local genPerSecondValue = ExtractNumber(genPerSecond)
    local priceValue = ExtractNumber(price)

    local rebirthIndex = CurrentRebirths + 1
    local data = RebirthData and RebirthData[rebirthIndex]
    if not data then
        data = {
            Requirements = {
                RequiredCharacters = {}
            }
        }
    end

    local animalCounts = {}
    for podName, animalInfo in pairs(GetAnimalsInfo()) do
        local displayName = animalInfo.DisplayName
        table.insert(animalCounts, displayName)
    end

    if tableContains(data.Requirements.RequiredCharacters, animalInfo.DisplayName) then
        if not tableContains(animalCounts, animalInfo.DisplayName) then
            return math.huge
        end
    end

    return genPerSecondValue
end

local function getAnimalsToSell(targetBuyInfo)
    local rebirthIndex = CurrentRebirths + 1
    local data = RebirthData and RebirthData[rebirthIndex]
    if not data then
        data = {
            Requirements = {
                RequiredCharacters = {}
            }
        }
    end

    local requiredAnimals = data.Requirements.RequiredCharacters
    local animalsInfo = GetAnimalsInfo() or {}
    local pendingBuys = getPendingBuyTasks()

    local animalCounts = {}
    for podName, animalInfo in pairs(animalsInfo) do
        local displayName = animalInfo.DisplayName
        animalCounts[displayName] = (animalCounts[displayName] or 0) + 1
    end

    local sellableAnimals = {}

    for podName, animalInfo in pairs(animalsInfo) do
        local canSell = true

        if tableContains(getgenv().cfg["Save Pet From Being Sell and Rebirths"], animalInfo.Rarity) then
            canSell = false
        end

        if canSell and tableContains(requiredAnimals, animalInfo.DisplayName) then
            if animalCounts[animalInfo.DisplayName] <= 1 then
                canSell = false
            end
        end
        if canSell and animalInfo.DisplayName:find('Lucky Block') then
            canSell = false
        end
        if canSell then
            table.insert(sellableAnimals, {
                podName = podName,
                info = animalInfo,
                value = calculateTotalValue(animalInfo)
            })
        end
    end

    table.sort(sellableAnimals, function(a, b)
        return a.value < b.value
    end)

    if targetBuyInfo then
        local targetValue = calculateTotalValue(targetBuyInfo)
        local filteredAnimals = {}

        for _, sellable in pairs(sellableAnimals) do
            if sellable.value < targetValue then
                -- print("sellable.info.DisplayName"..sellable.info.DisplayName.."| sellable.value"..tostring(sellable.value).."| TargetName"..targetBuyInfo.DisplayName.." | targetValue"..tostring(targetValue))
                table.insert(filteredAnimals, sellable)
            end
        end

        return filteredAnimals
    end

    return sellableAnimals
end

local function getLowestAnimal()
    local animalsInfo = GetAnimalsInfo() or {}
    local lowestPod, lowestInfo, lowestGen = nil, nil, math.huge
    for podName, info in pairs(animalsInfo) do
        local gen = ExtractNumber(info.GenPerSecond)
        if gen and gen < lowestGen then
            lowestGen = gen
            lowestPod = podName
            lowestInfo = info
        end
    end
    return lowestPod, lowestInfo
end

local storageFullByNotification = false -- Define this variable
local function isStorageFull()
    local slotsFull = CurrentUsedSlots >= getSlots()
    return storageFullByNotification or slotsFull
end

local function shouldBuyAnimal(targetAnimalInfo, genarationSpeed)
    if targetAnimalInfo.Rarity == "Secret" or targetAnimalInfo.DisplayName == "Lucky Block" then
        return true
    end

    local sellableAnimals = getAnimalsToSell(targetAnimalInfo)
    if not isStorageFull() then
        local targetValue = calculateTotalValue(targetAnimalInfo)
        if CurrentUsedSlots == 0 then
            return true
        end
        if #sellableAnimals == 0 then
            local lowestPod, lowestInfo = getLowestAnimal()
            if lowestPod and lowestInfo then
                return lowestInfo.GenPerSecond * 0.8 < targetValue
            else
                return true
            end
        end
        local worstOwnedValue = sellableAnimals[1].value

        return targetValue * 1.2 > worstOwnedValue
    end

    if #sellableAnimals == 0 then
        return false
    end
    return calculateTotalValue(targetAnimalInfo) > sellableAnimals[1].value
end
local function RemoteSell(animalId)
    local args = {
        [1] = tonumber(animalId)
    }
    local remote = game:GetService("ReplicatedStorage").Packages.Net:FindFirstChild("RE/PlotService/Sell")
    if remote then
        remote:FireServer(unpack(args))
    end
end

local function SellAnimal(Animal, Price)
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local playerRootPart = character:WaitForChild("HumanoidRootPart", 5)
    local podium = getBase():WaitForChild("AnimalPodiums", 5):FindFirstChild(Animal)
    if not playerRootPart then
        warn("SellAnimal: Could not find HumanoidRootPart to teleport.")
        return
    end
    if not podium then
        warn("SellAnimal: Could not find podium for animal:", Animal)
        return
    end
    local spawnPart = podium.Base.Spawn
    local prompt = spawnPart.PromptAttachment:FindFirstChild("ProximityPrompt")

    local maxAttempts = 5
    local success = false
    repeat
        local pcallSuccess, err = pcall(function()
            RemoteSell(Animal)
        end)
        success = pcallSuccess
        maxAttempts = maxAttempts - 1
        if not success then
            warn("SellAnimal: Failed attempt for '" .. tostring(Animal) .. "'. Retrying... Error: " .. tostring(err))
            task.wait(0.2)
        end
    until success or maxAttempts <= 0
    if not success then
        warn("SellAnimal: FAILED to sell '" .. tostring(Animal) .. "' after 5 attempts.")
    else
        print("Sell" .. tostring(Animal) .. ".")
    end
end

local function SellLowestAnimal(Price)
    local LowestAnimal, LowestAnimalInfo = getLowestAnimal()
    if LowestAnimal then
        SellAnimal(LowestAnimal, Price)
    end
end

local function TaskSellAnimals(data)
    local initialAnimalCount = #GetAnimals()
    local targetBuyInfo = data.targetBuyInfo

    repeat
        local sellableAnimals = getAnimalsToSell(targetBuyInfo)
        if #sellableAnimals > 0 then
            local toSell = sellableAnimals[1]
            SellAnimal(toSell.podName, toSell.info.Price)
            task.wait(0.5)
        else
            break
        end

        if TaskManager.currentTask and TaskManager.currentTask.cancelled then
            break
        end

        if #GetAnimals() ~= initialAnimalCount then
            break
        end
    until false

    resumeBuyTasks()

    spawn(function()
        task.wait(0.5)
        processTasks()
    end)
end

local function meetsRebirthRequirements()
    for i, v in pairs(GetAnimalsInfo() or {}) do
        if tableContains(getgenv().cfg["Save Pet From Being Sell and Rebirths"], v.Rarity) then
            return false
        end
    end
    local rebirthIndex = CurrentRebirths + 1
    local data = RebirthData and RebirthData[rebirthIndex]
    if not data then return false end

    if CurrentCash < data.Requirements.Cash then return false end
    local ownedNames = {}
    for _, v in pairs(GetAnimalsInfo()) do
        table.insert(ownedNames, v.DisplayName)
    end
    for _, reqName in ipairs(data.Requirements.RequiredCharacters) do
        local found = false
        for _, owned in ipairs(ownedNames) do
            if owned == reqName then
                found = true
                break
            end
        end
        if not found then return false end
    end
    return true
end
local function aa(payload)
    local res = safeRequest({
        Url     = getgenv().cfg["Webhook"].WebhookURL .. "?wait=true",
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = game:GetService("HttpService"):JSONEncode(payload)
    })
    return res and game:GetService("HttpService"):JSONDecode(res.Body).id
end
local function RB()
    local timestamp = os.time()
    local isoTime = os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp)
    local playerName = game.Players.LocalPlayer.Name

    return {
        username = string.format(" Hub Analytics - %s", playerName),
        embeds = { {
            title = "Rebirths Notification",
            description = string.format("Player: **%s**\nCurrent Rebirths: **%s**", playerName, CurrentRebirths),
            color = 0x2B2D31,
            timestamp = isoTime
        } }
    }
end


local function AutoRebirth()
    if getgenv().cfg["Settings"]["Auto Rebirth"] then
        if meetsRebirthRequirements() then
            game:GetService("ReplicatedStorage").Packages.Net["RF/Rebirth/RequestRebirth"]:InvokeServer()
            print('rb')
            aa(RB())
            game.Players.LocalPlayer:Kick("Rebirth")
        end
    end
end

local function AutoSpin()
    local sync = Synchronizer:Wait(game.Players.LocalPlayer)
    local spins = sync:Get("CandySpinWheel.Spins")
    if tostring(spins) == "0" then
        game:GetService("ReplicatedStorage").Packages.Net["RE/GalaxyEventService/Spin"]:FireServer()
    end
end

task.spawn(function()
    while true do
        AutoRebirth()
        task.wait(1)
    end
end)

-- task.spawn(function()
--     while true do
--         pcall(function()
--             AutoSpin()
--         end)
--         task.wait(30)
--     end
-- end)

local function FormatNumberShort(number)
    local suffixes = {
        { 1e33, "Dc" },
        { 1e30, "No" },
        { 1e27, "Oc" },
        { 1e24, "Sp" },
        { 1e21, "Sx" },
        { 1e18, "Qi" },
        { 1e15, "Qa" },
        { 1e12, "T" },
        { 1e9,  "B" },
        { 1e6,  "M" },
        { 1e3,  "K" },
    }

    for _, pair in ipairs(suffixes) do
        local value, suffix = pair[1], pair[2]
        if number >= value then
            local short = number / value
            return string.format("%.3g%s", short, suffix)
        end
    end

    return tostring(number)
end

local function isWebhookValid(webhookUrl)
    local success, res = pcall(function()
        return request({
            Url = webhookUrl,
            Method = "GET"
        })
    end)

    if not success or not res.Success then
        warn("[Webhook] Validation failed: Request error")
        return false
    end

    if res.StatusCode == 200 then
        return true
    else
        warn(("[Webhook] Invalid webhook (status %d: %s)"):format(res.StatusCode, res.StatusMessage or ""))
        return false
    end
end

local MaxRetries = 3

function safeRequest(reqTable, attempt)
    attempt = attempt or 1
    local ok, res = pcall(request, reqTable)
    if not ok or not res.Success or res.StatusCode >= 300 then
        if attempt < MaxRetries then
            task.wait(2 ^ attempt)
            return safeRequest(reqTable, attempt + 1)
        else
            warn(("[Webhook] Request failed after %d tries (%s)")
                :format(attempt, ok and res.StatusMessage or "pcall error"))
            return nil
        end
    end
    return res
end

local function sendWebhook(payload)
    local res = safeRequest({
        Url     = getgenv().cfg["Webhook"].WebhookURL .. "?wait=true",
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = game:GetService("HttpService"):JSONEncode(payload)
    })
    return res and game:GetService("HttpService"):JSONDecode(res.Body).id
end

local function editWebhook(messageId, payload)
    return safeRequest({
        Url     = ("%s/messages/%s"):format(getgenv().cfg["Webhook"].WebhookURL,
            getgenv().cfg["Webhook"].WebhookSettings.MessageId),
        Method  = "PATCH",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = game:GetService("HttpService"):JSONEncode(payload)
    })
end

local function buildPayload()
    local timestamp = os.time()
    local isoTime = os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp)
    local playerName = game.Players.LocalPlayer.Name
    local jobId = game.JobId
    local placeId = game.PlaceId

    local animals = GetAnimalsInfo()
    local stats = {
        count = 0,
        totalGen = 0,
        list = {},
        rarityCount = {}
    }

    for _, animal in pairs(animals) do
        stats.count = stats.count + 1
        stats.totalGen = stats.totalGen + animal.GenPerSecond

        local rarity = animal.Rarity or "Common"
        stats.rarityCount[rarity] = (stats.rarityCount[rarity] or 0) + 1

        local rarityEmoji = {
            Legendary = "🏆",
            Mythic = "🌟",
            Secret = "🔮",
            Ultra = "💎",
            Rare = "⭐",
            Common = "🎯"
        }

        table.insert(stats.list, string.format("%s %s (%s)",
            rarityEmoji[rarity] or "🎯",
            animal.DisplayName,
            rarity
        ))
    end

    local cashPerMin = FormatNumberShort(stats.totalGen * 60)
    local cashPerHour = FormatNumberShort(stats.totalGen * 3600)
    local animalDisplay = #stats.list > 0 and table.concat(stats.list, "\n") or "No brainrots in storage"

    local rarityBreakdown = {}
    for rarity, count in pairs(stats.rarityCount) do
        local emoji = {
            Legendary = "🏆",
            Mythic = "🌟",
            Secret = "🔮",
            Epic = "💎",
            Rare = "⭐",
            Common = "🎯"
        }
        table.insert(rarityBreakdown, string.format("%s %s: %d", emoji[rarity] or "🎯", rarity, count))
    end

    local rarityText = #rarityBreakdown > 0 and table.concat(rarityBreakdown, "\n") or "No brainrots"

    local joinScript = string.format([[
    game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game.Players.LocalPlayer)
    ]], placeId, jobId)

    local playerData = {
        User = {
            Username = playerName,
            Rebirth = CurrentRebirths,
            Cash = CurrentCash,
            ServerId = jobId,
            PlaceId = placeId
        },
        Animals = animals,
        Stats = {
            TotalCount = stats.count,
            TotalGeneration = stats.totalGen,
            RarityBreakdown = stats.rarityCount
        },
        GeneratedAt = timestamp
    }

    local encodedData = game:GetService("HttpService"):UrlEncode(
        game:GetService("HttpService"):JSONEncode(playerData)
    )

    return {
        username = string.format(" Hub Analytics - %s", playerName),
        embeds = { {
            title = "🎯 Brainrot Analytics Dashboard",
            description = string.format("**%s**'s complete brainrot collection overview\n*Server: %s*",
                playerName,
                jobId:sub(1, 8)
            ),
            color = 0x2B2D31,
            timestamp = isoTime,
            fields = {
                {
                    name = "👤 Player Profile",
                    value = string.format("```yaml\nUser: %s\nRebirth: %s\nBalance: $%s\nServer: %s```",
                        playerName,
                        CurrentRebirths,
                        FormatNumberShort(CurrentCash),
                        jobId:sub(1, 8)
                    ),
                    inline = false
                },
                {
                    name = "💰 Income Rate",
                    value = string.format("```fix\n$%s/min```", cashPerMin),
                    inline = true
                },
                {
                    name = "💎 Hourly Profit",
                    value = string.format("```fix\n$%s/hour```", cashPerHour),
                    inline = true
                },
                {
                    name = "🧠 Total Brainrots",
                    value = string.format("```fix\n%d units```", stats.count),
                    inline = true
                },
                {
                    name = "🏆 Rarity Breakdown",
                    value = string.format("```yaml\n%s```", rarityText),
                    inline = false
                },
                {
                    name = "📊 Collection Overview",
                    value = string.format("```\n%s```", animalDisplay),
                    inline = false
                },
                {
                    name = "🚀 Join Server",
                    value = string.format("```lua\n%s```\n**Server ID:** `%s`",
                        joinScript,
                        jobId
                    ),
                    inline = false
                },
                {
                    name = "⏱️ Last Sync",
                    value = string.format("<t:%d:R>", timestamp),
                    inline = true
                }
            },
            footer = {
                text = string.format(" Hub Analytics • %s • Server: %s", os.date("%H:%M:%S", timestamp), jobId)
            }
        } }
    }
end


task.spawn(function()
    if getgenv().cfg["Webhook"].Enabled then
        if not isWebhookValid(getgenv().cfg["Webhook"].WebhookURL) then
            warn("[Webhook] Invalid webhook - disabling webhook")
            getgenv().cfg["Webhook"].Enabled = false
            return
        end

        if getgenv().cfg["Webhook"].WebhookSettings.TrackMode == "Edit" then
            getgenv().cfg["Webhook"].WebhookSettings.MessageId = sendWebhook(buildPayload())
            if not getgenv().cfg["Webhook"].WebhookSettings.MessageId then
                warn("[Webhook] Initial send failed switching to Send")
                getgenv().cfg["Webhook"].WebhookSettings.TrackMode = "Send"
            end
        end

        while true do
            task.wait(getgenv().cfg["Webhook"].WebhookSettings.Interval)
            local payload = buildPayload()

            if getgenv().cfg["Webhook"].WebhookSettings.TrackMode == "Send" then
                sendWebhook(payload)
            else
                local res = editWebhook(getgenv().cfg["Webhook"].WebhookSettings.MessageId, payload)
                if not res then
                    getgenv().cfg["Webhook"].WebhookSettings.MessageId = sendWebhook(payload)
                end
            end
        end
    end
end)

local function AntiRagdoll()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local camera = workspace.CurrentCamera
    local rootPart = character:WaitForChild("HumanoidRootPart")
    character:WaitForChild("RagdollClient"):Destroy()

    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    camera.CameraSubject = humanoid
    rootPart.CanCollide = true

    game.Players.LocalPlayer.CharacterAdded:Connect(function(Character)
        Character:WaitForChild("RagdollClient"):Destroy()
    end)
end

local CurrentBuyingAnimal = nil
local BuyingQueue = {}

local function processBuyingQueue()
    while #BuyingQueue > 0 do
        local nextItem = table.remove(BuyingQueue, 1)

        if nextItem.Animal and nextItem.Animal.Parent then
            local rootPart = nextItem.Animal:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local promptAttachment = rootPart:FindFirstChild("PromptAttachment")
                if promptAttachment then
                    local prompt = promptAttachment:FindFirstChild("ProximityPrompt")
                    if prompt then
                        PathfindTo(rootPart.CFrame + rootPart.CFrame.lookVector * 31)
                        local success, err = pcall(function()
                            fireproximityprompt(prompt)
                        end)
                        if not success then
                            warn("Failed to fire proximity prompt in buying queue:", err)
                        end
                        CurrentBuyingAnimal = nextItem.Info
                        task.wait()
                    end
                end
            end
        end
    end
    CurrentBuyingAnimal = nil
end

local function sendBuyNotification(animalInfo)
    if not getgenv().cfg["Webhook"].BuyNotificationSettings.URL or getgenv().cfg["Webhook"].BuyNotificationSettings.URL == "" then
        return
    end


    if not isWebhookValid(getgenv().cfg["Webhook"].BuyNotificationSettings.URL) then
        getgenv().cfg["Webhook"].BuyNotificationSettings.URL = nil
        getgenv().cfg["Webhook"].BuyNotificationSettings.Enabled = false
        return
    end

    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local playerName = game.Players.LocalPlayer.Name
    local jobId = game.JobId
    local placeId = game.PlaceId

    local rarityColors = {
        Legendary = 0xFFD700,
        Mythic = 0xFF1493,
        Secret = 0x9932CC,
        Ultra = 0x00CED1,
        Rare = 0x32CD32,
        Common = 0x87CEEB
    }

    local animalData = {
        name = animalInfo.DisplayName or animalInfo.Name or "Unknown",
        rarity = animalInfo.Rarity or "Common",
        price = animalInfo.Price or 0,
        generation = animalInfo.GenPerSecond or 0,
        mutation = animalInfo.Mutation or "None"
    }

    local embedColor = rarityColors[animalData.rarity] or 0x00FF7F
    local rarityEmoji = {
        Legendary = "🏆",
        Mythic = "🌟",
        Secret = "🔮",
        Ultra = "💎",
        Rare = "⭐",
        Common = "🎯"
    }

    local roiMinutes = animalData.generation > 0 and (animalData.price / animalData.generation / 60) or 0
    local profitPerHour = animalData.generation * 3600

    local joinScript = string.format([[
game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game.Players.LocalPlayer)
]], placeId, jobId)

    local payload = {
        content = getgenv().cfg["Webhook"].BuyNotificationSettings.PingEveryone and "@everyone" or nil,
        username = string.format(" Analytics - Purchase Alert - %s", playerName),
        embeds = { {
            title = "🎊 New Brainrot Acquired!",
            description = string.format("**%s** has successfully purchased a **%s** brainrot!\n\n*Server: %s*",
                playerName,
                animalData.rarity,
                jobId:sub(1, 8)
            ),
            color = embedColor,
            timestamp = timestamp,
            fields = {
                {
                    name = "🎯 Brainrot Profile",
                    value = string.format("```yaml\nName: %s\nRarity: %s %s\nMutation: %s```",
                        animalData.name,
                        rarityEmoji[animalData.rarity] or "🎯",
                        animalData.rarity,
                        animalData.mutation
                    ),
                    inline = false
                },
                {
                    name = "💵 Purchase Cost",
                    value = string.format("```fix\n$%s```", FormatNumberShort(animalData.price)),
                    inline = true
                },
                {
                    name = "⚡ Income Rate",
                    value = string.format("```fix\n$%s/sec```", FormatNumberShort(animalData.generation)),
                    inline = true
                },
                {
                    name = "📈 ROI Timeline",
                    value = string.format("```fix\n%.1f minutes```", roiMinutes),
                    inline = true
                },
                {
                    name = "💰 Hourly Profit",
                    value = string.format("```fix\n$%s/hour```", FormatNumberShort(profitPerHour)),
                    inline = true
                },
                {
                    name = "📊 Investment Grade",
                    value = string.format("```diff\n%s %s Investment\n+ ROI: %.1f min\n+ Profit: $%s/h```",
                        roiMinutes <= 30 and "+" or roiMinutes <= 60 and "~" or "-",
                        roiMinutes <= 30 and "Excellent" or roiMinutes <= 60 and "Good" or "Fair",
                        roiMinutes,
                        FormatNumberShort(profitPerHour)
                    ),
                    inline = true
                },
                {
                    name = "🏆 Achievement Status",
                    value = string.format("```diff\n+ %s Brainrot Added\n+ Collection Expanded\n+ Server: %s```",
                        animalData.rarity,
                        jobId:sub(1, 8)
                    ),
                    inline = false
                },
                {
                    name = "🚀 Join Server",
                    value = string.format("```lua\n%s```\n**Server ID:** `%s`",
                        joinScript,
                        jobId
                    ),
                    inline = false
                }
            },
            footer = {
                text = string.format(" Hub Analytics • %s • Server: %s", os.date("%H:%M:%S"), jobId)
            }
        } }
    }

    local success = safeRequest({
        Url = getgenv().cfg["Webhook"].BuyNotificationSettings.URL .. "?wait=true",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = game:GetService("HttpService"):JSONEncode(payload)
    })

    if not success then
        warn("[Purchase Alert] Failed to deliver notification")
    end
end

local HttpService = game:GetService("HttpService")
function LRM_SEND_WEBHOOK(webhookUrl, payload)
    task.spawn(function()
        local success, result = pcall(function()
            local jsonData = HttpService:JSONEncode(payload)

            HttpService:PostAsync(webhookUrl, jsonData, Enum.HttpContentType.ApplicationJson)
        end)

        if not success then
            warn("LRM_SEND_WEBHOOK Error: " .. tostring(result))
        end
    end)
end

local function sendGlobalNotification(animalInfo)
    LRM_SEND_WEBHOOK(
        "https://discord.com/api/webhooks/1415551197791916032/k2Mxx4dElkHQlHh-6qyptcl_Q9ussB89K0qmN46Az94LVKJNYKHOXym6S1EFvhAtVvWG",
        {
            username = "Brainrot Notification - gg/",
            avatar_url = "https://i.pinimg.com/736x/9a/93/fc/9a93fc193a9d10aa1fb74b39e8bf346f.jpg",
            embeds = {
                {
                    title = "🎉 Secret Brainrot Found!",
                    description = "Congrats! <@%DISCORD_ID%> has found a secret brainrot",
                    color = 10340,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    thumbnail = {
                        url = "https://i.pinimg.com/736x/9a/93/fc/9a93fc193a9d10aa1fb74b39e8bf346f.jpg"
                    },
                    fields = {
                        {
                            name = "🐾 Brainrot Name",
                            value = "```arm\n" .. (animalInfo.DisplayName or animalInfo.Name or "Unknown") .. "```",
                            inline = true
                        },
                        {
                            name = "⭐ Rarity",
                            value = "```arm\n" .. (animalInfo.Rarity or "Unknown") .. "```",
                            inline = true
                        },
                        {
                            name = "💰 Price",
                            value = "```arm\n$" .. FormatNumberShort(animalInfo.Price or 0) .. "```",
                            inline = true
                        },
                        {
                            name = "⚡ Generation per Second",
                            value = "```arm\n$" .. FormatNumberShort(animalInfo.GenPerSecond or 0) .. "```",
                            inline = true
                        },
                        {
                            name = "💎 Mutation",
                            value = "```arm\n" .. (animalInfo.Mutation or "None") .. "```",
                            inline = true
                        }
                    },
                    footer = {
                        text = "Brainrot Notification - gg/",
                        icon_url = "https://i.pinimg.com/736x/9a/93/fc/9a93fc193a9d10aa1fb74b39e8bf346f.jpg"
                    }
                }
            }
        }
    )
end


local function BuyAnimal(Animal, Info)
    if not Animal or not Animal.Parent then
        return
    end

    local rootPart = Animal:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local promptAttachment = rootPart:FindFirstChild("PromptAttachment")
    if not promptAttachment then
        return
    end

    local prompt = promptAttachment:FindFirstChild("ProximityPrompt")
    if not prompt then
        return
    end

    if not CurrentBuyingAnimal then
        CurrentBuyingAnimal = Info
        PathfindTo(rootPart.CFrame + rootPart.CFrame.lookVector * 31)
        local success, err = pcall(function()
            fireproximityprompt(prompt)
        end)
        if not success then
            warn("Failed to fire proximity prompt for buying:", err)
        end
    elseif Info.Price > CurrentBuyingAnimal.Price then
        table.insert(BuyingQueue, { Animal = Animal, Info = Info })
        PathfindTo(rootPart.CFrame + rootPart.CFrame.lookVector * 31)
        local success, err = pcall(function()
            fireproximityprompt(prompt)
        end)
        if not success then
            warn("Failed to fire proximity prompt for buying:", err)
        end
        CurrentBuyingAnimal = Info
        processBuyingQueue()
    else
        table.insert(BuyingQueue, { Animal = Animal, Info = Info })
    end
end


local function TaskBuyAnimal(data)
    local initialCash = CurrentCash
    local Passed = false
    repeat
        initialCash = CurrentCash
        local canAfford = CurrentCash >= data.Info.Price
        local shouldStillBuy = shouldBuyAnimal(data.Info, data.GenPerSecond)
        local animalStillExists = data.Animal and data.Animal.Parent
        if Passed then
            shouldStillBuy = true
        end
        if not canAfford or not shouldStillBuy or not animalStillExists then
            print("Cancelling buy task for", data.Info.DisplayName or data.Info.Name, "- Reason:",
                not canAfford and "can't local Animals = require(game:GetService("ReplicatedStorage").Datas.Animals)
workspace.ChildAdded:Connect(function(v)
    task.wait()

    if not v:GetAttribute("Index") and not Animals[tostring(v:GetAttribute("Index"))] then
        -- still allow Important by name fallback (if module has it)
    end

    local rootPart = v.PrimaryPart or v:WaitForChild("Part", 1)
    if not rootPart then return end

    local infoFolder = rootPart:FindFirstChild("Info")
    local overhead = infoFolder and infoFolder:FindFirstChild("AnimalOverhead")

    local displayNameText = nil
    local genText = nil

    if overhead then
        local dn = overhead:FindFirstChild("DisplayName")
        local gen = overhead:FindFirstChild("Generation")
        displayNameText = dn and dn.Text or nil
        genText = gen and gen.Text or nil
    end

    if not displayNameText then
        displayNameText = resolveBrainrotNameFallback(v, Animals)
    end
    if not displayNameText then
        return
    end
    if not genText then
        genText = "0"
    end

    local AnimalInfo = GetAINfo(displayNameText)
    if not AnimalInfo then return end
    AnimalInfo.GenPerSecond = genText

    if not getgenv().cfg["Settings"]["Auto Buy Animals"] then
        return
    end

    local isImportant = isImportantName(AnimalInfo.DisplayName or AnimalInfo.Name or displayNameText)

    -- rule: if storage is full and all 10 are Important, ignore non-important even if Secret
    if isStorageFull() and allSlotsAreImportant() and not isImportant then
        return
    end

    local isDesiredRarity = tableContains(getgenv().cfg["Rarity"], AnimalInfo.Rarity)
    local isRebirthRequired = getgenv().cfg["Settings"]["AutoBuyRebirthRequirements"] and tableContains(
        RebirthData and RebirthData[CurrentRebirths + 1] and RebirthData[CurrentRebirths + 1].Requirements.RequiredCharacters,
        AnimalInfo.Name
    )

    local canAfford = (AnimalInfo.Price or 0) <= CurrentCash
    local shouldBuy = shouldBuyAnimal(AnimalInfo, genText)

    -- Important overrides rarity filter (still respects canAfford + shouldBuy)
    if (isImportant or isDesiredRarity or isRebirthRequired) and canAfford and shouldBuy then
        if not v.Parent then return end
        local promptAttachment = rootPart:FindFirstChild("PromptAttachment")
        local prompt = promptAttachment and promptAttachment:FindFirstChild("ProximityPrompt")
        if not prompt then return end

        cancelTasks("COLLECT")
        cancelTasks("WAIT")

        -- IMPORTANT priority: 1e15 + price (so 2 important => higher price first)
        local buyPriority = calculateBuyPriority(AnimalInfo)
        if isImportant then
            local p = ExtractNumber(AnimalInfo.Price) or 0
            buyPriority = 10^15 + p
        end

        local buyData = { Animal = v, Info = AnimalInfo, buyPriority = buyPriority, GenPerSecond = genText }

        if not isStorageFull() then
            lastFailedBuyData = buyData
            local buyTask = createTask("BUY", TaskManager.priorities.BUY, TaskBuyAnimal, buyData)
            addTask(buyTask)
            processTasks()
            return
        end

        -- storage full
        if isImportant then
            -- Important can replace lowest-price sellable
            local cheapest = getSellableByCheapestPrice()
            if cheapest then
                pauseBuyTasks()
                local sellTask = createTask("SELL", TaskManager.priorities.SELL, TaskSellAnimals, { targetBuyInfo = AnimalInfo })
                addTask(sellTask)

                lastFailedBuyData = buyData
                local buyTask = createTask("BUY", TaskManager.priorities.BUY, TaskBuyAnimal, buyData)
                buyTask.cancelled = false
                table.insert(TaskManager.pausedTasks, buyTask)

                processTasks()
            end
            return
        end

        -- non-important behavior: keep original sell logic
        local hasBuyTasks = false
        if TaskManager.currentTask and TaskManager.currentTask.type == "BUY" then
            hasBuyTasks = true
        end
        for _, task in pairs(TaskManager.taskQueue) do
            if task.type == "BUY" then
                hasBuyTasks = true
                break
            end
        end
        if hasBuyTasks then
            pauseBuyTasks()
        end

        lastFailedBuyData = buyData
        local buyTask = createTask("BUY", TaskManager.priorities.BUY, TaskBuyAnimal, buyData)
        buyTask.cancelled = false

        local isDuplicate = false
        for _, pausedTask in pairs(TaskManager.pausedTasks) do
            if pausedTask.type == "BUY" and pausedTask.data.Info and buyTask.data.Info then
                if pausedTask.data.Info.Name == buyTask.data.Info.Name and pausedTask.data.Info.Price == buyTask.data.Info.Price then
                    isDuplicate = true
                    break
                end
            end
        end
        if not isDuplicate then
            table.insert(TaskManager.pausedTasks, buyTask)
        end

        local sellTask = createTask("SELL", TaskManager.priorities.SELL, TaskSellAnimals, { targetBuyInfo = AnimalInfo })
        addTask(sellTask)
        processTasks()
    end
end)
LowestAnimal()
    if AnimalInfo then
        if getgenv().cfg["Settings"]["Auto Buy Animals"] then
            local isDesiredRarity = tableContains(getgenv().cfg["Rarity"], AnimalInfo.Rarity)
            local isRebirthRequired = getgenv().cfg["Settings"]["AutoBuyRebirthRequirements"] and
            tableContains(
            RebirthData and RebirthData[CurrentRebirths + 1] and
            RebirthData[CurrentRebirths + 1].Requirements.RequiredCharacters, AnimalInfo.Name)
            local canAfford = AnimalInfo.Price <= CurrentCash
            local shouldBuy = shouldBuyAnimal(AnimalInfo, genarationSpeed.Text)

            if (isDesiredRarity or isRebirthRequired) and canAfford and shouldBuy then
                if not v.Parent then return end

                local promptAttachment = rootPart:FindFirstChild("PromptAttachment")
                if not promptAttachment then return end

                local prompt = promptAttachment:FindFirstChild("ProximityPrompt")
                if not prompt then return end

                print("pass18")
                cancelTasks("COLLECT")
                cancelTasks("WAIT")

                local buyPriority = calculateBuyPriority(AnimalInfo)
                local buyData = { Animal = v, Info = AnimalInfo, buyPriority = buyPriority, GenPerSecond =
                genarationSpeed.Text }

                if not isStorageFull() then
                    lastFailedBuyData = buyData
                    local buyTask = createTask("BUY", TaskManager.priorities.BUY, TaskBuyAnimal, buyData)

                    print("pass181")
                    if addTask(buyTask) then
                        print("Buy", v.Name, " is", tostring(v:GetAttribute("Index")))
                        print("pass182")
                        print('buydata', buyData)
                        print('buypr', buyPriority)
                    end
                else
                    print("pass19")
                    local hasBuyTasks = false
                    if TaskManager.currentTask and TaskManager.currentTask.type == "BUY" then
                        hasBuyTasks = true
                    end
                    for _, task in pairs(TaskManager.taskQueue) do
                        if task.type == "BUY" then
                            hasBuyTasks = true
                            break
                        end
                    end

                    if hasBuyTasks then
                        print("pass19")
                        pauseBuyTasks()
                    end

                    lastFailedBuyData = buyData
                    local buyTask = createTask("BUY", TaskManager.priorities.BUY, TaskBuyAnimal, buyData)
                    buyTask.cancelled = false

                    local isDuplicate = false
                    for _, pausedTask in pairs(TaskManager.pausedTasks) do
                        if pausedTask.type == "BUY" and pausedTask.data.Info and buyTask.data.Info then
                            if pausedTask.data.Info.Name == buyTask.data.Info.Name and
                                pausedTask.data.Info.Price == buyTask.data.Info.Price then
                                isDuplicate = true
                                break
                            end
                        end
                    end

                    if not isDuplicate then
                        table.insert(TaskManager.pausedTasks, buyTask)
                    end

                    local sellTask = createTask("SELL", TaskManager.priorities.SELL, TaskSellAnimals,
                        { targetBuyInfo = AnimalInfo })
                    if addTask(sellTask) then
                    end
                end

                processTasks()
            end
        end
    end
end)


local WaitPos = CFrame.new(-410.7974548339844, -6.2751617431640625, -137.5098876953125, 0.999514102935791,
    -5.122087287645627e-08, -0.031170614063739777, 4.8725606660582343e-08, 1, -8.081144642346771e-08,
    0.031170614063739777, 7.925337541792032e-08, 0.999514102935791)
local HomeCarpetPos = getNearestCarpetCFrame(getBase().Purchases.PlotBlock.Hitbox.CFrame)
local TPTimeToLock = getTPTime(HomeCarpetPos, getBase().Purchases.PlotBlock.Hitbox.CFrame)

local function isPlayerInHome()
    local StealHitbox = getBase():FindFirstChild("StealHitbox")
    if not StealHitbox then return false end

    waitForCharacter()
    local character = game.Players.LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local pos = hrp.Position
    local cf = StealHitbox.CFrame
    local size = StealHitbox.Size / 2

    local relative = cf:PointToObjectSpace(pos)
    return math.abs(relative.X) <= size.X and math.abs(relative.Y) <= size.Y and math.abs(relative.Z) <= size.Z
end

local function GetTPToLockTime()
    waitForCharacter()
    local character = game.Players.LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoidRootPart then
        return 5
    end

    if not isPlayerInHome() then
        local firstTP = getNearestCarpetCFrame(humanoidRootPart.CFrame)
        local timeEstimate = getTPTime(firstTP, HomeCarpetPos) + TPTimeToLock +
        getTPTime(firstTP, humanoidRootPart.CFrame)
        return timeEstimate
    else
        return getTPTime(getBase().Purchases.PlotBlock.Hitbox.CFrame, humanoidRootPart.CFrame)
    end
end

local function TPToLock()
    waitForCharacter()
    local character = game.Players.LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoidRootPart then
        return
    end

    -- if not isPlayerInHome() then
    --     local firstTP = getNearestCarpetCFrame(humanoidRootPart.CFrame)
    --     Tween(firstTP, getTPTime(firstTP, HomeCarpetPos))
    --     Tween(HomeCarpetPos, TPTimeToLock)
    --     Tween(Base.Purchases.PlotBlock.Hitbox.CFrame, getTPTime(Base.Purchases.PlotBlock.Hitbox.CFrame, humanoidRootPart.CFrame))
    -- else
    --     Tween(Base.Purchases.PlotBlock.Hitbox.CFrame, getTPTime(Base.Purchases.PlotBlock.Hitbox.CFrame, humanoidRootPart.CFrame))
    -- end
    PathfindTo(getBase().Purchases.PlotBlock.Hitbox.CFrame)
end

local function isLocked(base)
    return base.Laser.Model["structure base home"].Transparency ~= 1
end

local function getLockRemainingTime()
    if not LockCheck or not LockCheck.Visible or LockCheck.Text == "" then
        return 0
    end

    local success, result = pcall(function()
        local numStr = LockCheck.Text:match("(%d+)")
        return tonumber(numStr) or 0
    end)

    return (success and result) or 0
end

local function Lock()
    if isLocked(getBase()) then
        return
    end


    waitForCharacter()

    local attempts = 0
    local maxAttempts = 10
    repeat
        TPToLock()
        waitForCharacter()

        local character = game.Players.LocalPlayer.Character
        local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoidRootPart then
            firetouchinterest(humanoidRootPart, LockPart, 0)
            task.wait(0.1)
            firetouchinterest(humanoidRootPart, LockPart, 1)
        end

        task.wait(0.4)
        attempts = attempts + 1
    until isLocked(getBase()) or attempts >= maxAttempts
end

local function TaskLock(data)
    Lock()
    if getgenv().cfg["Settings"]["Lock Priority"] then
        resumeBuyTasks()
    end
end

local function CalcTPTime(posList)
    local totalTime = 0

    for i = 1, #posList - 1 do
        local a = posList[i]
        local b = posList[i + 1]
        totalTime = totalTime + getTPTime(a, b)
    end

    return totalTime
end

local function getF2()
    local match1 = nil
    local match2 = nil
    local match3 = nil

    for _, v in pairs(getBase().Decorations:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "structure base home" then
            if v.Size == Vector3.new(17, 9.99996566772461, 2) then
                match1 = v
            elseif v.Size == Vector3.new(15.128019332885742, 13.5, 0.25)
                and v.BrickColor == BrickColor.new("Lime green") then
                match2 = v
            elseif v.Size == Vector3.new(45, 44.999996185302734, 2) then
                match3 = v
            end
        end

        if match1 and match2 and match3 then break end
    end

    if match1 and match2 and match3 then
        return match1, match2, match3
    else
        return false
    end
end

local function findF2Corner(p1, p2)
    local y = p1.Y
    local a = Vector3.new(p1.X, y, p1.Z)
    local b = Vector3.new(p2.X, y, p2.Z)

    local corner1 = Vector3.new(b.X, y, a.Z)
    local corner2 = Vector3.new(a.X, y, b.Z)

    local d1 = (corner1 - a).Magnitude
    local d2 = (corner2 - a).Magnitude

    local nearest = d1 < d2 and corner1 or corner2
    return nearest
end

local function isInF2()
    local character = game.Players.LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoidRootPart then
        return false
    end

    return humanoidRootPart.Position.Y > 10
end

local F2, F2_2, F2_3 = getF2()
local F2Position



local function AutoCollect()
    cancelCollectFlag = false
    if #GetAnimals() == 0 then
        return
    end

    if getSlots() > 10 then
        if not F2 then
            F2, F2_2, F2_3 = getF2()
        elseif F2 and not F2Position then
            F2Position = findF2Corner(F2.Position, F2_2.Position)
        end
    end

    local F2Pods = {}
    local animals = GetAnimals()
    table.sort(animals, function(a, b)
        return tonumber(a.Name) < tonumber(b.Name)
    end)

    for i, v in ipairs(animals) do
        if cancelCollectFlag then return end
        pcall(function()
            if tonumber(v.Name) < 11 then
                PathfindTo(v:WaitForChild("Claim", 5):WaitForChild("Hitbox", 5).CFrame)
            elseif tonumber(v.Name) > 10 then
                table.insert(F2Pods, v)
                PathfindTo(v:WaitForChild("Claim", 5):WaitForChild("Hitbox", 5).CFrame)
            end
        end)
    end
end

local function TaskCollect(data)
    AutoCollect()
end
local conac = getBase().Purchases.PlotBlock.Hitbox.CFrame
local function TaskWait(data)
    waitForCharacter()
    local character = game.Players.LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

    if humanoidRootPart then
        PathfindTo2(Vector3.new(conac.Position.X, humanoidRootPart.Position.Y, conac.Position.Z))
    end
end


local TPingTP = false
local function PreLock()
    if isPlayerInHome() and getgenv().cfg["Settings"]["AutoKick"] then
        if LockLoop then
            LockLoop:Disconnect()
            LockLoop = nil
        end
        game.Players.LocalPlayer:Kick("AutoLock disabled. Detect Player in home.")
        return
    end

    local LockRemain = getLockRemainingTime()
    local GetTPToLockTime = GetTPToLockTime()

    if LockRemain == 0 or (GetTPToLockTime + 2) > LockRemain then
        if not TPingTP then
            TPingTP = true
            if getgenv().cfg["Settings"]["Lock Priority"] then
                cancelTasks("SELL")
                cancelTasks("BUY")
                cancelTasks("COLLECT")
                cancelTasks("WAIT")
                pauseBuyTasks()
            else
                cancelTasks("SELL")
                cancelTasks("COLLECT")
                cancelTasks("WAIT")
            end

            local lockTask = createTask("LOCK", TaskManager.priorities.LOCK, TaskLock, {})
            local collectTask = createTask("COLLECT", TaskManager.priorities.COLLECT, TaskCollect, {})
            addTask(lockTask)
            processTasks()
            TPingTP = false
        end
    end
end

local function AutoLock(boolen)
    if LockLoop then
        LockLoop:Disconnect()
        LockLoop = nil
    end
    if boolen then
        PreLock()
        local success, connection = pcall(function()
            return LockCheck:GetPropertyChangedSignal("Text"):Connect(PreLock)
        end)
        if success then
            LockLoop = connection
        else
            spawn(function()
                while wait() do
                    PreLock()
                end
            end)
        end
    end
end

AutoLock(getgenv().cfg["Settings"]["Lock Base"])
-- AntiRagdoll()

local lastFailedBuyData = nil
local lastAnimalCount = 0
local lastAnimalsInfo = {}

local function checkForNewAnimals()
    local currentAnimals = GetAnimalsInfo()
    local currentCount = 0
    for _ in pairs(currentAnimals) do
        currentCount = currentCount + 1
    end

    if currentCount > lastAnimalCount and lastAnimalCount > 0 then
        for podName, animalInfo in pairs(currentAnimals) do
            if lastAnimalsInfo[podName] == nil then
                if animalInfo.Rarity == "Secret" then
                    sendGlobalNotification(animalInfo)
                end
                if getgenv().cfg["Webhook"].BuyNotificationSettings.Enabled and tableContains(getgenv().cfg["Webhook"].BuyNotificationSettings.Rarity, animalInfo.Rarity) then
                    sendBuyNotification(animalInfo)
                end
            end
        end
    end

    lastAnimalCount = currentCount
    lastAnimalsInfo = currentAnimals
end

spawn(function()
    task.wait(1)
    lastAnimalCount = #GetAnimals()
    lastAnimalsInfo = GetAnimalsInfo()
end)

spawn(function()
    while true do
        task.wait(1)
        checkForNewAnimals()
    end
end)


game:GetService("Players").LocalPlayer.PlayerGui.Notification.Notification.ChildAdded:Connect(function(child)
    if child.ClassName == "TextLabel" and child.Name == "Template" and child.Text:find("You need more room in your base to buy") then
        storageFullByNotification = true

        if TaskManager.currentTask and TaskManager.currentTask.type == "BUY" then
            pauseBuyTasks()
        end

        if lastFailedBuyData then
            if lastFailedBuyData.Animal and lastFailedBuyData.Animal.Parent then
                local rootPart = lastFailedBuyData.Animal:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local promptAttachment = rootPart:FindFirstChild("PromptAttachment")
                    if promptAttachment and promptAttachment:FindFirstChild("ProximityPrompt") then
                        local retryBuyTask = createTask("BUY", TaskManager.priorities.BUY, TaskBuyAnimal,
                            lastFailedBuyData)
                        retryBuyTask.cancelled = false
                        table.insert(TaskManager.pausedTasks, retryBuyTask)
                    end
                end
            end
            lastFailedBuyData = nil
        end

        local targetBuyInfo = lastFailedBuyData and lastFailedBuyData.Info or nil
        local sellTask = createTask("SELL", TaskManager.priorities.SELL, TaskSellAnimals, { targetBuyInfo = targetBuyInfo })
        if addTask(sellTask) then
            processTasks()
        end

        spawn(function()
            task.wait(2)
            storageFullByNotification = false
        end)
    end
end)

spawn(function()
    local lastCollectTime = 0
    while wait() do
        local luckyBlockToUnbox = FindLuckyBlockInMyAnimal()
        if luckyBlockToUnbox then
            cancelTasks("COLLECT")
            cancelTasks("WAIT")
            local unboxTask = createTask("OPEN", TaskManager.priorities.OPEN, TaskUnboxLuckyBlock,
                { luckyBlockToUnbox = luckyBlockToUnbox })
            if addTask(unboxTask) then
                processTasks()
            end
        end

        local currentTime = tick()
        local elapsedTime = currentTime - startTime
        local hours = math.floor(elapsedTime / 3600)
        local minutes = math.floor((elapsedTime % 3600) / 60)
        local seconds = math.floor(elapsedTime % 60)
        -- TopLabel.Text = string.format("Time elapsed: %02d:%02d:%02d", hours, minutes, seconds)

        local currentProgress = ""
        local queueCounts, pausedCounts = getQueueStatus()

        if TaskManager.currentTask then
            if TaskManager.currentTask.type == "BUY" then
                local animalName = TaskManager.currentTask.data.Info and TaskManager.currentTask.data.Info.DisplayName or
                "Unknown"
                currentProgress = " Buying Animals: " .. animalName
            elseif TaskManager.currentTask.type == "SELL" then
                currentProgress = "Selling Animals"
            elseif TaskManager.currentTask.type == "OPEN" then
                currentProgress = "Unboxing Lucky Block"
            elseif TaskManager.currentTask.type == "COLLECT" then
                currentProgress = "Collecting Cash"
            elseif TaskManager.currentTask.type == "LOCK" then
                currentProgress = "Locking Base"
            elseif TaskManager.currentTask.type == "WAIT" then
                currentProgress = "Waiting farm"
            end
        elseif #TaskManager.taskQueue > 0 then
            currentProgress = "Queue Processing"
        elseif #TaskManager.pausedTasks > 0 then
            currentProgress = "Tasks Paused"
        else
            currentProgress = "Idle"
        end

        local queueInfo = {}
        local totalQueued = 0
        local totalPaused = 0

        for taskType, count in pairs(queueCounts) do
            table.insert(queueInfo, taskType .. ":" .. count)
            totalQueued = totalQueued + count
        end

        for taskType, count in pairs(pausedCounts) do
            totalPaused = totalPaused + count
        end


        local slotsInfo = CurrentUsedSlots .. "/" .. getSlots()
        currentProgress = currentProgress .. " | Slots: " .. slotsInfo

        --print("Status: " .. currentProgress)

        if not TaskManager.isProcessing and #TaskManager.taskQueue == 0 and not TaskManager.currentTask and #TaskManager.pausedTasks == 0 then
            if currentTime - lastCollectTime >= getgenv().cfg["Settings"]["Collect Time"] then
                local collectTask = createTask("COLLECT", TaskManager.priorities.COLLECT, TaskCollect, {})
                if addTask(collectTask) then
                    processTasks()
                    lastCollectTime = currentTime
                end
            else
                local waitTask = createTask("WAIT", TaskManager.priorities.WAIT, TaskWait, {})
                if addTask(waitTask) then
                    processTasks()
                end
            end
        end

        if getgenv().cfg["Settings"]["Auto Sell"] and isStorageFull() then
            local hasBuyTask = false
            for _, task in pairs(TaskManager.taskQueue) do
                if task.type == "BUY" then
                    hasBuyTask = true
                    break
                end
            end

            if hasBuyTask then
                pauseBuyTasks()
                local targetBuyInfo = nil
                for _, task in pairs(TaskManager.pausedTasks) do
                    if task.type == "BUY" and task.data.Info then
                        targetBuyInfo = task.data.Info
                        break
                    end
                end
                local sellTask = createTask("SELL", TaskManager.priorities.SELL, TaskSellAnimals,
                    { targetBuyInfo = targetBuyInfo })
                if addTask(sellTask) then
                    processTasks()
                end
            end
        end
    end
end)
