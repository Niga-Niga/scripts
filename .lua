getgenv().InterfaceName = "FarmingHub"

local Starlight = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/starlight"))()
local NebulaIcons = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/nebula-icon-library-loader"))()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer

local FieldsFolder = workspace.Zones.Fields
local TokensFolder = workspace.Tokens.Default
local AnthillsFolder = workspace.Anthills

local State = {
    Field = nil,
    AutoFarm = false,
    AutoDig = false,
    AutoConvert = false,
    Converting = false
}

local function getChar()
    local c = lp.Character or lp.CharacterAdded:Wait()
    return c, c:WaitForChild("HumanoidRootPart")
end

local function tweenTo(pos, speed)
    local _, hrp = getChar()
    local d = (hrp.Position - pos).Magnitude
    local t = d / (speed or 80)
    local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = CFrame.new(pos)})
    tw:Play()
    tw.Completed:Wait()
end

local function getBounds(model)
    if not model then return end
    return model:GetBoundingBox()
end

local function randomInBounds(cf, size)
    local h = size * 0.5
    local x = (math.random() * 2 - 1) * h.X
    local z = (math.random() * 2 - 1) * h.Z
    return cf:PointToWorldSpace(Vector3.new(x, h.Y + 6, z))
end

local function inside(point, cf, size)
    local p = cf:PointToObjectSpace(point)
    local h = size * 0.5
    return math.abs(p.X) <= h.X and math.abs(p.Z) <= h.Z
end

local function getPollen()
    local gui = lp.PlayerGui.selfView.Metters.Pollen.Text
    local s = tostring(gui.Text or "")
    local a,b = s:match("(%d+)%s*/%s*(%d+)")
    return tonumber(a) or 0, tonumber(b) or 0
end

local function myAnthill()
    for _,a in ipairs(AnthillsFolder:GetChildren()) do
        local p = a:FindFirstChild("Platform")
        if p and p:FindFirstChild("Owner") and p.Owner.Value == lp.Name then
            return a
        end
    end
end

task.spawn(function()
    while task.wait(0.08) do
        if State.AutoDig and not State.Converting then
            ReplicatedStorage.Events.Server_Event:FireServer("UseTool",2)
        end
    end
end)

task.spawn(function()
    while task.wait(0.25) do
        if State.AutoConvert and not State.Converting then
            local c,m = getPollen()
            if m > 0 and c >= m then
                State.Converting = true
                local a = myAnthill()
                if a then
                    tweenTo(a:GetBoundingBox().Position + Vector3.new(0,5,0),120)
                end
                repeat task.wait(0.3) c,m = getPollen() until c <= 0
                if State.Field then
                    local f = FieldsFolder:FindFirstChild(State.Field)
                    if f then
                        tweenTo(f:GetBoundingBox().Position + Vector3.new(0,6,0),120)
                    end
                end
                State.Converting = false
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if State.AutoFarm and State.Field and not State.Converting then
            local f = FieldsFolder:FindFirstChild(State.Field)
            if f then
                local cf,size = getBounds(f)
                tweenTo(cf.Position + Vector3.new(0,6,0),120)
                for _=1,6 do
                    if not State.AutoFarm or State.Converting then break end
                    tweenTo(randomInBounds(cf,size),90)
                    for _,t in ipairs(TokensFolder:GetChildren()) do
                        local p = t:FindFirstChildWhichIsA("BasePart",true)
                        if p and inside(p.Position,cf,size) then
                            tweenTo(p.Position + Vector3.new(0,2,0),140)
                        end
                    end
                end
            end
        end
    end
end)

local Window = Starlight:CreateWindow({
    Name = "Field Farmer",
    Subtitle = "Starlight",
    ConfigurationSettings = {FolderName = "FieldFarmer"}
})

local Tabs = Window:CreateTabSection("Main")
local Tab = Tabs:CreateTab({Name="Farming",Icon=NebulaIcons:GetIcon("agriculture","Material"),Columns=2})

local Left = Tab:CreateGroupbox({Name="Farm",Column=1})
local Right = Tab:CreateGroupbox({Name="Status",Column=2})

local function fieldList()
    local t={}
    for _,f in ipairs(FieldsFolder:GetChildren()) do
        table.insert(t,f.Name)
    end
    table.sort(t)
    return t
end

local btnField = Left:CreateButton({Name="Select Field"})
local dd = btnField:AddDropdown({
    Options = fieldList(),
    Callback = function(v)
        State.Field = typeof(v)=="table" and v[1] or v
    end
})

Left:CreateButton({
    Name="Auto Farm: OFF",
    Callback=function(b)
        State.AutoFarm=not State.AutoFarm
        b:Set({Name="Auto Farm: "..(State.AutoFarm and "ON" or "OFF")})
    end
})

Left:CreateButton({
    Name="Auto Dig: OFF",
    Callback=function(b)
        State.AutoDig=not State.AutoDig
        b:Set({Name="Auto Dig: "..(State.AutoDig and "ON" or "OFF")})
    end
})

Left:CreateButton({
    Name="Auto Convert: OFF",
    Callback=function(b)
        State.AutoConvert=not State.AutoConvert
        b:Set({Name="Auto Convert: "..(State.AutoConvert and "ON" or "OFF")})
    end
})
