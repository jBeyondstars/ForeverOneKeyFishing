local buttonName = "ForeverOneKeyFishingCastButton"
local clickAction = "CLICK " .. buttonName .. ":LeftButton"
local events = CreateFrame("Frame")
local override = CreateFrame("Frame")
local capture = CreateFrame("Frame", nil, UIParent)
local button, db, spellName, spellID
local recastButton, forceRecast
local checkGeneration = 0
local softGUID, softEventSupported
local ScheduleDetectionCheck
local notice
local pending, retrieving = false, false
local herbsActive = false
local softTargetEvent = "aucun événement reçu"
local candidates = { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 131474 }
local cvars = {
    SoftTargetInteract = "3",
    SoftTargetInteractGameObject = "1",
    SoftTargetInteractArc = "2",
    SoftTargetInteractRange = "50",
    SoftTargetInteractRangeIsHard = "0",
    SoftTargetIconInteract = "1",
    SoftTargetIconGameObject = "1",
}

local function Say(message)
    print("|cff33ff99FKF|r: " .. message)
end

local function Debug(message)
    if db and db.debug then Say(message) end
end

local function Locked()
    return InCombatLockdown and InCombatLockdown()
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end
    if GetSpellInfo then return GetSpellInfo(id) end
end

local function FindFishing()
    local names = { Fishing = true, ["Pêche"] = true }
    if PROFESSIONS_FISHING then names[PROFESSIONS_FISHING] = true end
    for _, id in ipairs(candidates) do
        local name = SpellName(id)
        if name then names[name] = true end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo
        and Enum and Enum.SpellBookSpellBank then
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info then
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                    local id = item and item.spellID
                    local name = id and SpellName(id)
                    if name and names[name] then return name, id end
                end
            end
        end
    end
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for slot = offset + 1, offset + count do
                local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL or "spell")
                if name and names[name] then
                    local id
                    if GetSpellBookItemInfo then
                        local kind, value = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL or "spell")
                        if kind == "SPELL" then id = value end
                    end
                    return name, id
                end
            end
        end
    end
    local known = IsPlayerSpell or IsSpellKnown
    if known then
        for _, id in ipairs(candidates) do
            if known(id) then
                local name = SpellName(id)
                if name then return name, id end
            end
        end
    end
end

local function ConfigureSoftInteract()
    if Locked() then pending = true; return end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not get or not set then Say("API CVar absente : Soft Interact non configuré."); return end
    for name, value in pairs(cvars) do
        if name == "SoftTargetInteractRange" then value = tostring(db.range or 50) end
        local ok, current = pcall(get, name)
        if ok and current ~= nil then
            if db.cvarBackup[name] == nil then db.cvarBackup[name] = tostring(current) end
            if tostring(current) ~= value then
                local changed = pcall(set, name, value)
                local readable, actual = pcall(get, name)
                if not changed or not readable or tostring(actual) ~= value then
                    Say("CVar refusée ou limitée : " .. name .. " ; demandée=" .. value
                        .. ", effective=" .. tostring(actual))
                end
            end
        else
            Debug("CVar optionnelle absente : " .. name)
        end
    end
end

local function RestoreCVars(defaults)
    if Locked() then pending = true; return false end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    local getDefault = C_CVar and C_CVar.GetCVarDefault or GetCVarDefault
    if not get or not set then return false end
    local success = true
    for name in pairs(cvars) do
        local value = db.cvarBackup[name]
        local exists, current = pcall(get, name)
        if exists and current ~= nil then
            if defaults then
                local ok, default
                if getDefault then ok, default = pcall(getDefault, name) end
                if ok and default ~= nil then
                    value = tostring(default)
                else
                    success = false
                    Say("valeur par défaut indisponible : " .. name)
                end
            end
            if value ~= nil then
                local ok = pcall(set, name, value)
                local readable, actual = pcall(get, name)
                if ok and readable and tostring(actual) == value then
                    db.cvarBackup[name] = nil
                else
                    success = false
                    Say("restauration refusée : " .. name)
                end
            end
        end
    end
    return success
end

local function IsFishing()
    if not UnitChannelInfo then return false end
    local name, _, _, _, _, _, _, id = UnitChannelInfo("player")
    return name ~= nil and ((spellID and id == spellID) or name == spellName)
end

local function Diagnostic()
    local name, id
    if UnitChannelInfo then
        local channel = { UnitChannelInfo("player") }
        name, id = channel[1], channel[8]
    end
    Say("channel : " .. tostring(name or "aucun") .. " / " .. tostring(id)
        .. "; sort configuré : " .. tostring(spellName) .. " / " .. tostring(spellID))
    Say("mode : " .. (db.herbs and "herboristerie" or forceRecast and "relance prête" or retrieving and "récupération" or "lancer")
        .. "; binding effectif : " .. (db.key and GetBindingAction(db.key, true) or "aucun")
        .. "; combat : " .. tostring(not not Locked()))
    local ok, guid = false, nil
    if UnitGUID then ok, guid = pcall(UnitGUID, "softinteract") end
    Say("cible softinteract : " .. (ok and tostring(guid or "aucune") or "API indisponible"))
    Say("dernier changement Soft Interact : " .. softTargetEvent)
    Say("portée demandée : " .. tostring(db.range or 50))
    Say("autorecast : " .. (db.autorecast and "on (délai 2 s)" or "off"))
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if get then
        for name in pairs(cvars) do
            local readable, value = pcall(get, name)
            Say(name .. "=" .. (readable and tostring(value or "absente") or "indisponible"))
        end
    end
end

local function SetRetrieving(active, clear)
    if Locked() then pending = true; return end
    if not clear and db.enabled and db.herbs and db.key then
        if not herbsActive then
            ClearOverrideBindings(override)
            ConfigureSoftInteract()
            herbsActive = true
        end
        retrieving = false
        return
    end
    herbsActive = false
    if forceRecast then return end
    active = active and db.enabled and db.key ~= nil and button ~= nil
    if active and not retrieving then
        ConfigureSoftInteract()
        SetOverrideBinding(override, true, db.key, "INTERACTTARGET")
        retrieving = true
        if ScheduleDetectionCheck then ScheduleDetectionCheck() end
        Debug("mode récupération ; binding effectif : " .. GetBindingAction(db.key, true))
        if GetBindingAction(db.key, true) ~= "INTERACTTARGET" then
            Say("le binding effectif diffère de INTERACTTARGET ; vérifie les autres addons de pêche")
        end
    elseif not active then
        checkGeneration = checkGeneration + 1
        ClearOverrideBindings(override)
        if retrieving then Debug("channel terminé"); Debug("mode lancer") end
        retrieving = false
        RestoreCVars(false)
    end
end

local function PrepareButton()
    if Locked() then pending = true; return false end
    spellName, spellID = FindFishing()
    if not spellName then
        if button then button:SetAttribute("spell", nil) end
        Debug("sort Pêche introuvable dans le grimoire")
        return false
    end
    if not button then
        button = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetSize(1, 1)
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -10, -10)
        button:EnableMouse(false)
        button:SetAlpha(0)
        button:SetAttribute("type", "spell")
        -- A fixed key-up action avoids a second cast when the override changes mid-press.
        button:SetAttribute("useOnKeyDown", false)
    end
    button:SetAttribute("spell", spellID or spellName)
    if not recastButton then
        recastButton = CreateFrame("Button", buttonName .. "Recast", UIParent, "SecureActionButtonTemplate")
        recastButton:RegisterForClicks("AnyUp", "AnyDown")
        recastButton:SetSize(1, 1)
        recastButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -10, -10)
        recastButton:EnableMouse(false)
        recastButton:SetAlpha(0)
        recastButton:SetAttribute("type", "macro")
        recastButton:SetAttribute("useOnKeyDown", false)
    end
    recastButton:SetAttribute("macrotext", "/stopcasting [channeling:" .. spellName .. "]\n/cast " .. spellName)
    return true
end

local function HasSoftTarget()
    if softGUID then return true end
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, "softinteract")
        if ok then return guid ~= nil and guid ~= "", true end
    end
    return false, softEventSupported
end

local function UpdateNotice()
    if not db or not db.enabled or db.herbs or not db.hud or not db.key
        or (not IsFishing() and not forceRecast) then
        if notice then notice:Hide() end
        return
    end
    if not notice then
        notice = CreateFrame("Frame", "ForeverOneKeyFishingNotice", UIParent)
        notice:SetSize(580, 72)
        notice:SetPoint("TOP", UIParent, "TOP", 0, -100)
        notice:SetFrameStrata("HIGH")
        notice:EnableMouse(false)
        notice.text = notice:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        notice.text:SetAllPoints(notice)
        notice.text:SetJustifyH("CENTER")
        notice.text:SetShadowColor(0, 0, 0, 1)
        notice.text:SetShadowOffset(1, -1)
    end
    -- Soft targeting does not report a bite. Keep the HUD hidden until a reliable
    -- bite-ready signal is available on this client; never infer it from a timer.
    notice:Hide()
end

ScheduleDetectionCheck = function()
    checkGeneration = checkGeneration + 1
    if not db.autorecast or not db.enabled or db.herbs or not db.key or not IsFishing() then return end
    if not C_Timer or not C_Timer.After then
        Say("autorecast indisponible : API C_Timer.After absente")
        return
    end
    local generation = checkGeneration
    C_Timer.After(2, function()
        if generation ~= checkGeneration or not db.autorecast or not db.enabled or db.herbs
            or not db.key or forceRecast or not IsFishing() then return end
        if Locked() then pending = true; return end
        local detected, supported = HasSoftTarget()
        if detected then UpdateNotice(); return end
        if not supported then
            Say("autorecast suspendu : détection Soft Interact indisponible")
            return
        end
        -- Keep Soft Interact active so a late target can return the key to retrieval.
        forceRecast = "auto"
        retrieving = false
        SetOverrideBindingClick(override, true, db.key, buttonName .. "Recast", "LeftButton")
        Say("aucune cible d'interaction détectée : appuie sur " .. db.key .. " pour relancer")
        UpdateNotice()
    end)
end

local function Save()
    SaveBindings(GetCurrentBindingSet())
end

local function WarnReplacement(key, action)
    if action and action ~= "" and action ~= clickAction then
        Say("touche " .. key .. " : remplacement du raccourci " .. action)
    end
end

local function ReleaseKey()
    if not db.key then return true end
    if GetBindingAction(db.key) == (db.installedAction or clickAction) then
        local old = db.previousAction
        if old == "" or old == clickAction then old = nil end
        if not SetBinding(db.key, old) then
            Say("impossible de restaurer le raccourci précédent")
            return false
        end
    end
    return true
end

local function InstallKey(key)
    if db.herbs then
        if not SetBinding(key, "INTERACTTARGET") then return false end
        db.installedAction = "INTERACTTARGET"
    else
        if not SetBindingClick(key, buttonName, "LeftButton") then return false end
        db.installedAction = clickAction
    end
    return true
end

local function Bind(key)
    if Locked() then Say("configuration impossible en combat"); return end
    if not db.herbs and not PrepareButton() then Say("apprends Pêche avant de configurer la touche"); return end
    local previous = GetBindingAction(key) or ""
    WarnReplacement(key, previous)
    forceRecast = false
    SetRetrieving(false, true)
    local oldKey, oldAction = db.key, db.previousAction
    if not ReleaseKey() then return end
    if not InstallKey(key) then
        if oldKey then InstallKey(oldKey) end
        Say("touche refusée : " .. key)
        SetRetrieving(IsFishing())
        return
    end
    db.key = key
    db.enabled = true
    db.previousAction = key == oldKey and oldAction or previous
    Save()
    Say("touche " .. key .. " enregistrée")
    Debug("mode lancer")
    SetRetrieving(IsFishing())
end

capture:Hide()
capture:SetAllPoints(UIParent)
capture:SetFrameStrata("FULLSCREEN_DIALOG")
capture:EnableKeyboard(true)
capture:EnableMouse(true)
if capture.EnableMouseWheel then capture:EnableMouseWheel(true) end
if capture.SetPropagateKeyboardInput then capture:SetPropagateKeyboardInput(false) end

local modifiers = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
local function CaptureKey(key)
    if Locked() then capture:Hide(); Say("capture annulée : combat"); return end
    if key == "ESCAPE" then capture:Hide(); Say("capture annulée"); return end
    if modifiers[key] then return end
    if IsShiftKeyDown() then key = "SHIFT-" .. key end
    if IsControlKeyDown() then key = "CTRL-" .. key end
    if IsAltKeyDown() then key = "ALT-" .. key end
    capture:Hide()
    Bind(key)
end

capture:SetScript("OnKeyDown", function(_, key) CaptureKey(key) end)
capture:SetScript("OnMouseDown", function(_, mouse)
    local names = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" }
    local key = names[mouse] or (mouse:match("^Button%d+$") and mouse:upper())
    if key == "BUTTON1" or key == "BUTTON2" then
        Say("choisis un bouton souris 3 ou supérieur, ou une touche clavier")
    elseif key then CaptureKey(key) end
end)
capture:SetScript("OnMouseWheel", function(_, delta)
    if delta ~= 0 then CaptureKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end
end)

local function Restore()
    if Locked() then pending = true; return end
    pending = false
    if not db.enabled then
        forceRecast = false
        SetRetrieving(false)
        return
    end
    if not db.herbs and not PrepareButton() then
        SetRetrieving(false)
        return
    end
    if db.key then
        local current = GetBindingAction(db.key) or ""
        WarnReplacement(db.key, current)
        if current ~= (db.installedAction or clickAction) then db.previousAction = current end
        if InstallKey(db.key) then Save() end
    end
    SetRetrieving(IsFishing())
end

SLASH_FOREVERONEKEYFISHING1 = "/fkf"
local function HandleCommand(message)
    if not db then return end
    local command = (message or ""):match("^%s*(%S*)"):lower()
    if command == "debug" then
        db.debug = not db.debug
        Say("debug " .. (db.debug and "activé" or "désactivé"))
    elseif command == "diag" then
        Diagnostic()
    elseif command == "herbs" then
        local argument = message:match("^%s*%S+%s+(%S+)%s*$")
        argument = argument and argument:lower()
        if argument ~= "on" and argument ~= "off" then
            Say("herboristerie " .. (db.enabled and db.herbs and "on" or "off") .. " ; /fkf herbs on|off")
            return
        end
        if Locked() then Say("configuration impossible en combat"); return end
        if argument == "off" and not db.herbs then Say("herboristerie déjà désactivée"); return end
        capture:Hide()
        forceRecast = false
        SetRetrieving(false, true)
        if not ReleaseKey() then return end
        db.herbs = true
        db.enabled = argument == "on"
        Save()
        if db.enabled then
            Restore()
            Say(db.key and "herboristerie activée : " .. db.key .. " pour interagir à portée"
                or "herboristerie activée ; configure la touche avec /fkf bind")
            Say("la cible peut aussi être un autre objet ou un PNJ ; /fkf herbs off pour restaurer les réglages")
        else
            Say("herboristerie désactivée ; raccourci et réglages précédents restaurés")
        end
    elseif command == "hud" then
        local argument = message:match("^%s*%S+%s+(%S+)%s*$")
        argument = argument and argument:lower()
        if argument ~= "on" and argument ~= "off" then
            Say("affichage " .. (db.hud and "on" or "off") .. " ; /fkf hud on|off")
            return
        end
        db.hud = argument == "on"
        Say("affichage " .. argument)
        if db.hud then Say("alerte de morsure indisponible : aucun signal fiable identifié sur ce client") end
    elseif command == "autorecast" then
        local argument = message:match("^%s*%S+%s+(%S+)%s*$")
        argument = argument and argument:lower()
        if argument ~= "on" and argument ~= "off" then
            Say("autorecast " .. (db.autorecast and "on" or "off") .. " ; /fkf autorecast on|off")
            return
        end
        if Locked() then Say("configuration impossible en combat"); return end
        db.autorecast = argument == "on"
        checkGeneration = checkGeneration + 1
        if forceRecast == "auto" then
            forceRecast = false
            SetRetrieving(IsFishing())
        end
        if db.autorecast then ScheduleDetectionCheck() end
        Say("autorecast " .. argument .. " : relance uniquement au prochain appui")
    elseif command == "off" or command == "reset" then
        if Locked() then Say("configuration impossible en combat"); return end
        capture:Hide()
        forceRecast = false
        SetRetrieving(false, true)
        if not ReleaseKey() then return end
        db.enabled = false
        Save()
        local restored = RestoreCVars(true)
        Say(restored and "désactivé ; paramètres d'interaction remis aux valeurs par défaut du client"
            or "désactivé ; certains paramètres n'ont pas pu être réinitialisés")
    elseif command == "on" then
        if Locked() then Say("configuration impossible en combat"); return end
        if db.herbs then
            forceRecast = false
            SetRetrieving(false, true)
            if not ReleaseKey() then return end
            Save()
            db.herbs = false
        end
        db.enabled = true
        Restore()
        Say("activé ; réglages d'interaction appliqués uniquement pendant la pêche")
    elseif command == "recast" then
        if Locked() then Say("relance impossible en combat"); return end
        if db.herbs then Say("mode herboristerie ; /fkf on pour revenir à la pêche"); return end
        if not db.enabled or not db.key then Say("active l'addon et configure une touche d'abord"); return end
        if not PrepareButton() then Say("sort Pêche introuvable"); return end
        forceRecast = false
        SetRetrieving(false)
        forceRecast = true
        SetOverrideBindingClick(override, true, db.key, buttonName .. "Recast", "LeftButton")
        Say("relance forcée prête : appuie sur " .. db.key)
    elseif command == "range" then
        local argument = message:match("^%s*%S+%s+(%S+)%s*$")
        if not argument then
            Say("portée demandée : " .. tostring(db.range or 50) .. " ; /fkf range 50 (10 à 100)")
            return
        end
        local value = tonumber(argument)
        if not value or value ~= value or value < 10 or value > 100 then
            Say("utilise /fkf range avec une valeur de 10 à 100")
            return
        end
        if Locked() then Say("configuration impossible en combat"); return end
        db.range = value
        if retrieving or herbsActive then ConfigureSoftInteract() end
        Say("portée demandée : " .. tostring(value) .. " ; valeur effective dans /fkf diag")
    elseif command == "bind" then
        if Locked() then Say("configuration impossible en combat"); return end
        capture:Show()
        Say("Appuie sur la touche à utiliser... (ESC annule)")
    elseif command == "unbind" then
        if Locked() then Say("configuration impossible en combat"); return end
        capture:Hide()
        forceRecast = false
        SetRetrieving(false, true)
        if ReleaseKey() then
            db.key, db.previousAction = nil, nil
            Save()
            Say("raccourci retiré ; ancien binding restauré si toujours disponible")
        end
    else
        Say((db.enabled and "activé" or "désactivé") .. "; mode : " .. (db.herbs and "herboristerie" or "pêche") .. "; touche : " .. (db.key or "aucune"))
        Say("/fkf on (pêche), off, herbs on|off, autorecast on|off, hud on|off, recast, bind, unbind, debug, diag, range")
        if db.debug then
            local _, _, _, interface = GetBuildInfo()
            Say("Interface " .. tostring(interface) .. ", sort " .. tostring(spellID or spellName))
        end
    end
end

SlashCmdList.FOREVERONEKEYFISHING = function(message)
    HandleCommand(message)
    UpdateNotice()
end

local function HandleEvent(_, event, unit, ...)
    if event == "PLAYER_LOGIN" then
        ForeverOneKeyFishingDB = type(ForeverOneKeyFishingDB) == "table" and ForeverOneKeyFishingDB or {}
        db = ForeverOneKeyFishingDB
        db.enabled = db.enabled ~= false
        db.herbs = db.herbs == true
        if db.installedAction ~= clickAction and db.installedAction ~= "INTERACTTARGET" then db.installedAction = nil end
        db.autorecast = db.autorecast == true
        db.hud = db.hud ~= false
        db.cvarBackup = type(db.cvarBackup) == "table" and db.cvarBackup or {}
        if type(db.range) ~= "number" or db.range ~= db.range or db.range < 10 or db.range > 100 then
            db.range = 50
        end
        if type(db.key) ~= "string" or db.key == "" then db.key = nil end
        if type(db.previousAction) ~= "string" then db.previousAction = nil end
        Restore()
    elseif not db then
        return
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
        softTargetEvent = tostring(unit) .. " -> " .. tostring((...))
        softGUID = (...)
        if softGUID == "" then softGUID = nil end
        if softGUID and forceRecast == "auto" then
            if Locked() then pending = true; return end
            forceRecast = false
            SetRetrieving(IsFishing())
        end
        if retrieving then Debug("Soft Interact : " .. softTargetEvent) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if capture:IsShown() then capture:Hide(); Say("capture annulée : combat") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if forceRecast == "auto" and (not IsFishing() or HasSoftTarget()) then forceRecast = false end
        if pending then Restore() else SetRetrieving(IsFishing()) end
        if not forceRecast then ScheduleDetectionCheck() end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        if Locked() then pending = true; return end
        PrepareButton()
        SetRetrieving(IsFishing())
    elseif unit == "player" then
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            checkGeneration = checkGeneration + 1
            softGUID = nil
            forceRecast = false
            retrieving = false
            Debug("début de channel ; Pêche reconnue : " .. tostring(not not IsFishing()))
        end
        if event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_INTERRUPTED"
            or event == "UNIT_SPELLCAST_CHANNEL_FAILED" then
            checkGeneration = checkGeneration + 1
            if forceRecast == "auto" then forceRecast = false end
            SetRetrieving(false)
        else
            SetRetrieving(IsFishing())
        end
    end
end

events:SetScript("OnEvent", function(...)
    HandleEvent(...)
    UpdateNotice()
end)

for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "SPELLS_CHANGED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "PLAYER_SOFT_INTERACT_CHANGED",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_CHANNEL_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_FAILED",
}) do
    -- Some client branches reject unknown event names during registration.
    local ok = pcall(events.RegisterEvent, events, event)
    if event == "PLAYER_SOFT_INTERACT_CHANGED" then softEventSupported = ok end
end
