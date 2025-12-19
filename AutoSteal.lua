local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")

getgenv().LUCKY_BLOCK_CONFIG = getgenv().LUCKY_BLOCK_CONFIG or {
    ["Secret Lucky Block"] = false,
    ["Los Lucky Blocks"] = false,
    ["Admin Lucky Block"] = false,
    ["Spooky Lucky Block"] = false,
    ["La Grande Combinasion"] = false,
    ["Los Taco Blocks"] = false,
    ["Festive Lucky Block"] = true,
}

getgenv().WEBHOOK_URL = getgenv().WEBHOOK_URL or ""

if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(5)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local spawnCFrame = humanoidRootPart.CFrame
local MIN_DISTANCE = 65
local collecting = false
local collectedItems = {}
local blacklist = {}
local characterDied = false
local lastPath = nil

local function waitForLanding()
    local t = 0
    while t < 30 do
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            return true
        end
        task.wait(0.5)
        t += 0.5
    end
    return false
end

waitForLanding()

do
    local start = tick()
    while tick() - start < 30 do
        if workspace:FindFirstChild("Plots") then
            break
        end
        task.wait(0.1)
    end
end

local function setupCharacterMonitor()
    characterDied = false
    humanoid.Died:Connect(function()
        characterDied = true
    end)
end

setupCharacterMonitor()

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    task.wait(1)
    waitForLanding()
    spawnCFrame = humanoidRootPart.CFrame
    setupCharacterMonitor()
    task.wait(0.5)
    characterDied = false
    collecting = false
    lastPath = nil
end)

local function enabledNameSet()
    local set = {}
    for name, en in pairs(getgenv().LUCKY_BLOCK_CONFIG) do
        if en then
            set[name] = true
        end
    end
    return set
end

local function getOwnerName(plot)
    local owner = plot:FindFirstChild("Owner")
    if owner and owner.Value and owner.Value:IsA("Player") then
        return owner.Value.DisplayName or owner.Value.Name
    end
    local sign = plot:FindFirstChild("PlotSign")
    local sg = sign and sign:FindFirstChild("SurfaceGui")
    local fr = sg and sg:FindFirstChild("Frame")
    local lbl = fr and fr:FindFirstChild("TextLabel")
    if lbl and lbl.Text and lbl.Text ~= "" then
        return lbl.Text
    end
    return "Unknown"
end

local function hasAncestorNameContaining(inst, needle)
    needle = needle:lower()
    local p = inst
    while p do
        if p.Name:lower():find(needle, 1, true) then
            return true
        end
        p = p.Parent
    end
    return false
end

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    local myLabel = player.DisplayName .. "'s Base"
    for _, plot in ipairs(plots:GetChildren()) do
        if getOwnerName(plot) == myLabel then
            return plot
        end
    end
    return nil
end

local function countOwnedConfigPets()
    local myPlot = getMyPlot()
    if not myPlot then
        return 0
    end
    local enabled = enabledNameSet()
    local tong = 0
    for _, d in ipairs(myPlot:GetDescendants()) do
        if d.Name == "DisplayName" and (d:IsA("TextLabel") or d:IsA("StringValue")) then
            if hasAncestorNameContaining(d, "animaloverhead") then
                local petName = d:IsA("TextLabel") and d.Text or d.Value
                if petName and petName ~= "" and enabled[petName] then
                    tong += 1
                end
            end
        end
    end
    return tong
end

local function findTargetItem()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil, nil
    end

    local enabled = enabledNameSet()

    for _, plot in ipairs(plots:GetChildren()) do
        for _, obj in ipairs(plot:GetChildren()) do
            if enabled[obj.Name] and not collectedItems[obj] and not blacklist[obj] then
                local itemPos
                if obj:IsA("Model") then
                    itemPos = obj:GetPivot().Position
                elseif obj:IsA("BasePart") then
                    itemPos = obj.Position
                else
                    continue
                end

                local distance = (itemPos - spawnCFrame.Position).Magnitude
                if distance >= MIN_DISTANCE then
                    return obj, itemPos
                end
            end
        end
    end

    return nil, nil
end

local function getDistance2D(v1, v2)
    return (Vector3.new(v1.X, 0, v1.Z) - Vector3.new(v2.X, 0, v2.Z)).Magnitude
end

local function walkTo(targetPos, useSavedPath)
    local waypoints

    if useSavedPath and lastPath then
        waypoints = {}
        for i = #lastPath, 1, -1 do
            waypoints[#waypoints + 1] = lastPath[i]
        end
    else
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = 8,
            Costs = { Water = math.huge, Danger = math.huge },
        })

        local ok = pcall(function()
            path:ComputeAsync(humanoidRootPart.Position, targetPos)
        end)

        if not ok or path.Status ~= Enum.PathStatus.Success then
            return false
        end

        waypoints = path:GetWaypoints()
        lastPath = waypoints
        if not waypoints or #waypoints == 0 then
            return false
        end
    end

    for _, wp in ipairs(waypoints) do
        if characterDied then
            return false
        end

        if wp.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        humanoid:MoveTo(wp.Position)

        local reached = false
        local conn = humanoid.MoveToFinished:Connect(function()
            reached = true
        end)

        local t0 = tick()
        local tStuck = tick()

        while not reached and getDistance2D(humanoidRootPart.Position, wp.Position) > 4 do
            if characterDied then
                if conn then conn:Disconnect() end
                return false
            end

            if tick() - tStuck > 1.5 then
                local vel = humanoidRootPart.AssemblyLinearVelocity.Magnitude
                if vel < 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air then
                    humanoid.Jump = true
                    humanoid:MoveTo(wp.Position)
                end
                tStuck = tick()
            end

            if tick() - t0 > 10 then
                if conn then conn:Disconnect() end
                return false
            end

            task.wait(0.01)
        end

        if conn then conn:Disconnect() end
    end

    return true
end

local function collect()
    collecting = true
    humanoid:Move(Vector3.new(0, 0, 0))
    task.wait(0.05)

    local cam = workspace.CurrentCamera
    local original = cam.CFrame
    cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(-89), 0, 0)
    task.wait(0.02)

    local vim = game:GetService("VirtualInputManager")
    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(1.6)
    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)

    cam.CFrame = original
    task.wait(0.2)
    collecting = false
end

local function sendWebhook(itemName)
    local url = getgenv().WEBHOOK_URL
    if not url or url == "" or url == "YOUR_WEBHOOK_URL_HERE" then
        return
    end

    task.spawn(function()
        pcall(function()
            local data = {
                embeds = {{
                    title = "WTHH",
                    description = string.format("**%s**", itemName),
                    color = 16744192,
                    fields = {
                        { name = "🔸 Rarity:", value = "Secret", inline = false },
                        { name = "💰 Price:", value = "$750M", inline = false },
                        { name = "👤", value = player.Name, inline = false },
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
                }},
            }
            local jsonData = HttpService:JSONEncode(data)
            request({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData,
            })
        end)
    end)
end

local function writeDone(tag)
    writefile(player.Name .. ".txt", tag)
    game:Shutdown()
    task.wait(60)
end

local ROLE_IS_CLONE = (countOwnedConfigPets() > 0)

if ROLE_IS_CLONE then
    while true do
        task.wait(1)
        if characterDied then
            task.wait(1)
        end
        if countOwnedConfigPets() <= 0 then
            writeDone("Completed-Clone")
        end
    end
else
    spawn(function()
        while task.wait(1) do
            pcall(function()
                if countOwnedConfigPets() >= 10 then
                    writeDone("Completed-Main")
                end
            end)
        end
    end)

    spawn(function()
        while true do
            task.wait(0.1)
            if not collecting and not characterDied then
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.01)
                    vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end
        end
    end)

    while true do
        if characterDied then
            task.wait(1)
            continue
        end

        if countOwnedConfigPets() >= 10 then
            writeDone("Completed-Main")
        end

        local item, itemPos = findTargetItem()
        if not item then
            task.wait(3)
            item, itemPos = findTargetItem()
        end

        if not item then
            task.wait(2)
            continue
        end

        collectedItems[item] = true

        if not item.Parent then
            collectedItems[item] = nil
            task.wait(0.2)
            continue
        end

        local ok = walkTo(itemPos, false)
        if not ok or characterDied then
            blacklist[item] = true
            collectedItems[item] = nil
            task.wait(0.3)
            continue
        end

        if not item.Parent then
            blacklist[item] = true
            collectedItems[item] = nil
            task.wait(0.2)
            continue
        end

        collect()
        sendWebhook(item.Name)

        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
            vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            task.wait(0.03)
            vim:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
            vim:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
            task.wait(0.03)
            vim:SendKeyEvent(true, Enum.KeyCode.Three, false, game)
            vim:SendKeyEvent(false, Enum.KeyCode.Three, false, game)
            task.wait(0.03)
            vim:SendKeyEvent(true, Enum.KeyCode.Four, false, game)
            vim:SendKeyEvent(false, Enum.KeyCode.Four, false, game)
        end)

        ok = walkTo(spawnCFrame.Position, true)
        if not ok or characterDied then
            task.wait(1)
            continue
        end

        lastPath = nil
        task.wait(0.5)
    end
end
