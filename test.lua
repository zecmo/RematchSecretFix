local SAY = print
local SECRET = setmetatable({}, { __index=function() error("secret",0) end })
local sreg = { [SECRET]=true }
issecretvalue = function(v) return sreg[v]==true end
UNKNOWN = "Unknown"

local SPECIES, COMPANION = 1987, 116787
local mode = "open"
UnitExists = function() return mode ~= "none" end
UnitIsWildBattlePet = function() return mode ~= "npc" end
UnitBattlePetSpeciesID = function() return SPECIES end
C_PetJournal = { GetPetInfoBySpeciesID = function(sp)
    if sp ~= SPECIES then return nil end
    return "Deviate Flapper","icon",3,COMPANION end }
C_AddOns = { IsAddOnLoaded = function() return true end }
local evt
CreateFrame = function() return { RegisterEvent=function() end,
    UnregisterEvent=function() end, SetScript=function(_,_,f) evt=f end } end
SlashCmdList = {}
local chat = {}
local realprint = print
print = function(...) local p={} for i=1,select('#',...) do p[#p+1]=tostring((select(i,...))) end chat[#chat+1]=table.concat(p," ") end
C_AddOns = { IsAddOnLoaded = C_AddOns.IsAddOnLoaded,
             GetAddOnMetadata = function() return "5.3.1" end }
getmetatable("").__index.trim = function(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end

-- a stand-in Rematch with the 5.3.1 behaviour
local origNpcIDCalls, origNameCalls = 0, 0
Rematch = {
  targetData = { redirects = {} },
  targetInfo = {
    GetUnitNpcID = function(self, unit)
      origNpcIDCalls = origNpcIDCalls + 1
      if mode == "open" then return COMPANION end
      return nil                                   -- secret GUID: gives up
    end,
    GetNpcName = function(self, npcID)
      origNameCalls = origNameCalls + 1
      if mode == "secretname" then error("attempt to index a secret string value",0) end
      return "Real Name"
    end,
  },
  tooltip = { added = {}, AddLine = function(s,t) table.insert(s.added,t) end },
}
local pass, fail = 0, 0
local function ok(l,c,e) if c then pass=pass+1; SAY("  PASS  "..l) else fail=fail+1; SAY("  FAIL  "..l.."  got "..tostring(e)) end end

dofile("!RematchSecretFix/core.lua")
local ti = Rematch.targetInfo

mode = "open"
local r = ti:GetUnitNpcID("target")
ok("original succeeds -> shim passes through", r == COMPANION, r)

mode = "instance"
r = ti:GetUnitNpcID("target")
ok("original returns nil -> species fallback gives 116787", r == COMPANION, r)

Rematch.targetData.redirects[COMPANION] = 999
r = ti:GetUnitNpcID("target")
ok("redirect honoured", r == 999, r)
Rematch.targetData.redirects[COMPANION] = nil

mode = "npc"
r = ti:GetUnitNpcID("target")
ok("not a wild pet -> nil", r == nil, r)

mode = "secretname"
local g, n = pcall(ti.GetNpcName, ti, 116787)
ok("throwing GetNpcName -> no error, 'id 116787'", g and n == "id 116787", n)

mode = "open"
g, n = pcall(ti.GetNpcName, ti, 116787)
ok("working GetNpcName -> original result (cache preserved)", g and n == "Real Name", n)

-- tooltip clone
RematchGameTooltip = { NumLines=function() return 2 end, Hide=function() end }
local texts = { SECRET, "Real line" }
for i=1,2 do
  _G["RematchGameTooltipTextRight"..i] = { GetText=function() return texts[i] end, GetTextColor=function() return 1,1,1 end }
  _G["RematchGameTooltipTextLeft"..i]  = { GetText=function() return nil end, GetTextColor=function() return 1,1,1 end }
end
g = pcall(Rematch.tooltip.CloneGameTooltip, Rematch.tooltip)
ok("secret tooltip line skipped, no error", g and #Rematch.tooltip.added == 1
   and Rematch.tooltip.added[1] == "Real line", table.concat(Rematch.tooltip.added,"|"))

-- idempotency: applying twice must not double-wrap
local before = origNpcIDCalls
dofile("!RematchSecretFix/core.lua")
mode = "open" ; ti:GetUnitNpcID("target")
ok("re-running the shim does not double-wrap", origNpcIDCalls == before + 1,
   origNpcIDCalls - before)

ok("MouseIsOver restored when absent", type(MouseIsOver)=="function")
local probe = { IsMouseOver = function(_,a) return "called:"..tostring(a) end }
ok("MouseIsOver passes through to region:IsMouseOver", MouseIsOver(probe, 7) == "called:7")

-- ---- /rsf status command ----
C_AddOns.GetAddOnMetadata = function() return "5.3.1" end
local chat = {}
local realprint = print
print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts+1] = tostring((select(i, ...))) end
    chat[#chat+1] = table.concat(parts, " ")
end
local function flat() return (table.concat(chat, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

chat = {}
local ranOK = pcall(SlashCmdList["RSF"])
local out = flat()
print = realprint
ok("/rsf runs without error", ranOK)
ok("/rsf reports MouseIsOver", out:find("MouseIsOver") ~= nil, out)
ok("/rsf reports Rematch version", out:find("version 5%.3%.1") ~= nil, out)
ok("/rsf: GetUnitNpcID applied", out:find("GetUnitNpcID%s+applied") ~= nil, out)
ok("/rsf: GetNpcName applied", out:find("GetNpcName%s+applied") ~= nil, out)
ok("/rsf: CloneGameTooltip applied", out:find("CloneGameTooltip%s+applied") ~= nil, out)

-- with Rematch absent it must say so rather than error
local keep = Rematch
Rematch = nil
chat = {}
print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts+1] = tostring((select(i, ...))) end
    chat[#chat+1] = table.concat(parts, " ")
end
local ranOK2 = pcall(SlashCmdList["RSF"])
local out2 = flat()
print = realprint
Rematch = keep
ok("/rsf with no Rematch: no error", ranOK2)
ok("/rsf with no Rematch: says so", out2:find("Rematch is not loaded") ~= nil, out2)

SAY("")
SAY(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
