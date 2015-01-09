
local print, strsplit, select, wipe, remove
    = print, strsplit, select, wipe, table.remove
local CreateFrame, GetSpellInfo, PlaySoundFile, UIParent, UnitBuff
	= CreateFrame, GetSpellInfo, PlaySoundFile, UIParent, UnitBuff
    
local me = ...

local MEDIA_PATH = [[Interface\Addons\DarkSoulsDeathScreen\media\]]
local YOU_DIED = MEDIA_PATH .. [[YOUDIED.tga]]
local THANKS_OBAMA = MEDIA_PATH .. [[THANKSOBAMA.tga]]
local YOU_DIED_SOUND = MEDIA_PATH .. [[YOUDIED.ogg]]
local BONFIRE_LIT = MEDIA_PATH .. [[BONFIRELIT.tga]]
local BONFIRE_LIT_BLUR = MEDIA_PATH .. [[BONFIRELIT_BLUR.tga]]
local BONFIRE_LIT_SOUND = MEDIA_PATH .. [[BONFIRELIT.ogg]]
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

-- TODO: ds2
-- bg = 60% from top
-- youdied: https://www.youtube.com/watch?v=KtLrVSrRruU&t=24m34s
--      i dont think wow's animation system can do the text reveal that ds2 does
--      need to set texcoords in an OnUpdate handler, i think..
-- bonfire: https://www.youtube.com/watch?v=KtLrVSrRruU&t=2m49s

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

local function HideBackgroundAfterDelay(self, e)
	self.elapsed = (self.elapsed or 0) + e
	if self.elapsed > FADE_OUT_DELAY then
		background:SetScript("OnUpdate", BGFadeOut)
		self:SetScript("OnUpdate", nil)
		self.elapsed = nil
	end
end

local youDied
local function YouDied()
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
		fadein:SetDuration(FADE_IN_TIME + TEXT_FADE_IN_DURATION)
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
			fadeout:SetScript("OnUpdate", HideBackgroundAfterDelay)
			hide:Play()
		end)
        hide:SetScript("OnUpdate", function(self, e)
            
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
	youDied:SetSize(height / YOU_DIED_WIDTH_HEIGHT_RATIO, height)
	youDied:SetAlpha(0)
	youDied:SetScale(1)
	youDied.show:Play()
end

local bonfireLit
local bonfireLitAnimated
local function LightBonfire()
    if not bonfireLit then
		bonfireLit = CreateFrame("Frame")
		bonfireLit:SetPoint("CENTER", 0, 0)
		bonfireLit:SetFrameStrata("HIGH")
        
		-- "BONFIRE LIT"
		bonfireLit.tex = bonfireLit:CreateTexture()
		bonfireLit.tex:SetAllPoints()
        bonfireLit.tex:SetTexture(BONFIRE_LIT)
        
		-- intial animation (fade-in)
		local show = bonfireLit:CreateAnimationGroup()
		local fadein = show:CreateAnimation("Alpha")
		fadein:SetChange(BONFIRE_TEXT_END_ALPHA)
		fadein:SetOrder(1)
		fadein:SetDuration(FADE_IN_TIME + TEXT_FADE_IN_DURATION)
		fadein:SetEndDelay(TEXT_END_DELAY)
        
		-- hide animation (fade-out)
		local hide = bonfireLit:CreateAnimationGroup()
		local fadeout = hide:CreateAnimation("Alpha")
		fadeout:SetChange(-1)
		fadeout:SetOrder(1)
		fadeout:SetSmoothing("IN_OUT")
		fadeout:SetStartDelay(FADE_OUT_DELAY)
		fadeout:SetDuration(FADE_OUT_TIME + FADE_OUT_DELAY)
        
		show:SetScript("OnFinished", function(self)
			-- hide once the delay finishes
			bonfireLit:SetAlpha(BONFIRE_TEXT_END_ALPHA)
		end)
		hide:SetScript("OnFinished", function(self)
			-- reset to initial state
			bonfireLit:SetAlpha(0)
		end)
		bonfireLit.show = show
        bonfireLit.hide = hide
    end
    
    if not bonfireLitAnimated then
		bonfireLitAnimated = CreateFrame("Frame")
		bonfireLitAnimated:SetPoint("CENTER", 0, 0)
		bonfireLitAnimated:SetFrameStrata("HIGH")
    
        -- animated "BONFIRE LIT"
		bonfireLitAnimated.tex = bonfireLitAnimated:CreateTexture()
		bonfireLitAnimated.tex:SetAllPoints()
        bonfireLitAnimated.tex:SetTexture(BONFIRE_LIT_BLUR)
		
		-- intial animation (fade-in + flare)
		local show = bonfireLitAnimated:CreateAnimationGroup()
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
		local hide = bonfireLitAnimated:CreateAnimationGroup()
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
            bonfireLitAnimated:SetSize(width * BONFIRE_FLARE_SCALE_X * xScale, height * BONFIRE_FLARE_SCALE_Y * yScale)
        end)
        
        show:SetScript("OnFinished", function(self)
			-- hide once the delay finishes
			bonfireLitAnimated:SetAlpha(BONFIRE_BLUR_TEXT_END_ALPHA)
            
			fadeout:SetScript("OnUpdate", HideBackgroundAfterDelay)
			hide:Play()
            bonfireLit.hide:Play()
		end)
		hide:SetScript("OnFinished", function(self)
			-- reset to initial state
			bonfireLitAnimated:SetAlpha(0)
			bonfireLitAnimated:SetScale(BONFIRE_START_SCALE)
		end)
		bonfireLitAnimated.show = show
	end
	
	local height = TEXT_HEIGHT_PERCENT * ScreenHeight
	bonfireLit:SetSize(height / BONFIRE_WIDTH_HEIGHT_RATIO, height)
	bonfireLit:SetAlpha(0)
	bonfireLit:SetScale(BONFIRE_START_SCALE)
    bonfireLit.show:Play()
    
    bonfireLitAnimated:SetSize(height / BONFIRE_WIDTH_HEIGHT_RATIO, height)
    bonfireLitAnimated:SetAlpha(0)
    bonfireLitAnimated:SetScale(BONFIRE_START_SCALE)
	bonfireLitAnimated.show:Play()
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
        
        -- TODO: cancel other anims (ie, bonfire lit)
        
		SpawnBackground()
		YouDied()
	end
end

local ENKINDLE_BONFIRE = 174723
DSFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
function DSFrame:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell, rank, lineId, spellId)
    if (spellId == ENKINDLE_BONFIRE and unit == "player") or not event then
        if db.sound then
            PlaySoundFile(BONFIRE_LIT_SOUND, "Master")
        end
        -- TODO: delay in case player chain casts
        
        SpawnBackground()
        LightBonfire()
        
        -- https://www.youtube.com/watch?v=HUS_5ao5WEQ&t=6m8s
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
