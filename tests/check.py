from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
frames, bindings, saved, writes = {}, {F = 'ASSISTTARGET', G = 'TOGGLEBAGS'}, 0, 0
SlashCmdList, UIParent = {}, {}
BOOKTYPE_SPELL, PROFESSIONS_FISHING = 'spell', 'Pêche'
function print() end
function InCombatLockdown() return combat end
local function safe() assert(not combat, 'protected mutation in combat'); writes = writes + 1 end
function CreateFrame(kind, name, parent, template)
    local f = {scripts = {}, attributes = {}, shown = true}
    function f:SetScript(k, v) self.scripts[k] = v end
    function f:RegisterEvent(e)
        if e == 'UNIT_SPELLCAST_CHANNEL_FAILED' or e == 'UNIT_SPELLCAST_CHANNEL_INTERRUPTED' then error('unknown event') end
    end
    function f:SetAttribute(k, v) safe(); self.attributes[k] = v end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:IsShown() return self.shown end
    function f:SetPoint(...) self.point = {...} end
    function f:CreateFontString()
        local text = {}
        function text:SetText(value) self.value = value end
        for _, k in ipairs({'SetAllPoints', 'SetJustifyH', 'SetShadowColor', 'SetShadowOffset'}) do
            text[k] = function() end
        end
        return text
    end
    for _, k in ipairs({'RegisterForClicks', 'SetSize', 'EnableMouse', 'SetAlpha',
        'SetAllPoints', 'SetFrameStrata', 'EnableKeyboard', 'EnableMouseWheel', 'SetPropagateKeyboardInput'}) do
        f[k] = function() end
    end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function GetSpellInfo(id) if id == 7620 then return 'Pêche' end end
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return 'General', nil, 0, 1 end
function GetSpellBookItemName() return 'Pêche' end
function GetSpellBookItemInfo() return 'SPELL', 7620 end
function UnitChannelInfo() return channel, nil, nil, nil, nil, nil, nil, channelID end
function GetBindingAction(key, overrides)
    if overrides and key == overrideKey then return overrideAction end
    return bindings[key] or ''
end
function SetBinding(key, action) safe(); bindings[key] = action; return true end
function SetBindingClick(key, name) safe(); if reject == key then return false end; bindings[key] = 'CLICK '..name..':LeftButton'; return true end
function SetOverrideBinding(owner, priority, key, action) safe(); overrideKey, overrideAction = key, action end
function SetOverrideBindingClick(owner, priority, key, name)
    SetOverrideBinding(owner, priority, key, 'CLICK '..name..':LeftButton')
end
function ClearOverrideBindings() safe(); overrideKey, overrideAction = nil, nil end
function SaveBindings() safe(); saved = saved + 1 end
function GetCurrentBindingSet() return 2 end
cv = {SoftTargetInteract = '0', SoftTargetInteractArc = '0', SoftTargetInteractRange = '10',
    SoftTargetInteractRangeIsHard = '1', SoftTargetIconGameObject = '0'}
function GetCVar(k) return cv[k] end
defaults = {}; for k, v in pairs(cv) do defaults[k] = v end
function GetCVarDefault(k) return defaults[k] end
function SetCVar(k, v) safe(); assert(cv[k]); cv[k] = v end
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function GetBuildInfo() return '', '', '', 16001 end
function event(e, unit, ...) frames[1].scripts.OnEvent(frames[1], e, unit, ...) end
function command(s) SlashCmdList.FOREVERONEKEYFISHING(s) end
function key(k) frames[3].scripts.OnKeyDown(frames[3], k) end
now, timers = 0, {}
C_Timer = {After = function(delay, callback)
    timers[#timers + 1] = {at = now + delay, callback = callback}
end}
function advance(seconds)
    now = now + seconds
    local ready = timers; timers = {}
    for _, timer in ipairs(ready) do
        if timer.at <= now then timer.callback() else timers[#timers + 1] = timer end
    end
end
function UnitGUID() return detectedGUID end
''')
lua.execute((root / 'ForeverOneKeyFishing.lua').read_text(encoding='utf-8'))
lua.execute(r'''
event('PLAYER_LOGIN')
command('bind'); key('ESCAPE'); assert(not ForeverOneKeyFishingDB.key)
command('bind'); key('F')
assert(ForeverOneKeyFishingDB.key == 'F' and ForeverOneKeyFishingDB.previousAction == 'ASSISTTARGET')
assert(ForeverOneKeyFishingCastButton.attributes.spell == 7620)
assert(cv.SoftTargetInteractRange == '10' and cv.SoftTargetIconGameObject == '0')
channel, channelID = 'Pêche', 7620
cv.SoftTargetInteract, cv.SoftTargetInteractRangeIsHard = '0', '1'
event('UNIT_SPELLCAST_CHANNEL_START', 'target'); assert(not overrideKey)
event('UNIT_SPELLCAST_CHANNEL_START', 'player'); assert(overrideKey == 'F' and overrideAction == 'INTERACTTARGET')
assert(cv.SoftTargetInteract == '3' and cv.SoftTargetInteractRangeIsHard == '0')
assert(cv.SoftTargetIconGameObject == '1')
assert(cv.SoftTargetInteractRange == '50')
command('range 70'); assert(cv.SoftTargetInteractRange == '70' and ForeverOneKeyFishingDB.range == 70)
command('range invalid'); command('range 101'); command('range 0')
assert(ForeverOneKeyFishingDB.range == 70)
command('diag')
event('PLAYER_SOFT_INTERACT_CHANGED', nil, 'GameObject-test')
assert(overrideAction == 'INTERACTTARGET')
channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player'); assert(not overrideKey)
assert(cv.SoftTargetInteractRange == '10' and cv.SoftTargetIconGameObject == '0')
channel, channelID = 'Other', 123; event('UNIT_SPELLCAST_CHANNEL_START', 'player'); assert(not overrideKey)
channel, channelID = 'Pêche', 7620; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
combat = true; local before = writes
channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player'); command('unbind'); command('bind')
command('diag')
assert(writes == before and ForeverOneKeyFishingDB.key == 'F')
command('range 30'); assert(writes == before and ForeverOneKeyFishingDB.range == 70)
combat = false; event('PLAYER_REGEN_ENABLED'); assert(not overrideKey)
reject = 'G'; command('bind'); key('G'); assert(ForeverOneKeyFishingDB.key == 'F' and bindings.G == 'TOGGLEBAGS')
reject = nil; command('bind'); key('G'); assert(bindings.F == 'ASSISTTARGET')
command('unbind'); assert(bindings.G == 'TOGGLEBAGS' and not ForeverOneKeyFishingDB.key)
command('bind'); shift = true; key('F'); shift = false
assert(ForeverOneKeyFishingDB.key == 'SHIFT-F')
event('PLAYER_LOGIN'); assert(bindings['SHIFT-F']:match('^CLICK '))
assert(cv.SoftTargetInteractRange == '10')
command('range 30'); assert(cv.SoftTargetInteractRange == '10' and ForeverOneKeyFishingDB.range == 30)
bindings['SHIFT-F'] = 'USER_CHANGED'; command('unbind'); assert(bindings['SHIFT-F'] == 'USER_CHANGED')
command('bind'); event('PLAYER_REGEN_DISABLED'); assert(not frames[3]:IsShown())
command('bind'); key('F')
channel, channelID = 'Pêche', 7620; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
command('recast'); assert(overrideAction == 'CLICK ForeverOneKeyFishingCastButtonRecast:LeftButton')
assert(ForeverOneKeyFishingCastButtonRecast.attributes.macrotext == '/stopcasting [channeling:Pêche]\n/cast Pêche')
channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player')
assert(overrideAction:match('Recast'))
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
assert(overrideAction == 'INTERACTTARGET')
combat = true; local before = writes
command('off'); command('on'); command('recast'); assert(writes == before)
combat = false
command('off'); assert(not overrideKey and not ForeverOneKeyFishingDB.enabled)
assert(bindings.F == 'ASSISTTARGET')
for k, v in pairs(defaults) do assert(cv[k] == v) end
event('UNIT_SPELLCAST_CHANNEL_START', 'player'); assert(not overrideKey)
event('PLAYER_LOGIN'); assert(not ForeverOneKeyFishingDB.enabled and bindings.F == 'ASSISTTARGET')
channel = nil; command('on'); assert(bindings.F:match('^CLICK '))
assert(cv.SoftTargetIconGameObject == '0')
cv.SoftTargetInteractRange = '17'
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player'); assert(cv.SoftTargetInteractRange == '30')
event('PLAYER_LOGIN'); channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player')
assert(cv.SoftTargetInteractRange == '17')
command('reset'); assert(cv.SoftTargetInteractRange == '10')
command('on'); command('autorecast on')
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
advance(1); assert(overrideAction == 'INTERACTTARGET')
advance(1); assert(overrideAction:match('Recast'))
assert(channel == 'Pêche' and cv.SoftTargetInteractRange == '30')
event('PLAYER_SOFT_INTERACT_CHANGED', nil, 'GameObject-bobber')
assert(overrideAction == 'INTERACTTARGET')
advance(2); assert(overrideAction == 'INTERACTTARGET')
channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player')
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
detectedGUID = 'GameObject-bobber'; advance(2); assert(overrideAction == 'INTERACTTARGET')
detectedGUID = nil
event('UNIT_SPELLCAST_CHANNEL_START', 'player'); command('autorecast off')
advance(2); assert(overrideAction == 'INTERACTTARGET')
command('autorecast on'); advance(2); assert(overrideAction:match('Recast'))
command('autorecast off'); assert(overrideAction == 'INTERACTTARGET')
command('autorecast on'); channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player')
advance(2); assert(not overrideKey and cv.SoftTargetInteractRange == '10')
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
combat = true; local before = writes; advance(2); assert(writes == before)
combat = false; event('PLAYER_REGEN_ENABLED'); advance(2); assert(overrideAction:match('Recast'))
channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player'); assert(not overrideKey)
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
command('off'); advance(2); assert(not overrideKey)
channel = nil; command('on'); channel = 'Pêche'
event('UNIT_SPELLCAST_CHANNEL_START', 'player'); advance(1)
channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player')
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player'); advance(1)
assert(overrideAction == 'INTERACTTARGET'); advance(1); assert(overrideAction:match('Recast'))
command('autorecast off')
local timerAPI = C_Timer; C_Timer = nil; command('autorecast on')
assert(overrideAction == 'INTERACTTARGET'); C_Timer = timerAPI
local hud = ForeverOneKeyFishingNotice
assert(hud and not hud:IsShown())
assert(hud.point[1] == 'TOP' and hud.point[3] == 'TOP')
event('PLAYER_SOFT_INTERACT_CHANGED', nil, 'GameObject-bobber')
assert(not hud:IsShown())
command('hud off'); assert(not hud:IsShown())
event('PLAYER_SOFT_INTERACT_CHANGED', 'GameObject-bobber', nil); assert(not hud:IsShown())
command('hud on'); assert(not hud:IsShown())
command('autorecast on'); advance(2)
assert(not hud:IsShown())
channel = nil; event('UNIT_SPELLCAST_CHANNEL_STOP', 'player'); assert(not hud:IsShown())
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player')
combat = true; event('PLAYER_REGEN_DISABLED'); assert(not hud:IsShown())
combat = false; command('off'); assert(not hud:IsShown())
channel = nil; cv.SoftTargetInteractRange = '18'
command('herbs on')
assert(ForeverOneKeyFishingDB.herbs and ForeverOneKeyFishingDB.enabled)
assert(bindings.F == 'INTERACTTARGET' and not overrideKey)
assert(cv.SoftTargetInteractRange == '30' and not hud:IsShown())
event('UNIT_SPELLCAST_CHANNEL_STOP', 'player')
assert(bindings.F == 'INTERACTTARGET' and cv.SoftTargetInteractRange == '30')
channel = 'Pêche'; event('UNIT_SPELLCAST_CHANNEL_START', 'player'); advance(3)
assert(not overrideKey and bindings.F == 'INTERACTTARGET')
command('recast'); assert(not overrideKey)
combat = true; local before = writes
command('herbs off'); command('on'); assert(writes == before)
combat = false; channel = nil
event('PLAYER_LOGIN'); assert(bindings.F == 'INTERACTTARGET')
command('herbs off'); assert(bindings.F == 'ASSISTTARGET')
assert(cv.SoftTargetInteractRange == '18' and not ForeverOneKeyFishingDB.enabled)
event('PLAYER_LOGIN'); assert(bindings.F == 'ASSISTTARGET')
command('herbs on'); command('bind'); key('G')
assert(bindings.F == 'ASSISTTARGET' and bindings.G == 'INTERACTTARGET')
command('on'); assert(not ForeverOneKeyFishingDB.herbs and bindings.G:match('^CLICK '))
assert(cv.SoftTargetInteractRange == '18')
command('unbind'); assert(bindings.G == 'TOGGLEBAGS')
local getTabs = GetNumSpellTabs; GetNumSpellTabs = function() return 0 end
command('herbs on'); command('bind'); key('F')
assert(bindings.F == 'INTERACTTARGET')
command('unbind'); assert(bindings.F == 'ASSISTTARGET' and cv.SoftTargetInteractRange == '18')
GetNumSpellTabs = getTabs
command('bind'); key('F'); command('off')
assert(bindings.F == 'ASSISTTARGET' and cv.SoftTargetInteractRange == '10')
''')
print('PASS: Lua 5.1; bindings, combat, CVar restoration, recast, delayed detection, late target, stale timers, autorecast on/off and missing timer API.')
