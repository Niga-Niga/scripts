getgenv().Config = getgenv().Config or {
    ["Auto Game"] = {
        ["Rarity"] = {
            ["Enable"] = false,
            ["Name Rarity"] = {"Mythic","Secret"},
        },
        ["Name"] = {
            ["Enable"] = true,
            ["Name Brainrot"] = {"Secret Lucky Block","Festive Lucky Block"},
        }
    },
    ["Max slot"] = 10,
    ["Hold Buffer"] = 1,
    ["Clone Check Interval"] = 1,
    ["Prompt Search Radius"] = 18,
    ["Prompt Search Radius Max"] = 60,
    ["Prompt Search Time"] = 2.5,
    ["Fallback Use Any Steal Prompt"] = true
}

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

lp.CharacterAdded:Connect(function(c)
    char = c
    hum = char:WaitForChild("Humanoid")
    hrp = char:WaitForChild("HumanoidRootPart")
end)

local CFG = getgenv().Config
local Plots = workspace:WaitForChild("Plots")

local function safeWrite(n, c)
    pcall(function()
        if writefile then writefile(n, c) end
    end)
end

local DesiredNames = {}
for _,n in ipairs((CFG["Auto Game"] and CFG["Auto Game"]["Name"] and CFG["Auto Game"]["Name"]["Name Brainrot"]) or {}) do
    DesiredNames[n] = true
end

local function nameMatch(n)
    return DesiredNames[n] == true
end

local function rarityMatch(r)
    for _,v in ipairs((CFG["Auto Game"] and CFG["Auto Game"]["Rarity"] and CFG["Auto Game"]["Rarity"]["Name Rarity"]) or {}) do
        if r == v then return true end
    end
    return false
end

local function getMyPlot()
    for _,p in ipairs(Plots:GetChildren()) do
        local yb = p:FindFirstChild("PlotSign") and p.PlotSign:FindFirstChild("YourBase")
        if yb and yb.Enabled then
            return p
        end
    end
end

local myPlot = getMyPlot()
if not myPlot then return end

local function walkTo(pos)
    local t0 = os.clock()
    while os.clock() - t0 < 5 do
        if hum.FloorMaterial ~= Enum.Material.Air then break end
        task.wait(0.1)
    end

    local path
    for i = 1, 3 do
        path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
        local ok = pcall(function()
            path:ComputeAsync(hrp.Position, pos)
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            break
        end
        hum.Jump = true
        hum:MoveTo(hrp.Position + hrp.CFrame.LookVector * 5)
        task.wait(0.2)
    end

    if not path or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(pos)
        hum.MoveToFinished:Wait()
        return true
    end

    for _,wp in ipairs(path:GetWaypoints()) do
        if wp.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end
        hum:MoveTo(wp.Position)
        local reached = false
        local conn
        conn = hum.MoveToFinished:Connect(function()
            reached = true
            conn:Disconnect()
        end)
        local st = os.clock()
        while not reached do
            if os.clock() - st > 2 then
                if hrp.AssemblyLinearVelocity.Magnitude < 0.1 then
                    hum.Jump = true
                    hum:MoveTo(wp.Position)
                end
                st = os.clock()
            end
            task.wait(0.05)
        end
    end
    return true
end

local function backToBase()
    return walkTo(myPlot:GetPivot().Position)
end

local function scanOwned(plot)
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return 0,{} end
    local occ,list = 0,{}
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if spawn then
            local att = spawn:FindFirstChild("Attachment")
            local oh = att and att:FindFirstChild("AnimalOverhead")
            local dn = oh and oh:FindFirstChild("DisplayName")
            local rr = oh and oh:FindFirstChild("Rarity")
            if dn and rr then
                occ += 1
                list[#list+1] = {Name = dn.Text, Rarity = rr.Text}
            end
        end
    end
    return occ, list
end

local function scanPods(plot)
    local list = {}
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return list end
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if spawn then
            local att = spawn:FindFirstChild("Attachment")
            local oh = att and att:FindFirstChild("AnimalOverhead")
            local dn = oh and oh:FindFirstChild("DisplayName")
            local rr = oh and oh:FindFirstChild("Rarity")
            local pa = spawn:FindFirstChild("PromptAttachment")
            if dn and rr and pa then
                for _,p in ipairs(pa:GetChildren()) do
                    if p:IsA("ProximityPrompt") and p.ActionText == "Steal" then
                        list[#list+1] = {Name = dn.Text, Rarity = rr.Text, Position = spawn.Position, Prompt = p, Kind = "Pod"}
                        break
                    end
                end
            end
        end
    end
    return list
end

local function getModelPos(m)
    local ok, cf = pcall(function() return m:GetPivot() end)
    if ok and cf then return cf.Position end
    local pp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
    return pp and pp.Position
end

local function scanModels(plot)
    local list = {}
    for _,d in ipairs(plot:GetDescendants()) do
        if d:IsA("Model") and nameMatch(d.Name) then
            local pos = getModelPos(d)
            if pos then
                list[#list+1] = {Name = d.Name, Position = pos, Kind = "Model"}
            end
        end
    end
    return list
end

local function findTarget()
    for _,p in ipairs(Plots:GetChildren()) do
        if p ~= myPlot then
            for _,i in ipairs(scanPods(p)) do
                if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(i.Name) then return i end
                if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(i.Rarity) then return i end
            end
            if CFG["Auto Game"]["Name"]["Enable"] then
                local ms = scanModels(p)
                if #ms > 0 then return ms[1] end
            end
        end
    end
end

local function holdPrompt(p)
    hum:Move(Vector3.zero)
    task.wait(0.05)
    local t = (p.HoldDuration or 0) + (CFG["Hold Buffer"] or 1)
    p:InputHoldBegin()
    task.wait(t)
    p:InputHoldEnd()
end

local function holdTarget(i)
    if i.Kind == "Pod" and i.Prompt then
        pcall(function() holdPrompt(i.Prompt) end)
    end
end

local function hasDesiredInMyBase()
    local _,list = scanOwned(myPlot)
    for _,i in ipairs(list) do
        if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(i.Name) then return true end
        if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(i.Rarity) then return true end
    end
    return false
end

local ROLE_IS_MAIN = not hasDesiredInMyBase()

if not ROLE_IS_MAIN then
    while true do
        if not hasDesiredInMyBase() then
            print("het brainrot")
            safeWrite(lp.Name..".txt","Completed-Clone")
            break
        end
        task.wait(CFG["Clone Check Interval"] or 1)
    end
    return
end

while true do
    local occ = select(1, scanOwned(myPlot))
    if occ >= (CFG["Max slot"] or 10) then
        print("max slot")
        safeWrite(lp.Name..".txt","Completed-Main")
        break
    end

    local target = findTarget()
    if not target then
        print("ko co target")
        safeWrite(lp.Name..".txt","Completed-Main")
        break
    end

    walkTo(target.Position)
    task.wait(0.15)
    holdTarget(target)
    task.wait(0.2)
    backToBase()
    task.wait(0.25)
end
