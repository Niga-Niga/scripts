
local isEnabled = false
local player = game:GetService("Players").LocalPlayer
local playergui = player:WaitForChild("PlayerGui")
local roguelikeselect = playergui:WaitForChild("RoguelikeSelect")

local function handleCardSelection()
    if not isEnabled then return end

    task.wait()
    local optionframe = roguelikeselect.Main.Main.Items:WaitForChild("OptionFrame") 
    optionframe.Active = true
    optionframe.Active = false
    task.wait(1)

    local options = roguelikeselect.Main.Main.Items:GetChildren()
    local positiontable = {}
    for _, v in pairs(options) do
        if v.Name == "OptionFrame" and v:IsA("Frame") and v:FindFirstChild("bg") then
            table.insert(positiontable, v.AbsolutePosition.X)
        end
    end

    table.sort(positiontable)

    local newoptions = {}
    for _, v in pairs(options) do
        if v.Name == "OptionFrame" and v:IsA("Frame") and v:FindFirstChild("bg") then
            if v.AbsolutePosition.X == positiontable[1] then
                table.insert(newoptions, {text = v.bg.Main.Title.TextLabel.Text, index = "1"})
            elseif v.AbsolutePosition.X == positiontable[2] then
                table.insert(newoptions, {text = v.bg.Main.Title.TextLabel.Text, index = "2"})
            elseif v.AbsolutePosition.X == positiontable[3] then
                table.insert(newoptions, {text = v.bg.Main.Title.TextLabel.Text, index = "3"})
            end
        end
    end

    -- Use PriorityCards if wave <= FocusWave (5), otherwise use normal Cards
    local priorityList = (wavenumber and wavenumber <= getgenv().FocusWave) and getgenv().PriorityCards or getgenv().Cards
    local selectedCard = nil
    local selectedIndex = nil

    -- Check each card in priority list against available options
    for _, card in ipairs(priorityList) do
        for _, option in ipairs(newoptions) do
            if option.text == card then
                selectedCard = card
                selectedIndex = option.index
                break
            end
        end
        if selectedCard then break end
    end

    -- If we found a matching card, send the selection to the server
    if selectedCard then
        task.wait(0.5)
        local args = {[1] = selectedIndex}
        game:GetService("ReplicatedStorage").endpoints.client_to_server.request_pick_card:InvokeServer(unpack(args))
    end
end

-- Connect to roguelikeselect's Enabled property
roguelikeselect:GetPropertyChangedSignal("Enabled"):Connect(function()
    if roguelikeselect.Enabled and isEnabled then
        handleCardSelection()
    end
end)
