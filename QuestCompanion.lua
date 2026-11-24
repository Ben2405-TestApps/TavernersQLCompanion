local ADDON,ns=...
local Core=_G.TavernersCore
if not Core then return end
local DB=Core.Database:Register("TavernersQLCompanionDB",{version=1,zoneFavourites={},tracked={}},1)
local Zones={
 {name="Durotar",lo=1,hi=10,f="Horde",note="Sen'jin Village and Razor Hill starting quests."},
 {name="Mulgore",lo=1,hi=10,f="Horde",note="Bloodhoof Village and the surrounding plains."},
 {name="Tirisfal Glades",lo=1,hi=10,f="Horde",note="Deathknell and Brill quest hubs."},
 {name="The Barrens",lo=10,hi=25,f="Horde",note="Use Crossroads as a hub; group nearby objectives."},
 {name="Silverpine Forest",lo=10,hi=20,f="Horde",note="Quest around The Sepulcher and nearby settlements."},
 {name="Stonetalon Mountains",lo=15,hi=27,f="Both",note="Useful follow-on from the Barrens; watch higher-level pockets."},
 {name="Thousand Needles",lo=25,hi=35,f="Both",note="Shimmering Flats provides a useful quest hub."},
 {name="Arathi Highlands",lo=30,hi=40,f="Both",note="Mix local quests with nearby dungeon preparation."},
 {name="Stranglethorn Vale",lo=30,hi=45,f="Both",note="Group nearby objectives to reduce travel."},
 {name="Tanaris",lo=40,hi=50,f="Both",note="Gadgetzan is the main hub; combine objectives by sub-area."},
 {name="Felwood",lo=48,hi=55,f="Both",note="Later leveling zone with linked quest chains."},
 {name="Un'Goro Crater",lo=48,hi=55,f="Both",note="Group collectible objectives into efficient circuits."},
 {name="Western Plaguelands",lo=50,hi=60,f="Both",note="Follow linked quest hubs and watch for elite objectives."},
 {name="Eastern Plaguelands",lo=55,hi=60,f="Both",note="Bring suitable consumables and group for tougher objectives."},
}
local A={db=DB,active={},zones=Zones}
function A:Scan()
 self.active={}
 for i=1,(GetNumQuestLogEntries and GetNumQuestLogEntries() or 0) do
  local title,level,tag,_,header,_,complete,_,qid=GetQuestLogTitle(i)
  if title and not header then
   local q={title=title,level=level,complete=complete and true or false,id=qid or title,objectives={}}
   if GetNumQuestLeaderBoards then
    for j=1,(GetNumQuestLeaderBoards(i) or 0) do local t,_,done=GetQuestLogLeaderBoard(j,i); if t then q.objectives[#q.objectives+1]={text=t,done=done} end end
   end
   self.active[#self.active+1]=q
  end
 end
end
function A:SuggestedZones()
 local level=UnitLevel("player"); local faction=UnitFactionGroup and UnitFactionGroup("player") or "Horde"; local out={}
 for _,z in ipairs(Zones) do if level>=z.lo and level<=z.hi and (z.f=="Both" or z.f==faction) then out[#out+1]=z end end
 return out
end
Core:RegisterModule("QuestCompanion",A)
local frame,content,tab
local function label(parent,text,y,font)
 local fs=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight"); fs:SetPoint("TOPLEFT",8,y); fs:SetWidth(630); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true); fs:SetText(text); return fs
end
local function refresh()
 if not content then return end
 for _,v in ipairs(content.rows or {}) do v:Hide(); v:SetParent(nil) end; content.rows={}
 local y=-5
 local function add(t,f) local v=label(content,t,y,f); content.rows[#content.rows+1]=v; y=y-v:GetStringHeight()-9 end
 if tab=="zones" then
  add("LEVEL "..UnitLevel("player").." • "..(UnitFactionGroup("player") or "Faction"),"GameFontNormal")
  for _,z in ipairs(A:SuggestedZones()) do add(z.name.." ("..z.lo.."-"..z.hi..")"..(DB.zoneFavourites[z.name] and " ★" or ""),"GameFontNormal"); add(z.note) end
  add("Zone ranges are broad guidance, not a complete quest route.")
 else
  add("ACTIVE QUEST LOG • "..#A.active.." quests","GameFontNormal")
  for _,q in ipairs(A.active) do add((q.complete and "|cff55dd77[Complete]|r " or "")..q.title.." (Level "..tostring(q.level or "?")..")","GameFontNormal"); for _,o in ipairs(q.objectives) do add("   "..(o.done and "✓ " or "• ")..o.text,"GameFontHighlightSmall") end end
  if #A.active==0 then add("No quests found. Accept a quest or open your quest log to refresh.") end
 end
 content:SetHeight(math.max(1,-y+20))
end
local function build()
 if frame then return end
 frame=CreateFrame("Frame","TavernersQLCompanionFrame",UIParent); frame:SetSize(700,500); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
 if frame.SetBackdrop then frame:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}}); frame:SetBackdropColor(.07,.05,.035,.97) end
 local title=label(frame,"|cffffd27aThe Taverners|r — Quest & Leveling Companion",-18,"GameFontNormalLarge"); title:SetWidth(600)
 local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
 local function btn(txt,x,fn) local b=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate"); b:SetSize(120,24); b:SetPoint("TOPLEFT",x,-48); b:SetText(txt); b:SetScript("OnClick",fn) end
 btn("Active Quests",18,function() tab="quests"; refresh() end); btn("Leveling Zones",145,function() tab="zones"; refresh() end)
 local s=CreateFrame("ScrollFrame","TavernersQLCScroll",frame,"UIPanelScrollFrameTemplate"); s:SetPoint("TOPLEFT",18,-82); s:SetPoint("BOTTOMRIGHT",-36,18)
 content=CreateFrame("Frame",nil,s); content:SetSize(640,1); s:SetScrollChild(content)
end
A.UI={Toggle=function() build(); if frame:IsShown() then frame:Hide() else frame:Show(); A:Scan(); refresh() end end,Refresh=refresh}
local ev=CreateFrame("Frame"); ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("QUEST_LOG_UPDATE"); ev:RegisterEvent("QUEST_ACCEPTED"); ev:RegisterEvent("QUEST_TURNED_IN")
ev:SetScript("OnEvent",function() A:Scan(); if frame and frame:IsShown() then refresh() end end)
SLASH_TAVERNERSQLCOMPANION1="/tquest"; SLASH_TAVERNERSQLCOMPANION2="/tqlc"; SlashCmdList=SlashCmdList or {}; SlashCmdList.TAVERNERSQLCOMPANION=function() A.UI:Toggle() end
