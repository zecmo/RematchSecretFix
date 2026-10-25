--[[ Rematch Secret Fix

Rematch 5.3.1 predates patch 12.1 and breaks in four ways. This addon fixes
all of them from the outside, so none of Rematch's own files are touched.
Delete it once Rematch ships an official 12.1 update.

  1. MouseIsOver was removed in 12.1 -> Rematch's main window draws blank.
  2. A scanned NPC name can be a secret string; indexing it throws out of
     GetNpcName mid-render, so the Teams List loses names and looks as though
     teams have been deleted or moved. (They have not. It is a draw failure.)
  3. A tooltip line can be a secret string, aborting the whole tooltip copy.
  4. Unit GUIDs are secret inside instanced content, so Rematch cannot work
     out an npcID and target detection switches itself off -- no target panel,
     no auto-select -- in exactly the pet battle dungeons you want it in.

(4) is the interesting one. Unit identity is secret, but the battle pet APIs
are not, so for a wild pet we can go

    UnitBattlePetSpeciesID -> C_PetJournal.GetPetInfoBySpeciesID -> companionID

and companionID is the same npcID a team is keyed on. Verified in a pet battle
dungeon: Deviate Flapper -> species 1987 -> companionID 116787, which is the
exact key that team was saved under.

Fixes 2-4 call Rematch's original function first and only act if it fails or
comes back empty, so they stop engaging by themselves once Rematch handles
secret values -- no version checks, and Rematch keeps its own name caching.
]]

--------------------------------------------------------------------------
-- 1. MouseIsOver
--
-- Verbatim from !RematchCompat by unieagle (MIT, see LICENSE) -- its 12.0.7
-- implementation was a one-line pass-through to region:IsMouseOver. The guard
-- means this is harmless if that addon is also installed, or if Blizzard ever
-- brings the global back.
--------------------------------------------------------------------------
local state = { mouseIsOver = nil, rematch = false }

if not MouseIsOver then
    function MouseIsOver(region, topOffset, bottomOffset, leftOffset, rightOffset)
        return region:IsMouseOver(topOffset, bottomOffset, leftOffset, rightOffset)
    end
    state.mouseIsOver = "restored by this addon"
else
    state.mouseIsOver = "already present, left alone"
end

--------------------------------------------------------------------------
-- 2-4. Secret-value fixes, applied once Rematch exists
--------------------------------------------------------------------------
local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function applyFixes()
    local R = _G.Rematch
    if not R or not R.targetInfo then return false end

    -- (4) recover the npcID without the secret GUID
    if not R.targetInfo.__secretFixNpcID then
        local orig = R.targetInfo.GetUnitNpcID
        R.targetInfo.GetUnitNpcID = function(self, unit)
            local ok, npcID = pcall(orig, self, unit)
            if ok and npcID then
                return npcID                      -- original coped
            end
            if not (unit and UnitExists and UnitExists(unit)) then return end
            if not (UnitIsWildBattlePet and UnitIsWildBattlePet(unit)) then return end
            if not (C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID) then return end

            local species = UnitBattlePetSpeciesID and UnitBattlePetSpeciesID(unit)
            if not species or isSecret(species) then return end

            local okPet, _, _, _, companionID = pcall(C_PetJournal.GetPetInfoBySpeciesID, species)
            if not okPet or not companionID or isSecret(companionID) then return end

            companionID = tonumber(companionID)
            if not companionID or companionID == 0 then return end

            local redirects = R.targetData and R.targetData.redirects
            return (redirects and redirects[companionID]) or companionID
        end
        R.targetInfo.__secretFixNpcID = true
    end
    state.rematch = true

    -- (2) a secret name must not abort the caller's render
    if not R.targetInfo.__secretFixNpcName then
        local orig = R.targetInfo.GetNpcName
        R.targetInfo.GetNpcName = function(self, npcID, noDisplay)
            local ok, name = pcall(orig, self, npcID, noDisplay)
            if ok then
                return name                       -- including the cached path
            end
            if type(npcID) == "number" then
                return "id " .. npcID
            end
            return UNKNOWN or "Unknown"
        end
        R.targetInfo.__secretFixNpcName = true
    end

    -- (3) one secret line must not lose the whole tooltip. Rebuilt rather
    -- than delegated: a mid-way failure would leave a half-copied tooltip.
    if R.tooltip and not R.tooltip.__secretFixClone then
        R.tooltip.CloneGameTooltip = function(self)
            local source = _G.RematchGameTooltip
            if source and source:NumLines() > 0 then
                for i = 1, source:NumLines() do
                    local line = _G["RematchGameTooltipTextRight" .. i]
                    local text = line and line:GetText()
                    if not text then
                        line = _G["RematchGameTooltipTextLeft" .. i]
                        text = line and line:GetText()
                    end
                    if text and not isSecret(text) and text:trim() ~= "" then
                        local r, g, b = line:GetTextColor()
                        self:AddLine(text, r, g, b)
                    end
                end
            end
            if source then source:Hide() end
        end
        R.tooltip.__secretFixClone = true
    end

    return true
end

--------------------------------------------------------------------------
-- /rsf -- say what actually took effect, so a bug report can be specific
--------------------------------------------------------------------------
local function mark(ok)
    return ok and "|cff20ff20applied|r" or "|cffff2020NOT applied|r"
end

SLASH_RSF1 = "/rsf"
SLASH_RSF2 = "/rematchsecretfix"
SlashCmdList["RSF"] = function()
    local R = _G.Rematch
    local ver = "?"
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        ver = C_AddOns.GetAddOnMetadata("Rematch", "Version") or "?"
    end

    print("|cff58C6FARematchSecretFix|r status:")
    print(("  MouseIsOver       %s"):format(state.mouseIsOver or "?"))

    if not R then
        print("  |cffff2020Rematch is not loaded|r - nothing to patch."
            .. " This addon is only useful alongside Rematch.")
        return
    end
    print(("  Rematch           found, version %s"):format(tostring(ver)))

    -- read the live markers rather than what we remember doing, in case
    -- something else replaced a function after us
    local ti = R.targetInfo
    print(("  GetUnitNpcID      %s   (target detection in instances)")
        :format(mark(ti and ti.__secretFixNpcID)))
    print(("  GetNpcName        %s   (names in the Teams List)")
        :format(mark(ti and ti.__secretFixNpcName)))
    print(("  CloneGameTooltip  %s   (tooltips)")
        :format(mark(R.tooltip and R.tooltip.__secretFixClone)))

    if issecretvalue == nil then
        print("  |cffffd200note|r  issecretvalue() is absent on this client,"
            .. " so the secret-value guards will never trigger. Harmless.")
    end
end

if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Rematch") then
    applyFixes()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name == "Rematch" and applyFixes() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
