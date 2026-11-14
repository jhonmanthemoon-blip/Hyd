--// KISHOU AUTO LOADER: downloads the 20 small sheets + audio into workspace/kishou_xmas (only what is missing), then plays the video
--// Run it with:
--// loadstring(game:HttpGet("https://raw.githubusercontent.com/jhonmanthemoon-blip/Hyd/main/kishou_xmas_sheets.lua"))()
local DL_REPO     = "jhonmanthemoon-blip/Hyd"
local DL_BRANCH   = "main"
-- it tries the main folder of the repo first, then a folder called xmas, then kishou_xmas, so any upload layout works
local DL_BASES = {
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/",
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/xmas/",
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/kishou_xmas/",
}
local DL_FOLDER   = "kishou_xmas"
local DL_SHEETS   = 20     -- 20 small sheets, 15 frames each (the last one has 3)
local FRAMES_PER_SHEET = 15
local TOTAL_FRAMES = 288
-- file names: s01.jpg ... s20.jpg
local function sheetName(i)
    return string.format("s%02d.jpg", i)
end
local DL_THREADS  = 8      -- downloads at the same time (lower it to 4 if GitHub rate-limits you)

do
    local Players = game:GetService("Players")

    local function fetch(url)
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and #body > 0 then return body end
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if req then
            local ok2, res = pcall(req, {Url = url, Method = "GET"})
            if ok2 and res and res.StatusCode == 200 and type(res.Body) == "string" and #res.Body > 0 then
                return res.Body
            end
        end
        return nil
    end

    -- reject "404: Not Found" pages and broken downloads
    local function valid(name, body)
        if #body < 200 then return false end
        if name:sub(-4) == ".jpg" then
            return body:byte(1) == 0xFF and body:byte(2) == 0xD8
        end
        return true
    end

    local function haveFile(path)
        if not isfile(path) then return false end
        local ok, data = pcall(readfile, path)
        return ok and type(data) == "string" and #data >= 200
    end

    if not isfolder(DL_FOLDER) then makefolder(DL_FOLDER) end

    local names = {"audio.mp3"}
    for i = 1, DL_SHEETS do
        table.insert(names, sheetName(i))
    end

    local missing = {}
    for _, name in ipairs(names) do
        if not haveFile(DL_FOLDER .. "/" .. name) then table.insert(missing, name) end
    end

    if #missing > 0 then
        -- small progress screen
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
        local old = playerGui:FindFirstChild("KishouDownload")
        if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "KishouDownload"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999999
        gui.Parent = playerGui

        local bgf = Instance.new("Frame")
        bgf.Size = UDim2.fromScale(1, 1)
        bgf.BackgroundColor3 = Color3.new(0, 0, 0)
        bgf.BorderSizePixel = 0
        bgf.Parent = gui

        local label = Instance.new("TextLabel")
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, 0.45)
        label.Size = UDim2.fromOffset(500, 30)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 20
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = "Downloading video... 0 / " .. #missing
        label.Parent = bgf

        local track = Instance.new("Frame")
        track.AnchorPoint = Vector2.new(0.5, 0.5)
        track.Position = UDim2.fromScale(0.5, 0.52)
        track.Size = UDim2.fromOffset(360, 8)
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        track.BorderSizePixel = 0
        track.Parent = bgf
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        fill.BorderSizePixel = 0
        fill.Parent = track

        local nextIndex, done, running = 0, 0, DL_THREADS
        local failed = {}

        local function worker()
            while true do
                nextIndex += 1
                local name = missing[nextIndex]
                if not name then return end
                local ok = false
                for attempt = 1, 3 do
                    for _, base in ipairs(DL_BASES) do
                        local body = fetch(base .. name)
                        if body and valid(name, body) then
                            writefile(DL_FOLDER .. "/" .. name, body)
                            ok = true
                            -- remember the base that worked so the next files try it first
                            if base ~= DL_BASES[1] then local at = table.find(DL_BASES, base); if at then table.remove(DL_BASES, at); table.insert(DL_BASES, 1, base) end end
                            break
                        end
                    end
                    if ok then break end
                    task.wait(0.3 * attempt)
                end
                if not ok then
                    if name == "audio.mp3" then
                        warn("[KISHOU] audio.mp3 not found in the repo, playing without sound")
                    else
                        table.insert(failed, name)
                    end
                end
                done += 1
                label.Text = "Downloading video... " .. done .. " / " .. #missing
                fill.Size = UDim2.fromScale(done / #missing, 1)
            end
        end

        for _ = 1, DL_THREADS do
            task.spawn(function()
                worker()
                running -= 1
            end)
        end
        while running > 0 do task.wait(0.1) end

        if #failed > 0 then
            warn("[KISHOU] could not download: " .. table.concat(failed, ", ", 1, math.min(#failed, 10)) .. (#failed > 10 and " ..." or ""))
            warn("[KISHOU] check DL_REPO and that your repo is public and has the files")
            label.TextColor3 = Color3.fromRGB(255, 90, 90)
            label.Text = "Download failed (" .. #failed .. " files) - see console"
            task.wait(5)
            gui:Destroy()
            return
        end
        gui:Destroy()
    end
end

--// CONFIG (20 small sprite sheets, 3 columns x 5 rows = 15 frames each, 12 FPS)
local FOLDER       = "kishou_xmas/"  -- workspace folder that holds the sheets and audio.mp3
local FRAME_COUNT  = 288
local FPS          = 12
local COLS         = 3
local ROWS         = 5
local PER_SHEET    = COLS * ROWS     -- 15
local LOOP         = false
local AUDIO        = true            -- plays audio.mp3 and keeps the video in sync with it

--// SERVICES
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local SoundService = game:GetService("SoundService")

--// GUI (full screen)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SheetPlayerKishou")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SheetPlayerKishou"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BorderSizePixel = 0
bg.Parent = gui

local FULL   = UDim2.fromScale(1, 1)
local HIDDEN = UDim2.fromOffset(4, 4)

-- two labels: one shows the current sheet, the other already loads the next sheet
local labels = {}
for i = 1, 2 do
    local l = Instance.new("ImageLabel")
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Position = UDim2.fromScale(0.5, 0.5)
    l.Size = HIDDEN
    l.ZIndex = 1
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.ScaleType = Enum.ScaleType.Stretch
    l.Parent = bg
    labels[i] = l
end

--// SKIP BUTTON
local close = Instance.new("TextButton")
close.Name = "Skip"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -18, 0, 18)
close.Size = UDim2.fromOffset(112, 42)
close.AutoButtonColor = true
close.BackgroundColor3 = Color3.fromRGB(35, 18, 65)
close.BackgroundTransparency = 0.08
close.BorderSizePixel = 0
close.Text = "SKIP  \194\187"
close.Font = Enum.Font.GothamBold
close.TextSize = 17
close.TextColor3 = Color3.new(1, 1, 1)
close.ZIndex = 10
close.Parent = bg

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 12)
skipCorner.Parent = close

--// SHEET LOADING
local SHEET_COUNT = math.ceil(FRAME_COUNT / PER_SHEET)
local assets = {}        -- sheet number -> custom asset id
local slotSheet = {1, 1} -- which sheet each label holds (0 = none)
slotSheet[1], slotSheet[2] = 0, 0

local function sheetAsset(n)
    if assets[n] then return assets[n] end
    local path = FOLDER .. sheetName(n)
    if isfile and not isfile(path) then
        warn("MISSING FILE (not in your executor workspace): " .. path)
        return nil
    end
    local ok, asset = pcall(getcustomasset, path)
    if ok and asset and asset ~= "" then
        assets[n] = asset
        return asset
    end
    warn("Failed to load " .. path .. ": " .. tostring(asset))
    return nil
end

local function slotOf(n) return (n % 2) + 1 end

local function loadSheet(n)
    if n < 1 or n > SHEET_COUNT then return end
    local slot = slotOf(n)
    if slotSheet[slot] == n then return end
    local asset = sheetAsset(n)
    if asset then
        labels[slot].Image = asset
        slotSheet[slot] = n
    end
end

local function sheetReady(n)
    local slot = slotOf(n)
    local l = labels[slot]
    return slotSheet[slot] == n and (l.IsLoaded or l.ContentImageSize.X > 0)
end

-- load the first two sheets before starting so playback never waits (max 4 seconds)
loadSheet(1)
loadSheet(2)
local t0 = os.clock()
while os.clock() - t0 < 4 and not sheetReady(1) do task.wait() end

--// AUDIO
local sound
if AUDIO then
    local ok, asset = pcall(getcustomasset, FOLDER .. "audio.mp3")
    if ok and asset and asset ~= "" then
        sound = Instance.new("Sound")
        sound.SoundId = asset
        sound.Volume = 1
        sound.Parent = SoundService
        local t1 = os.clock()
        while not sound.IsLoaded and os.clock() - t1 < 2 do task.wait() end
        if sound.IsLoaded then
            sound:Play()
        else
            warn("audio.mp3 did not load, playing without sound")
            sound:Destroy()
            sound = nil
        end
    else
        warn("Could not load " .. FOLDER .. "audio.mp3")
    end
end

--// PLAYBACK
local frame = 0
local shownSlot
local conn

local function stop()
    if conn then conn:Disconnect() end
    if sound then sound:Stop() sound:Destroy() end
    gui:Destroy()
end
close.MouseButton1Click:Connect(stop)

conn = RunService.RenderStepped:Connect(function(dt)
    frame += math.min(dt, 0.1) * FPS

    -- the audio is the master clock, so picture and sound stay in sync
    if sound and sound.IsPlaying then
        local audioFrame = sound.TimePosition * FPS
        if math.abs(frame - audioFrame) > 3 then
            frame = audioFrame
        end
    end

    local f = math.floor(frame)
    if f >= FRAME_COUNT then
        if LOOP then
            frame, f = 0, 0
            if sound then sound.TimePosition = 0 end
        else
            stop()
            return
        end
    end

    local sheet = math.floor(f / PER_SHEET) + 1
    local idx   = f % PER_SHEET
    local col   = idx % COLS
    local row   = math.floor(idx / COLS)

    loadSheet(sheet)
    -- start loading the next sheet halfway through this one
    if idx >= 3 then loadSheet(sheet + 1) end

    local slot = slotOf(sheet)
    local l = labels[slot]

    if slotSheet[slot] == sheet and sheetReady(sheet) then
        -- cut out the right frame from the sheet (works for any sheet size)
        local size = l.ContentImageSize
        local tw, th = size.X / COLS, size.Y / ROWS
        l.ImageRectSize = Vector2.new(tw, th)
        l.ImageRectOffset = Vector2.new(col * tw, row * th)

        if shownSlot ~= slot then
            l.ZIndex = 2
            l.Size = FULL
            if shownSlot then
                labels[shownSlot].Size = HIDDEN
                labels[shownSlot].ZIndex = 1
            end
            shownSlot = slot
        end
    end
end)
