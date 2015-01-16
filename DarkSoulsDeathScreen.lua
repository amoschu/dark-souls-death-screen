
local print, strsplit, select, tonumber, tostring, wipe, remove
    = print, strsplit, select, tonumber, tostring, wipe, table.remove
local CreateFrame, GetSpellInfo, PlaySoundFile, UIParent, UnitBuff, C_Timer
    = CreateFrame, GetSpellInfo, PlaySoundFile, UIParent, UnitBuff, C_Timer
    
local me = ...

local MEDIA_PATH = [[Interface\Addons\DarkSoulsDeathScreen\media\]]
local YOU_DIED = MEDIA_PATH .. [[YOUDIED.tga]]
local THANKS_OBAMA = MEDIA_PATH .. [[THANKSOBAMA.tga]]
local YOU_DIED_SOUND = MEDIA_PATH .. [[YOUDIED.ogg]]
local BONFIRE_LIT = MEDIA_PATH .. [[BONFIRELIT.tga]]
local BONFIRE_LIT_BLUR = MEDIA_PATH .. [[BONFIRELIT_BLUR.tga]]
local BONFIRE_LIT_SOUND = {
    [1] = MEDIA_PATH .. [[BONFIRELIT.ogg]],
    [2] = MEDIA_PATH .. [[BONFIRELIT2.ogg]],
}
local YOU_DIED_WIDTH_HEIGHT_RATIO = 0.32 -- width / height
local BONFIRE_WIDTH_HEIGHT_RATIO = 0.36 -- w / h

local BG_END_ALPHA = 0.75 -- [0,1] alpha
local TEXT_END_ALPHA = 0.5 -- [0,1] alpha
local BONFIRE_TEXT_END_ALPHA = 0.8 -- [0,1] alpha
local BONFIRE_BLUR_TEXT_END_ALPHA = 0.63 -- [0,1] alpha
local TEXT_SHOW_END_SCALE = 1.25 -- scale factor
local BONFIRE_START_SCALE = 1.15 -- scale factor
local BONFIRE_FLARE_SCALE_X = 1.1 -- scale factor
local BONFIRE_FLARE_SCALE_Y = 1.065 -- scale factor
local BONFIRE_FLARE_OUT_TIME = 0.22 -- seconds
local BONFIRE_FLARE_IN_TIME = 0.6 -- seconds
local TEXT_FADE_IN_DURATION = 0.15 -- seconds
local FADE_IN_TIME = 0.45 -- in seconds
local FADE_OUT_TIME = 0.3 -- in seconds
local FADE_OUT_DELAY = 0.4 -- in seconds
local TEXT_END_DELAY = 0.5 -- in seconds
local BONFIRE_END_DELAY = 0.05 -- in seconds
local BACKGROUND_GRADIENT_PERCENT = 0.15 -- of background height
local BACKGROUND_HEIGHT_PERCENT = 0.21 -- of screen height
local TEXT_HEIGHT_PERCENT = 0.18 -- of screen height

local ScreenWidth, ScreenHeight = UIParent:GetSize()
local db

local ADDON_COLOR = "ff999999"
local function Print(msg)
    print(("|c%sDSDS|r: %s"):format(ADDON_COLOR, msg))
end

local function UnrecognizedVersion()
    local msg = "[|cffFF0000Error|r] Unrecognized version flag, \"%s\"!"
    Print(msg:format(tostring(db.version)))
    
    -- just correct the issue, I guess?
    db.version = 1
end

-- ------------------------------------------------------------------
-- Init
-- ------------------------------------------------------------------
local type = type
local function OnEvent(self, event, ...)
    if type(self[event]) == "function" then
        self[event](self, event, ...)
    end
end

local DSFrame = CreateFrame("Frame") -- helper frame
DSFrame:SetScript("OnEvent", OnEvent)

-- ----------
-- BACKGROUND
-- ----------

local UPDATE_TIME = 0.04
local function BGFadeIn(self, e)
    self.elapsed = (self.elapsed or 0) + e
    local progress = self.elapsed / FADE_IN_TIME
    if progress <= 1 then
        self:SetAlpha(progress * BG_END_ALPHA)
    else
        self:SetScript("OnUpdate", nil)
        self.elapsed = nil
    end
end

local function BGFadeOut(self, e)
    self.elapsed = (self.elapsed or 0) + e
    local progress = 1 - (self.elapsed / FADE_OUT_TIME)
    if progress >= 0 then
        self:SetAlpha(progress * BG_END_ALPHA)
    else
        self:SetScript("OnUpdate", nil)
        self.elapsed = nil
        -- force the background to hide at the end of the animation
        self:SetAlpha(0)
    end
end

local background = {} -- bg frames

local SpawnBackground = {
    [1] = function()
        local frame = background[1]
        if not frame then
            frame = CreateFrame("Frame")
            background[1] = frame
            
            frame:SetPoint("CENTER", 0, 0)
            frame:SetFrameStrata("MEDIUM")
            
            local bg = frame:CreateTexture()
            bg:SetTexture(0, 0, 0)
            frame.bg = bg
            
            local top = frame:CreateTexture()
            top:SetTexture(0, 0, 0)
            top:SetGradientAlpha("VERTICAL", 0, 0, 0, 1, 0, 0, 0, 0) -- orientation, startR, startG, startB, startA, endR, endG, endB, endA (start = bottom, end = top)
            frame.top = top
            
            local btm = frame:CreateTexture()
            btm:SetTexture(0, 0, 0)
            btm:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0, 0, 0, 1)
            frame.btm = btm
        end
        
        local height = BACKGROUND_HEIGHT_PERCENT * ScreenHeight
        local bgHeight = BACKGROUND_GRADIENT_PERCENT * height
        frame:SetSize(ScreenWidth, height)
        
        -- size the background's constituent components
        frame.top:ClearAllPoints()
        frame.top:SetPoint("TOPLEFT", 0, 0)
        frame.top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -bgHeight)
        
        frame.bg:ClearAllPoints()
        frame.bg:SetPoint("TOPLEFT", 0, -bgHeight)
        frame.bg:SetPoint("BOTTOMRIGHT", 0, bgHeight)
        
        frame.btm:ClearAllPoints()
        frame.btm:SetPoint("BOTTOMLEFT", 0, 0)
        frame.btm:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, bgHeight)
        
        frame:SetAlpha(0)
        -- ideally this would use Animations, but they seem to set the alpha on all elements in the region which destroys the alpha gradient
        -- ie, the background becomes just a solid-color rectangle
        frame:SetScript("OnUpdate", BGFadeIn)
    end,
    
    [2] = function()
        local frame = background[2]
        if not frame then
            frame = CreatFrame("Frame")
            background[2] = frame
            
            --[[
            bg positioned 60% from top of screen
            --]]
        end
   end,
}

local function HideBackgroundAfterDelay(self, e)
    self.elapsed = (self.elapsed or 0) + e
    if self.elapsed > FADE_OUT_DELAY then
        local bg = background[db.version or 0]
        if bg then
            bg:SetScript("OnUpdate", BGFadeOut)
        else
            UnrecognizedVersion()
        end
        self:SetScript("OnUpdate", nil)
        self.elapsed = nil
    end
end

-- --------
-- YOU DIED
-- --------

local youDied = {} -- frames

local YouDied = {
    [1] = function()
        local frame = youDied[1]
        if not frame then
            frame = CreateFrame("Frame")
            youDied[1] = frame
            
            frame:SetPoint("CENTER", 0, 0)
            frame:SetFrameStrata("HIGH")
            
            -- "YOU DIED"
            frame.tex = frame:CreateTexture()
            frame.tex:SetAllPoints()
            
            -- intial animation (fade-in + zoom)
            local show = frame:CreateAnimationGroup()
            local fadein = show:CreateAnimation("Alpha")
            fadein:SetChange(TEXT_END_ALPHA)
            fadein:SetOrder(1)
            fadein:SetStartDelay(FADE_IN_TIME)
            fadein:SetDuration(FADE_IN_TIME + TEXT_FADE_IN_DURATION)
            fadein:SetEndDelay(TEXT_END_DELAY)
            local zoom = show:CreateAnimation("Scale")
            zoom:SetOrigin("CENTER", 0, 0)
            zoom:SetScale(TEXT_SHOW_END_SCALE, TEXT_SHOW_END_SCALE)
            zoom:SetOrder(1)
            zoom:SetDuration(1.3)
            zoom:SetEndDelay(TEXT_END_DELAY)
            
            -- hide animation (fade-out + slower zoom)
            local hide = frame:CreateAnimationGroup()
            local fadeout = hide:CreateAnimation("Alpha")
            fadeout:SetChange(-1)
            fadeout:SetOrder(1)
            fadeout:SetSmoothing("IN_OUT")
            fadeout:SetStartDelay(FADE_OUT_DELAY)
            fadeout:SetDuration(FADE_OUT_TIME + FADE_OUT_DELAY)
            local zoom = hide:CreateAnimation("Scale")
            zoom:SetOrigin("CENTER", 0, 0)
            zoom:SetScale(1.07, 1.038)
            zoom:SetOrder(1)
            zoom:SetDuration(FADE_OUT_TIME + FADE_OUT_DELAY + 0.3)
            
            show:SetScript("OnFinished", function(self)
                -- hide once the delay finishes
                frame:SetAlpha(TEXT_END_ALPHA)
                frame:SetScale(TEXT_SHOW_END_SCALE)
                fadeout:SetScript("OnUpdate", HideBackgroundAfterDelay)
                hide:Play()
            end)
            hide:SetScript("OnUpdate", function(self, e)
                
            end)
            hide:SetScript("OnFinished", function(self)
                -- reset to initial state
                frame:SetAlpha(0)
                frame:SetScale(1)
            end)
            frame.show = show
        end
        
        if frame.tex:GetTexture() ~= db.tex then
            frame.tex:SetTexture(db.tex)
        end
        
        local height = TEXT_HEIGHT_PERCENT * ScreenHeight
        frame:SetSize(height / YOU_DIED_WIDTH_HEIGHT_RATIO, height)
        frame:SetAlpha(0)
        frame:SetScale(1)
        frame.show:Play()
    end,

    [2] = function()
        local frame = youDied[1]
        if not frame then
            frame = CreateFrame("Frame")
            youDied[2] = frame

        --[[
        https://www.youtube.com/watch?v=KtLrVSrRruU&t=24m34s
        i dont think wow's animation system can do the text reveal that ds2 does
        need to set texcoords in an OnUpdate handler, i think..
        
        1. bg fade in
        2. (bg done? maybe like 75%+) YOU DIED reveal + scale
        3. all fade out (~0.075s? -- very quick)
        --]]
        end
    end,
} -- you died animations

-- -----------
-- BONFIRE LIT
-- -----------

local bonfireIsLighting -- anim is running flag
local bonfireLit = {} -- frames

local BonfireLit = { -- bonfire lit animations
    [1] = function()
        local frame = bonfireLit[1]
        if not frame then
            -- static bonfire lit
            frame = CreateFrame("Frame")
            bonfireLit[1] = frame
            
            frame:SetPoint("CENTER", 0, 0)
            frame:SetFrameStrata("HIGH")
            
            -- "BONFIRE LIT"
            frame.tex = frame:CreateTexture()
            frame.tex:SetAllPoints()
            frame.tex:SetTexture(BONFIRE_LIT)
            
            -- intial animation (fade-in)
            local show = frame:CreateAnimationGroup()
            local fadein = show:CreateAnimation("Alpha")
            fadein:SetChange(BONFIRE_TEXT_END_ALPHA)
            fadein:SetOrder(1)
            fadein:SetDuration(FADE_IN_TIME + TEXT_FADE_IN_DURATION)
            fadein:SetEndDelay(TEXT_END_DELAY)
            
            -- hide animation (fade-out)
            local hide = frame:CreateAnimationGroup()
            local fadeout = hide:CreateAnimation("Alpha")
            fadeout:SetChange(-1)
            fadeout:SetOrder(1)
            fadeout:SetSmoothing("IN_OUT")
            fadeout:SetStartDelay(FADE_OUT_DELAY)
            fadeout:SetDuration(FADE_OUT_TIME + FADE_OUT_DELAY)
            
            show:SetScript("OnFinished", function(self)
                -- hide once the delay finishes
                frame:SetAlpha(BONFIRE_TEXT_END_ALPHA)
            end)
            hide:SetScript("OnFinished", function(self)
                -- reset to initial state
                frame:SetAlpha(0)
            end)
            frame.show = show
            frame.hide = hide
            
            --
            --
            -- animated/blurred bonfire lit
            frame.animated = CreateFrame("Frame")
            frame.animated:SetPoint("CENTER", 0, 0)
            frame.animated:SetFrameStrata("HIGH")
        
            -- animated "BONFIRE LIT"
            frame.animated.tex = frame.animated:CreateTexture()
            frame.animated.tex:SetAllPoints()
            frame.animated.tex:SetTexture(BONFIRE_LIT_BLUR)
            
            -- intial animation (fade-in + flare)
            local show = frame.animated:CreateAnimationGroup()
            local fadein = show:CreateAnimation("Alpha")
            fadein:SetChange(BONFIRE_BLUR_TEXT_END_ALPHA)
            fadein:SetOrder(1)
            -- delay the flare animation until the base texture is almost fully visible
            fadein:SetStartDelay(FADE_IN_TIME * 0.75)
            fadein:SetDuration(FADE_IN_TIME + TEXT_FADE_IN_DURATION)
            --fadein:SetEndDelay(TEXT_END_DELAY)
            local flareOut = show:CreateAnimation("Scale")
            flareOut:SetOrigin("CENTER", 0, 0)
            flareOut:SetScale(BONFIRE_FLARE_SCALE_X, BONFIRE_FLARE_SCALE_Y) -- flare out
            flareOut:SetOrder(1)
            flareOut:SetSmoothing("OUT")
            flareOut:SetStartDelay(FADE_IN_TIME + TEXT_FADE_IN_DURATION)
            flareOut:SetEndDelay(0.1)
            flareOut:SetDuration(BONFIRE_FLARE_OUT_TIME)
            
            local flareIn = show:CreateAnimation("Scale")
            flareIn:SetOrigin("CENTER", 0, 0)
            -- scale back down (just a little larger than the starting amount)
            local xScale = (1 / BONFIRE_FLARE_SCALE_X) + 0.021
            flareIn:SetScale(xScale, 1 / BONFIRE_FLARE_SCALE_Y)
            flareIn:SetOrder(2)
            flareIn:SetSmoothing("OUT")
            flareIn:SetDuration(BONFIRE_FLARE_IN_TIME)
            flareIn:SetEndDelay(BONFIRE_END_DELAY)
            
            -- hide animation (fade-out)
            local hide = frame.animated:CreateAnimationGroup()
            local fadeout = hide:CreateAnimation("Alpha")
            fadeout:SetChange(-1)
            fadeout:SetOrder(1)
            fadeout:SetSmoothing("IN_OUT")
            fadeout:SetStartDelay(FADE_OUT_DELAY)
            fadeout:SetDuration(FADE_OUT_TIME + FADE_OUT_DELAY)
            
            flareIn:SetScript("OnFinished", function(self)
                -- set the end scale of the animation to prevent the frame
                -- from snapping to its original scale
                local xScale, yScale = self:GetScale()
                local height = TEXT_HEIGHT_PERCENT * ScreenHeight
                local width = height / BONFIRE_WIDTH_HEIGHT_RATIO
                frame.animated:SetSize(width * BONFIRE_FLARE_SCALE_X * xScale, height * BONFIRE_FLARE_SCALE_Y * yScale)
            end)
            
            show:SetScript("OnFinished", function(self)
                -- hide once the delay finishes
                frame.animated:SetAlpha(BONFIRE_BLUR_TEXT_END_ALPHA)
                
                fadeout:SetScript("OnUpdate", HideBackgroundAfterDelay)
                frame.hide:Play() -- static hide
                hide:Play() -- blurred hide
            end)
            hide:SetScript("OnFinished", function(self)
                -- reset to initial state
                frame.animated:SetAlpha(0)
                frame.animated:SetScale(BONFIRE_START_SCALE)
                
                bonfireIsLighting = nil
            end)
            frame.animated.show = show
        end
        
        local height = TEXT_HEIGHT_PERCENT * ScreenHeight
        frame:SetSize(height / BONFIRE_WIDTH_HEIGHT_RATIO, height)
        frame:SetAlpha(0)
        frame:SetScale(BONFIRE_START_SCALE)
        frame.show:Play()
        
        local animated = frame.animated
        animated:SetSize(height / BONFIRE_WIDTH_HEIGHT_RATIO, height)
        animated:SetAlpha(0)
        animated:SetScale(BONFIRE_START_SCALE)
        animated.show:Play()
        
        bonfireIsLighting = true
    end,

    [2] = function()
        local frame = bonfireLit[2]
        if not frame then
            -- static bonfire lit
            frame = CreateFrame("Frame")
            bonfireLit[2] = frame
            
            --
            --
            -- animated/blurred bonfire lit
            frame.animated = CreateFrame("Frame")
        end
        
        --[[
        https://www.youtube.com/watch?v=KtLrVSrRruU&t=2m49s
        1. bg alpha in (~0.2s?)
        2. static BONFIRE LIT alpha in when bg is ~50% done
        3. blurred BONFIRE LIT alpha + scale (x) after static is done animating
                -> ~2s
        4. all fade out
            a. both BONFIRE LIT textures zoom out (~0.3s?)
        --]]
        
        bonfireIsLighting = true
    end,
} -- bonfire lit animations

-- ------------------------------------------------------------------
-- Event handlers
-- ------------------------------------------------------------------
DSFrame:RegisterEvent("ADDON_LOADED")
function DSFrame:ADDON_LOADED(event, name)
    if name == me then
        DarkSoulsDeathScreen = DarkSoulsDeathScreen or {
            --[[
            default db
            --]]
            enabled = true, -- addon enabled flag
            sound = true, -- sound enabled flag
            tex = YOU_DIED, -- death animation texture
            version = 1, -- animation version
        }
        db = DarkSoulsDeathScreen
        if not db.enabled then
            self:SetScript("OnEvent", nil)
        end
        self.ADDON_LOADED = nil
        
        -- add the version flag to old SVs
        db.version = db.version or 1
    end
end

local SpiritOfRedemption = GetSpellInfo(20711)
local FeignDeath = GetSpellInfo(5384)
DSFrame:RegisterEvent("PLAYER_DEAD")
function DSFrame:PLAYER_DEAD(event)
    local SOR = UnitBuff("player", SpiritOfRedemption)
    local FD = UnitBuff("player", FeignDeath)
    -- event==nil means a fake event
    if not event or not (UnitBuff("player", SpiritOfRedemption) or UnitBuff("player", FeignDeath)) then
    
        -- TODO? cancel other anims (ie, bonfire lit)
        
        if db.sound then
            PlaySoundFile(YOU_DIED_SOUND, "Master")
        end
        
        local SpawnBackgroundAnim = SpawnBackground[db.version]
        local YouDiedAnim = YouDied[db.version]
        if SpawnBackgroundAnim and YouDiedAnim then
            SpawnBackgroundAnim()
            YouDiedAnim()
        else
            UnrecognizedVersion()
        end
    end
end

local ENKINDLE_BONFIRE = 174723
DSFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
function DSFrame:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell, rank, lineId, spellId)
    if (spellId == ENKINDLE_BONFIRE and unit == "player") or not event then
        -- waiting for the full animation to run may skip some enkindle casts
        -- (if the player is spam clicking the bonfire)
        if not bonfireIsLighting then
            if db.sound then
                local bonfireLitSound = BONFIRE_LIT_SOUND[db.version or 0]
                if bonfireLitSound then
                    PlaySoundFile(bonfireLitSound, "Master")
                --[[
                else
                    -- let the anim print the error message
                --]]
                end
            end
            
            if db.version == 1 then
                -- begin the animation after the bonfire is actually lit (to mimic Dark Souls 1)
                C_Timer.After(0.6, function()
                    SpawnBackground[1]()
                    BonfireLit[1]()
                    -- https://www.youtube.com/watch?v=HUS_5ao5WEQ&t=6m8s
                end)
            else
                local SpawnBackgroundAnim = SpawnBackground[db.version or 0]
                local BonfireLitAnim = BonfireLit[db.version or 0]
                if SpawnBackgroundAnim and BonfireLitAnim then
                    SpawnBackgroundAnim()
                    BonfireLitAnim()
                else
                    UnrecognizedVersion()
                end
            end
        
        end
    end
end

-- ------------------------------------------------------------------
-- Slash cmd
-- ------------------------------------------------------------------
local slash = "/dsds"
SLASH_DARKSOULSDEATHSCREEN1 = slash

local function OnOffString(bool)
    return bool and "|cff00FF00enabled|r" or "|cffFF0000disabled|r"
end

local split = {}
local function pack(...)
    wipe(split)

    local numArgs = select('#', ...)
    for i = 1, numArgs do
        split[i] = select(i, ...)
    end
    return split
end

local commands = {}
commands["enable"] = function(args)
    db.enabled = true
    DSFrame:SetScript("OnEvent", OnEvent)
    Print(OnOffString(db.enabled))
end
commands["on"] = commands["enable"] -- enable alias
commands["disable"] = function(args)
    db.enabled = false
    DSFrame:SetScript("OnEvent", nil)
    Print(OnOffString(db.enabled))
end
commands["off"] = commands["disable"] -- disable alias
local function GetValidVersions()
    -- returns "1/2/3/.../k"
    local result = "1"
    local max = #YouDied
    for i = 2, max do
        result = ("%s/%d"):format(result, i)
    end
    return result
end
commands["version"] = function(args)
    local doPrint = true
    local ver = args[1]
    local max = #YouDied
    if ver then
        ver = tonumber(ver) or 0
        if 0 < ver and ver <= max then
            db.version = ver
        else
            Print(("Usage: %s version [%s]"):format(slash, GetValidVersions()))
            doPrint = false
        end
    else
        -- cycle
        db.version = (db.version % max) + 1
    end
    
    if doPrint then
        Print(("Using Dark Souls %d animations"):format(db.version))
    end
end
commands["ver"] = commands["version"]
commands["sound"] = function(args)
    local doPrint = true
    local enable = args[1]
    if enable then
        if enable == "on" or enable == "true" then
            db.sound = true
        elseif enable == "off" or enable == "false" or enable == "nil" then
            db.sound = false
        else
            Print(("Usage: %s sound [on/off]"):format(slash))
            doPrint = false
        end
    else
        -- toggle
        db.sound = not db.sound
    end
    
    if doPrint then
        Print(("Sound %s"):format(OnOffString(db.sound)))
    end
end
commands["tex"] = function(args)
    local tex = args[1]
    local currentTex = db.tex
    if tex then
        db.tex = tex
    else
        -- toggle
        if currentTex == YOU_DIED then
            db.tex = THANKS_OBAMA
            tex = "THANKS OBAMA"
        else
            -- this will also default to "YOU DIED" if a custom texture path was set
            db.tex = YOU_DIED
            tex = "YOU DIED"
        end
    end
    Print(("Texture set to '%s'"):format(tex))
end
commands["test"] = function(args)
    local anim = args[1]
    if anim == "b" or anim == "bonfire" then
        DSFrame:UNIT_SPELLCAST_SUCCEEDED()
    else
        DSFrame:PLAYER_DEAD()
    end
end

local indent = "  "
local usage = {
    ("Usage: %s"):format(slash),
    ("%s%s on/off: Enables/disables the death screen."),
    ("%s%s version ["..GetValidVersions().."]: Cycles through animation versions (eg, Dark Souls 1/Dark Souls 2)."),
    ("%s%s sound [on/off]: Enables/disables the death screen sound. Toggles if passed no argument."),
    ("%s%s tex [path\\to\\custom\\texture]: Toggles between the 'YOU DIED' and 'THANKS OBAMA' textures. If an argument is supplied, the custom texture will be used instead."),
    ("%s%s test [bonfire]: Runs the death animation or the bonfire animation if 'bonfire' is passed as an argument."),
    ("%s%s help: Shows this message."),
}
do -- format the usage lines
    for i = 2, #usage do
        usage[i] = usage[i]:format(indent, slash)
    end
end
commands["help"] = function(args)
    for i = 1, #usage do
        Print(usage[i])
    end
end
commands["h"] = commands["help"] -- help alias

local delim = " "
function SlashCmdList.DARKSOULSDEATHSCREEN(msg)
    msg = msg and msg:lower()
    local args = pack(strsplit(delim, msg))
    local cmd = remove(args, 1)
    
    local exec = cmd and type(commands[cmd]) == "function" and commands[cmd] or commands["h"]
    exec(args)
end
