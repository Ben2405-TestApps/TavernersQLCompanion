local ADDON,ns=...
local Core=_G.TavernersCore
if not Core then return end
local Ref=ns and ns.QuestData or {}
local DB=Core.Database:Register("TavernersQLCompanionDB",{version=2,zoneFavourites={},tracked={}},2)
local A={db=DB,active={},zones=Ref.zones or {},questData=Ref.dungeonQuests or {}}
local QuestDB, NpcDB, ObjectDB, ItemDB
local searchBox, databaseReady=false,nil
local questIndex, questById = {}, {}
local function BindQuestDatabase()
 local lib=_G.LibQuestieDB
 if type(lib)~="table" or type(lib.Quest)~="table" then return false end
 local qdb=lib.Quest
 if type(qdb.GetAllIds)~="function" or type(qdb.name)~="function" then return false end
 QuestDB=qdb; NpcDB=lib.Npc or _G.NpcDB; ObjectDB=lib.Object or _G.ObjectDB; ItemDB=lib.Item or _G.ItemDB
 return true
end
local function SafeGet(db,field,id)
 if db and type(db[field])=="function" then
  local ok,value=pcall(db[field],id)
  if ok then return value end
 end
end
local function AddObjective(out,text)
 if text and text~="" then out[#out+1]=tostring(text) end
end
local function SpawnSummary(db,id)
 local spawns=SafeGet(db,"spawns",id)
 if type(spawns)~="table" then return nil end
 local areaIds={}
 for areaId in pairs(spawns) do areaIds[#areaIds+1]=areaId end
 table.sort(areaIds)
 local area=areaIds[1]
 local points=area and spawns[area]
 if type(points)~="table" or not points[1] then return area and ("Area #"..tostring(area)) or nil end
 local coords={}
 for i=1,math.min(2,#points) do
  local p=points[i]
  if type(p)=="table" then coords[#coords+1]=string.format("%.1f, %.1f",tonumber(p[1]) or 0,tonumber(p[2]) or 0) end
 end
 local areaName
 if C_Map and C_Map.GetAreaInfo then
  local ok,name=pcall(C_Map.GetAreaInfo,area)
  if ok then areaName=name end
 end
 return tostring(areaName or ("Area #"..tostring(area)))..(#coords>0 and (" ("..table.concat(coords,"; ")..")") or "")
end
local function BuildStarterLines(qid)
 local out={}
 local starter=SafeGet(QuestDB,"startedBy",qid) or {}
 for _,id in ipairs(starter[1] or {}) do
  local name=SafeGet(NpcDB,"name",id) or ("NPC "..id)
  AddObjective(out,"Starts: "..name..(SpawnSummary(NpcDB,id) and (" — "..SpawnSummary(NpcDB,id)) or ""))
  if #out>=6 then return out end
 end
 for _,id in ipairs(starter[2] or {}) do
  local name=SafeGet(ObjectDB,"name",id) or ("Object "..id)
  AddObjective(out,"Starts from object: "..name..(SpawnSummary(ObjectDB,id) and (" — "..SpawnSummary(ObjectDB,id)) or ""))
  if #out>=6 then return out end
 end
 for _,id in ipairs(starter[3] or {}) do
  local name=SafeGet(ItemDB,"name",id) or ("Item "..id)
  AddObjective(out,"Starts from item: "..name)
  if #out>=6 then return out end
 end
 return out
end
local function BuildObjectiveLines(qid)
 local out={}
 local lines=SafeGet(QuestDB,"objectivesText",qid)
 if type(lines)=="table" then for _,line in ipairs(lines) do AddObjective(out,line) end end
 local data=SafeGet(QuestDB,"objectives",qid) or {}
 local function entityName(db,id,fallback)
  return SafeGet(db,"name",id) or fallback or ("ID "..tostring(id))
 end
 for _,row in ipairs(data[1] or {}) do
  AddObjective(out,"Kill "..tostring(row[2] or entityName(NpcDB,row[1])).." — "..tostring(row[3] or 0)..(SpawnSummary(NpcDB,row[1]) and (" • "..SpawnSummary(NpcDB,row[1])) or ""))
 end
 for _,row in ipairs(data[2] or {}) do
  AddObjective(out,"Use / interact with "..tostring(row[2] or entityName(ObjectDB,row[1])).." — "..tostring(row[3] or 0)..(SpawnSummary(ObjectDB,row[1]) and (" • "..SpawnSummary(ObjectDB,row[1])) or ""))
 end
 for _,row in ipairs(data[3] or {}) do
  AddObjective(out,"Collect "..tostring(row[2] or entityName(ItemDB,row[1])).." — "..tostring(row[3] or 0))
 end
 if data[4] then AddObjective(out,"Reputation objective — "..tostring(data[4][2] or "")) end
 for _,row in ipairs(data[5] or {}) do
  AddObjective(out,"Kill credit: "..tostring(row[3] or entityName(NpcDB,row[2]))..(SpawnSummary(NpcDB,row[2]) and (" • "..SpawnSummary(NpcDB,row[2])) or ""))
 end
 for _,row in ipairs(data[6] or {}) do
  AddObjective(out,"Cast spell objective — "..tostring(row[2] or ("spell "..tostring(row[1] or 0)))..(tonumber(row[3]) and row[3]>0 and (" (item "..row[3]..")") or ""))
 end
 for _,row in ipairs(SafeGet(QuestDB,"extraObjectives",qid) or {}) do
  AddObjective(out,"Special: "..tostring(row[3] or "Hidden objective"))
 end
 return out
end
function A:BuildDatabase(force)
 if self.databaseBuilt and not force then return true end
 if not BindQuestDatabase() then self.databaseBuilt=false; return false end
 local ok,ids=pcall(QuestDB.GetAllIds)
 if not ok or type(ids)~="table" then self.databaseBuilt=false; return false end
 local index,byId={},{}
 for _,id in ipairs(ids) do
  local name=SafeGet(QuestDB,"name",id)
  if name and name~="" then
   local row={
    id=id,name=name,
    requiredLevel=SafeGet(QuestDB,"requiredLevel",id) or 0,
    questLevel=SafeGet(QuestDB,"questLevel",id) or 0,
    zoneOrSort=SafeGet(QuestDB,"zoneOrSort",id) or 0,
    objectiveText=SafeGet(QuestDB,"objectivesText",id) or {},
    prerequisites=SafeGet(QuestDB,"preQuestSingle",id) or {},
    groupedPrerequisites=SafeGet(QuestDB,"preQuestGroup",id) or {},
    childQuests=SafeGet(QuestDB,"childQuests",id) or {},
    nextQuestInChain=SafeGet(QuestDB,"nextQuestInChain",id) or 0,
   }
   index[#index+1]=row; byId[id]=row
  end
 end
 self.databaseBuilt=true; self.databaseCount=#index; self.database= index; self.databaseById=byId
 questIndex=index; questById=byId; databaseReady=true
 return true
end
function A:GetQuestById(id)
 if not self.databaseBuilt then self:BuildDatabase() end
 return self.databaseById and self.databaseById[tonumber(id)] or nil
end
function A:SearchDatabase(query,limit)
 if not self.databaseBuilt and not self:BuildDatabase() then return {},0 end
 query=tostring(query or ""):lower()
 local out={}; local cap=tonumber(limit) or 60
 for _,q in ipairs(self.database or {}) do
  local hit=query=="" or q.name:lower():find(query,1,true)
  if not hit and query~="" then
   for _,line in ipairs(q.objectiveText or {}) do if tostring(line):lower():find(query,1,true) then hit=true; break end end
  end
  if hit then out[#out+1]=q; if #out>=cap then break end end
 end
 return out,self.databaseCount or 0
end
function A:GetQuestieStatus()
 return type(_G.Questie)=="table" and type(_G.Questie.API)=="table" and _G.Questie.API.isReady==true
end

function A:Scan()
 self.active={}
 for i=1,(GetNumQuestLogEntries and GetNumQuestLogEntries() or 0) do
  local title,level,_,header,_,complete,_,qid=GetQuestLogTitle(i)
  if title and not header then
   local q={title=title,level=level,complete=complete and true or false,id=qid or title,objectives={}}
   for j=1,(GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0) do
    local t,_,done=GetQuestLogLeaderBoard(j,i); if t then q.objectives[#q.objectives+1]={text=t,done=done} end
   end
   self.active[#self.active+1]=q
  end
 end
end
function A:GetActiveCount() return #self.active end
function A:GetDungeonQuests(dungeonName)
 local out={}
 local target=tostring(dungeonName or ""):lower():gsub("’","'"):gsub("%s+"," ")
 local aliases={
  ["the stockades"]="the stockade",
  ["temple of atal'hakkar"]="sunken temple",
  ["the temple of atal'hakkar"]="sunken temple",
  ["dire maul"]="dire maul east",
  ["dire maul (east)"]="dire maul east",
  ["dire maul (west)"]="dire maul west",
  ["dire maul (north)"]="dire maul north",
  ["lower blackrock spire"]="lower blackrock spire",
  ["upper blackrock spire"]="upper blackrock spire",
 }
 local wanted=aliases[target] or target
 local function matches(key)
  if key==wanted then return true end
  if target=="dire maul" then return key=="dire maul east" or key=="dire maul west" or key=="dire maul north" end
  if target=="lower blackrock spire" then return key=="lower blackrock spire" end
  if target=="upper blackrock spire" then return key=="upper blackrock spire" end
  return false
 end
 for _,q in ipairs(self.questData) do
  local key=tostring(q.dungeon or ""):lower():gsub("’","'"):gsub("%s+"," ")
  if not dungeonName or matches(key) then out[#out+1]=q end
 end
 return out
end
function A:GetActiveRouteStops()
 if not BindQuestDatabase() then return {},false end
 local stops,seen={},{}
 local function collect(db,id,questTitle,labelText)
  local spawns=SafeGet(db,"spawns",id)
  if type(spawns)~="table" then return end
  for areaId,points in pairs(spawns) do
   if type(points)=="table" then
    for _,p in ipairs(points) do
     if type(p)=="table" and tonumber(p[1]) and tonumber(p[2]) then
      local x,y=tonumber(p[1]),tonumber(p[2])
      local key=tostring(areaId)..":"..tostring(id)..":"..string.format("%.2f:%.2f",x,y)
      if not seen[key] then
       seen[key]=true
       local zoneName
       if C_Map and C_Map.GetAreaInfo then local ok,n=pcall(C_Map.GetAreaInfo,areaId); if ok then zoneName=n end end
       stops[#stops+1]={areaId=tonumber(areaId) or 0,zone=zoneName or ("Area #"..tostring(areaId)),
        x=x,y=y,quest=questTitle,objective=labelText}
      end
     end
    end
   end
  end
 end
 for _,q in ipairs(self.active or {}) do
  local data=SafeGet(QuestDB,"objectives",q.id) or {}
  for _,row in ipairs(data[1] or {}) do collect(NpcDB,row[1],q.title,row[2] or "Creature objective") end
  for _,row in ipairs(data[2] or {}) do collect(ObjectDB,row[1],q.title,row[2] or "Object objective") end
  for _,row in ipairs(data[5] or {}) do collect(NpcDB,row[2],q.title,row[3] or "Kill-credit objective") end
 end
 table.sort(stops,function(a,b)
  if a.areaId~=b.areaId then return a.areaId<b.areaId end
  if a.x~=b.x then return a.x<b.x end
  return a.y<b.y
 end)
 return stops,true
end
function A:GetDashboardSummary()
 local total=self.databaseCount or #self.questData
 local source=self.databaseBuilt and "Forever quest database" or "curated dungeon index"
 return #self.active.." active quests • "..total.." quests available ("..source..")"
end
function A:SuggestedZones()
 local level=UnitLevel("player"); local faction=UnitFactionGroup and UnitFactionGroup("player") or "Horde"; local out={}
 for _,z in ipairs(self.zones) do if level>=z.lo and level<=z.hi and (z.f=="Both" or z.f==faction) then out[#out+1]=z end end
 return out
end
Core:RegisterModule("QuestCompanion",A)
local frame,content,tab
local function label(parent,t,y,font)
 local fs=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight"); fs:SetPoint("TOPLEFT",8,y); fs:SetWidth(630); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true); fs:SetText(t); return fs
end
local function refresh()
 if not content then return end
 for _,v in ipairs(content.rows or {}) do v:Hide(); v:SetParent(nil) end; content.rows={}; local y=-5
 local function add(t,f) local v=label(content,t,y,f); content.rows[#content.rows+1]=v; y=y-v:GetStringHeight()-8 end
 if tab=="zones" then
  add("LEVEL "..UnitLevel("player").." • "..(UnitFactionGroup("player") or "Faction"),"GameFontNormal")
  for _,z in ipairs(A:SuggestedZones()) do add(z.name.." ("..z.lo.."-"..z.hi..")","GameFontNormal"); add(z.note) end
  add("Zone ranges are Wowhead's recommended content ranges, not a guaranteed fastest route.")
 elseif tab=="database" then
  local results,total=A:SearchDatabase(searchBox and searchBox:GetText() or "",60)
  add("FOREVER QUEST DATABASE • "..tostring(total).." quests available","GameFontNormal")
  add(A:GetQuestieStatus() and "Questie is ready — map pins and its native tracker are active." or "Questie not detected/ready. Install Questie + QuestieDB for map markers and full tracking.")
  if not A.databaseBuilt then add("Quest database is unavailable. Install the Forever-compatible QuestieDB addon and restart the game.") end
  for _,q in ipairs(results) do
   local zoneName
   if q.zoneOrSort and q.zoneOrSort>0 and C_Map and C_Map.GetAreaInfo then
    local ok,name=pcall(C_Map.GetAreaInfo,q.zoneOrSort); if ok then zoneName=name end
   end
   add(q.name.."  •  ID "..q.id.."  •  Level "..tostring(q.questLevel or q.requiredLevel or "?")..(zoneName and (" • "..zoneName) or ""),"GameFontNormal")
   for _,line in ipairs(BuildStarterLines(q.id)) do add("   "..line,"GameFontHighlightSmall") end
   for _,line in ipairs(q.objectiveText or {}) do add("   "..tostring(line),"GameFontHighlightSmall") end
   local objectiveDetails=BuildObjectiveLines(q.id)
   if #objectiveDetails>0 then for _,line in ipairs(objectiveDetails) do add("   - "..line,"GameFontHighlightSmall") end end
   if #q.prerequisites>0 then add("   Any one prerequisite: "..table.concat(q.prerequisites,", "),"GameFontHighlightSmall") end
   if #q.groupedPrerequisites>0 then add("   All required prerequisites: "..table.concat(q.groupedPrerequisites,", "),"GameFontHighlightSmall") end
   if #q.childQuests>0 then add("   Unlocks quest IDs: "..table.concat(q.childQuests,", "),"GameFontHighlightSmall") end
   if q.nextQuestInChain and q.nextQuestInChain>0 then add("   Next in chain: quest "..q.nextQuestInChain,"GameFontHighlightSmall") end
  end
  if #results==0 then add("No matching quests. Try a shorter name or objective keyword.") end
  if #results>=60 then add("Showing the first 60 matches. Refine the search to narrow the results.") end
 elseif tab=="route" then
  local stops,ready=A:GetActiveRouteStops()
  add("ACTIVE QUEST OBJECTIVE ROUTE • "..#stops.." KNOWN SPAWN POINTS","GameFontNormal")
  add("Stops are grouped by area and sorted by map coordinates. They are QuestieDB spawn hints, not a live GPS route; Questie remains responsible for map pins.")
  if not ready then add("QuestieDB is not available. Install the Forever-compatible QuestieDB library to build objective locations.") end
  local lastArea=nil
  for i,stop in ipairs(stops) do
   if i>50 then break end
   if stop.areaId~=lastArea then add(stop.zone,"GameFontNormal"); lastArea=stop.areaId end
   add(string.format("%02d. %.1f, %.1f — %s",i,stop.x,stop.y,stop.objective or "Objective"),"GameFontHighlight")
   add("Quest: "..tostring(stop.quest),"GameFontHighlightSmall")
  end
  if #stops==0 and ready then add("No active quest objectives with known creature/object spawn coordinates were found. Check the All Quests tab for starter and objective details.") end
  if #stops>50 then add("Showing first 50 locations. The full list may be larger.") end
 elseif tab=="dungeons" then
  add("DUNGEON QUEST REFERENCE • "..#A.questData.." curated records","GameFontNormal")
  local faction=UnitFactionGroup and UnitFactionGroup("player") or "Horde"
  for _,q in ipairs(A.questData) do if q.faction=="Both" or q.faction==faction then
   add(q.name.." — quest level "..tostring(q.level or "?"),"GameFontNormal")
   add(q.dungeon.." • "..tostring(q.giver or "?").." • "..tostring(q.location or "Location not listed"))
   if q.coords then add("Coordinates: "..q.coords) end
   if q.prerequisite then add("Prerequisite: "..q.prerequisite) end
  end end
  add("Curated 249-entry reference; class-only and some less common variants still need verification. Check Wowhead for the latest prerequisites.")
 else
  add("ACTIVE QUEST LOG • "..#A.active.." quests","GameFontNormal")
  for _,q in ipairs(A.active) do add((q.complete and "|cff55dd77[Complete]|r " or "")..q.title.." (Level "..tostring(q.level or "?")..")","GameFontNormal"); for _,o in ipairs(q.objectives) do add("   "..(o.done and "✓ " or "• ")..o.text,"GameFontHighlightSmall") end end
  if #A.active==0 then add("No quests found. Accept a quest or open your quest log to refresh.") end
 end
 content:SetHeight(math.max(1,-y+20))
end
local function build()
 if frame then return end
 frame=CreateFrame("Frame","TavernersQLCompanionFrame",UIParent); frame:SetSize(700,500); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
 frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
 if frame.SetBackdrop then frame:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}}); frame:SetBackdropColor(.07,.05,.035,.97) end
 local title=label(frame,"|cffffd27aThe Taverners|r — Quest & Leveling Companion",-18,"GameFontNormalLarge"); title:SetWidth(600)
 local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
 local function btn(t,x,k) local b=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate"); b:SetSize(120,24); b:SetPoint("TOPLEFT",x,-48); b:SetText(t); b:SetScript("OnClick",function()
  tab=k
  if searchBox then if k=="database" then searchBox:Show(); A:BuildDatabase() else searchBox:Hide() end end
  refresh()
 end) end
 btn("Active Quests",18,"quests"); btn("Leveling Zones",145,"zones"); btn("Dungeon Quests",272,"dungeons"); btn("All Quests",399,"database"); btn("Quest Route",526,"route")
 searchBox=CreateFrame("EditBox","TavernersQLCSearch",frame,"InputBoxTemplate")
 searchBox:SetSize(260,24); searchBox:SetPoint("TOPLEFT",18,-78); searchBox:SetAutoFocus(false); searchBox:SetText(""); searchBox:Hide()
 searchBox:SetScript("OnTextChanged",function() if tab=="database" then refresh() end end)
 local s=CreateFrame("ScrollFrame","TavernersQLCScroll",frame,"UIPanelScrollFrameTemplate"); s:SetPoint("TOPLEFT",18,-112); s:SetPoint("BOTTOMRIGHT",-36,18)
 content=CreateFrame("Frame",nil,s); content:SetSize(640,1); s:SetScrollChild(content)
end
A.UI={Toggle=function() build(); if frame:IsShown() then frame:Hide() else frame:Show(); A:Scan(); refresh() end end,Refresh=refresh}
local ev=CreateFrame("Frame"); ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("QUEST_LOG_UPDATE"); ev:RegisterEvent("QUEST_ACCEPTED"); ev:RegisterEvent("QUEST_TURNED_IN")
ev:SetScript("OnEvent",function(_,event)
 if event=="PLAYER_LOGIN" then
  A:Scan()
  if _G.Questie and _G.Questie.API and _G.Questie.API.RegisterOnReady then
   pcall(_G.Questie.API.RegisterOnReady,function()
    if _G.Questie.API.RegisterForQuestUpdates then
     pcall(_G.Questie.API.RegisterForQuestUpdates,function() A:Scan(); if frame and frame:IsShown() then refresh() end end)
    end
   end)
  end
 else A:Scan() end
 if frame and frame:IsShown() then refresh() end
end)
SLASH_TAVERNERSQLCOMPANION1="/tquest"; SLASH_TAVERNERSQLCOMPANION2="/tqlc"; SlashCmdList=SlashCmdList or {}
SlashCmdList.TAVERNERSQLCOMPANION=function() A.UI:Toggle() end
