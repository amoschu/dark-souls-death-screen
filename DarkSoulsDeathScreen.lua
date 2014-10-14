
local print, strsplit, select, wipe, remove
    = print, strsplit, select, wipe, table.remove
local CreateFrame, GetSpellInfo, PlaySoundFile, UIParent, UnitBuff
	= CreateFrame, GetSpellInfo, PlaySoundFile, UIParent, UnitBuff
    
local me = ...

local MEDIA_PATH = [[Interface\Addons\DarkSoulsDeathScreen\media\]]
local YOU_DIED = MEDIA_PATH .. [[YOUDIED.tga]]
local THANKS_OBAMA = MEDIA_PATH .. [[THANKSOBAMA.tga]]
local YOU_DIED_SOUND = MEDIA_PATH .. [[YOUDIED.ogg]]
local TEXTURE_WIDTH_HEIGHT_RATIO = 0.32 -- width / height

local BG_END_ALPHA = 0.85 -- [0,1] alpha
local TEXT_END_ALPHA = 0.5 -- [0,1] alpha
local TEXT_SHOW_END_SCALE = 1.25 -- scale factor
local FADE_IN_TIME = 0.45 -- in seconds
local FADE_OUT_TIME = 0.3 -- in seconds
local FADE_OUT_DELAY = 0.4 -- in seconds
local TEXT_END_DELAY = 0.5 -- in seconds
local BACKGROUND_GRADIENT_PERCENT = 0.15 -- of background height
local BACKGROUND_HEIGHT_PERCENT = 0.21 -- of screen height
local TEXT_HEIGHT_PERCENT = 0.18 -- of screen height

local ScreenWidth, ScreenHeight = UIParent:GetSize()
local db

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

-- ------------------------------------------------------------------
-- Display
-- ------------------------------------------------------------------
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

local background
local function SpawnBackground()
	if not background then
		background = CreateFrame("Frame")
		background:SetPoint("CENTER", 0, 0)
		background:SetFrameStrata("MEDIUM")
		
		local bg = background:CreateTexture()
		bg:SetTexture(0, 0, 0)
		background.bg = bg
		
		local top = background:CreateTexture()
		top:SetTexture(0, 0, 0)
		top:SetGradientAlpha("VERTICAL", 0, 0, 0, 1, 0, 0, 0, 0) -- orientation, startR, startG, startB, startA, endR, endG, endB, endA (start = bottom, end = top)
		background.top = top
		
		local btm = background:CreateTexture()
		btm:SetTexture(0, 0, 0)
		btm:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0, 0, 0, 1)
		background.btm = btm
	end
	
	local height = BACKGROUND_HEIGHT_PERCENT * ScreenHeight
	local bgHeight = BACKGROUND_GRADIENT_PERCENT * height
	background:SetSize(ScreenWidth, height)
	
	-- size the background's constituent components
	background.top:ClearAllPoints()
	background.top:SetPoint("TOPLEFT", 0, 0)
	background.top:SetPoint("BOTTOMRIGHT", background, "TOPRIGHT", 0, -bgHeight)
	
	background.bg:ClearAllPoints()
	background.bg:SetPoint("TOPLEFT", 0, -bgHeight)
	background.bg:SetPoint("BOTTOMRIGHT", 0, bgHeight)
	
	background.btm:ClearAllPoints()
	background.btm:SetPoint("BOTTOMLEFT", 0, 0)
	background.btm:SetPoint("TOPRIGHT", background, "BOTTOMRIGHT", 0, bgHeight)
	
	background:SetAlpha(0)
	-- ideally this would use Animations, but they seem to set the alpha on all elements in the region which destroys the alpha gradient
	-- ie, the background becomes just a solid-color rectangle
	background:SetScript("OnUpdate", BGFadeIn)
end

local function FadeOutOnUpdate(self, e)
	self.elapsed = (self.elapsed or 0) + e
	if self.elapsed > FADE_OUT_DELAY then
		background:SetScript("OnUpdate", BGFadeOut)
		self:SetScript("OnUpdate", nil)
		self.elapsed = nil
	end
end

local youDied
local function SpawnText()
	if not youDied then
		youDied = CreateFrame("Frame")
		youDied:SetPoint("CENTER", 0, 0)
		youDied:SetFrameStrata("HIGH")
		
		-- "YOU DIED"
		youDied.tex = youDied:CreateTexture()
		youDied.tex:SetAllPoints()
		
		-- intial animation (fade-in + zoom)
		local show = youDied:CreateAnimationGroup()
		local fadein = show:CreateAnimation("Alpha")
		fadein:SetChange(TEXT_END_ALPHA)
		fadein:SetOrder(1)
		fadein:SetStartDelay(FADE_IN_TIME)
		fadein:SetDuration(FADE_IN_TIME + 0.15)
		fadein:SetEndDelay(TEXT_END_DELAY)
		local zoom = show:CreateAnimation("Scale")
		zoom:SetOrigin("CENTER", 0, 0)
		zoom:SetScale(TEXT_SHOW_END_SCALE, TEXT_SHOW_END_SCALE)
		zoom:SetOrder(1)
		zoom:SetDuration(1.3)
		zoom:SetEndDelay(TEXT_END_DELAY)
		
		-- hide animation (fade-out + slower zoom)
		local hide = youDied:CreateAnimationGroup()
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
			youDied:SetAlpha(TEXT_END_ALPHA)
			youDied:SetScale(TEXT_SHOW_END_SCALE)
			fadeout:SetScript("OnUpdate", FadeOutOnUpdate)
			hide:Play()
		end)
		hide:SetScript("OnFinished", function(self)
			-- reset to initial state
			youDied:SetAlpha(0)
			youDied:SetScale(1)
		end)
		youDied.show = show
	end
    
    if youDied.tex:GetTexture() ~= db.tex then
        youDied.tex:SetTexture(db.tex)
    end
	
	local height = TEXT_HEIGHT_PERCENT * ScreenHeight
	youDied:SetSize(height / TEXTURE_WIDTH_HEIGHT_RATIO, height)
	youDied:SetAlpha(0)
	youDied:SetScale(1)
	youDied.show:Play()
end

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
            enabled = true,
            sound = true,
            tex = YOU_DIED,
        }
        db = DarkSoulsDeathScreen
        if not db.enabled then
            self:SetScript("OnEvent", nil)
        end
        self.ADDON_LOADED = nil
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
        if db.sound then
            PlaySoundFile(YOU_DIED_SOUND, "Master")
        end
		SpawnBackground()
		SpawnText()
	end
end

-- ------------------------------------------------------------------
-- Slash cmd
-- ------------------------------------------------------------------
local slash = "/dsds"
SLASH_DARKSOULSDEATHSCREEN1 = slash

local ADDON_COLOR = "ff999999"
local function Print(msg)
    print(("|c%sDSDS|r: %s"):format(ADDON_COLOR, msg))
end

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
    DSFrame:PLAYER_DEAD()
end

local indent = "  "
local usage = {
    ("Usage: %s"):format(slash),
    ("%s%s on/off: Enables/disables the death screen."),
    ("%s%s sound [on/off]: Enables/disables the death screen sound. Toggles if passed no argument."),
    ("%s%s tex [path\\to\\custom\\texture]: Toggles between the 'YOU DIED' and 'THANKS OBAMA' textures. If an argument is supplied, the custom texture will be used instead."),
    ("%s%s test: Shows the death screen."),
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
