local Q, ui = QuestUI, hafen.ui()
local states = {}
local options = hafen.client():options():addon()
local auto = options:boolean("show-objectives"):default(true):add()
local readyFirst = options:boolean("ready-first"):default(true):add()
local hideNative = options:boolean("hide-native-objectives"):default(true):add()
-- QView lives inside the client's AlignPanel, so its local position is not
-- screen-clamped. A sheet applies to new widgets at placement, before the
-- deferred Added callback can run. Keep the native HUD out of the viewport.
local nativeSheet=ui:sheet()
nativeSheet:load({["@QView"]={position={x=-100000,y=-100000}}})
local nativeSheetInstalled=false
local function syncNativeStyle()
  if hideNative:value() then
    if not nativeSheetInstalled then nativeSheet:install();nativeSheetInstalled=true end
  elseif nativeSheetInstalled then nativeSheet:release();nativeSheetInstalled=false end
end
syncNativeStyle()
local function report(text) hafen.log():write("Quest UI: " .. tostring(text)) end
local function step(fn)
  hafen.timer():after(0, function()
    local ok, err = pcall(fn)
    if not ok then report(err) end
  end)
end
local function first(session, selector)
  for _, w in ipairs(session:ui():matchAll(selector)) do if not w:owned() then return w end end
end
local function release(w)
  if w and w:exists() then w:parent(nil); w:position(nil); w:size(nil) end
end
local function button(parent, text, x, y, width, fn)
  local b = ui:button():parent(parent):position(x,y):size(width):text(text)
  b:on("Pressed", function() step(fn) end)
  return b
end
local function surface(parent, name, x,y,w,h)
  return ui:widget():parent(parent):name(name):position(x,y):size(w,h)
    :stock{bg={color={0,0,0,100}},border={color={120,105,60,170},width=1}}
end
local function window(state, name, title, x,y,w,h,geometry)
  local view = ui:window():parent(state.hud):name(name):title(title):position(x,y):size(w,h)
    :resizable(true):remember(geometry or name):visible(false)
  view:on("Close",function(event) event:preventDefault(); view:visible(false) end)
  return view
end
local function show(w)
  -- Window.show() restarts the fade-in even when already visible.
  -- Quest switches update this same window; only open it when hidden.
  if not w:visible() then w:visible(true) end
  w:raise()
end
local function nativeObjectives(state,native)
  if hideNative:value() and not state.hidden[native] then
    native:visible(false)
    state.hidden[native]=true
  end
end
local function selectQuest(state, id, scanning)
  if not state.session:exists() or (id~=nil and not state.session:quest():get(id)) then return false end
  if state.refresh and not scanning then Q.stopRefresh(state,false) end
  -- QuestWnd is normally an unbound tab. Send through its bound ancestor,
  -- exactly the route of its native list's qsel message, using no invented verb.
  local target = first(state.session,"@QuestWnd")
  while target and not target:id() do target=target:parent() end
  if not target then report("Quest Log is not ready yet"); return false end
  state.sendingQuest=true
  local ok,err=pcall(function() target:send("qsel",id) end)
  state.sendingQuest=nil
  if not ok then error(err) end
  return true
end
local function currentCredo(state)
  return state.session:char():credo():pursuing()
end
local function credoQuest(state)
  local credo=currentCredo(state)
  if credo and credo:questId() then selectQuest(state,credo:questId()) end
end
local function drawLines(g, lines, x,y,color)
  g:color(color or {235,235,235})
  for _, line in ipairs(lines) do g:text(line,x,y); y=y+17 end
  return y
end
local function restoreNativeTabs(state)
  for tab,visible in pairs(state.nativeTabVisibility or {}) do
    -- Restore the page, then drop the hide record so native showtab can
    -- select it again. These tabs carry no other edits from this addon.
    if tab:exists() then tab:visible(visible);tab:revert() end
  end
  state.nativeTabVisibility=nil
end
local function openNativeLog(state)
  local sheet=first(state.session,"@CharWnd")
  local quest=first(state.session,"@QuestWnd")
  if not sheet or not quest then report("Character-sheet Quest Log is not ready yet");return end
  local tab=quest:parent()
  -- Tabs have no activation verb in the Lua API. Show the existing native
  -- quest tab and hide its sibling tabs, without moving any native content.
  local tabs=state.session:ui():matchAll("@Tab")
  state.nativeTabVisibility=state.nativeTabVisibility or {}
  for _, other in ipairs(tabs) do
    if other:parent()==tab:parent() then
      if state.nativeTabVisibility[other]==nil then state.nativeTabVisibility[other]=other:visible() end
      other:visible(other==tab)
    end
  end
  tab:visible(true)
  sheet:visible(true):raise()
  state.nativeQuestTab=tab
  if not state.nativeTabHooks then
    state.nativeTabHooks={}
    for _, control in ipairs(state.session:ui():matchAll("@TB")) do
      local ancestor=control:parent()
      while ancestor and ancestor~=sheet do ancestor=ancestor:parent() end
      local picture=control:picture() or ""
      if ancestor==sheet and picture:find("gfx/hud/chr/",1,true) then
        state.nativeTabHooks[#state.nativeTabHooks+1]=control:on("Pressed",function()
          -- Remove the explicitly shown quest page before the client's normal
          -- tab click selects its page. It then manages the tabs itself again.
          restoreNativeTabs(state)
          state.nativeQuestTab=nil
        end)
      end
    end
  end
end
local function buildObjectives(state)
  -- New geometry key starts the corrected layout at Kami's content dimensions,
  -- while retaining the user's subsequent drags/resizes across addon reloads.
  local w=window(state,"objectives","Quest Objectives",10,250,224,277,"objectives-kami-v2")
  state.objectives=w
  local frame=ui:widget():parent(w):name("objective-frame"):position(-1,-1):size(227,235)
    :stock{bg={color={0,0,0,110}}}
  state.objectiveFrame=frame
  local pieces={}
  for _, name in ipairs({"tl","tr","bl","br","extvl","extvr","extht","exthb"}) do
    pieces[name]=hafen.asset():get("art/objectives/frame-"..name..".png")
  end
  frame:on("Draw",function(event)
    local g,fw,fh=event:g(),event:w(),event:h()
    g:color(255,255,255)
    g:image(pieces.tl,0,0,8,8);g:image(pieces.tr,fw-8,0,8,8)
    g:image(pieces.bl,0,fh-8,8,8);g:image(pieces.br,fw-8,fh-8,8,8)
    g:image(pieces.extht,8,0,fw-16,7);g:image(pieces.exthb,8,fh-7,fw-16,7)
    g:image(pieces.extvl,0,8,7,fh-16);g:image(pieces.extvr,fw-7,8,7,fh-16)
  end)
  local scroll=ui:scroll():parent(w):position(4,4):size(217,225)
  local body=ui:widget():parent(scroll):name("objective-body"):position(0,0):size(217,225)
  state.objectiveScroll, state.objectiveBody=scroll,body
  body:on("Draw",function(event)
    local g=event:g()
    for _, line in ipairs(state.objectiveLines or {}) do
      g:color(line.color);g:text(line.text,1,line.y,line.opts)
    end
  end)
  body:on("MouseDown",function(event)
    if event:button()==1 and event:y()<(state.objectiveTitleHeight or 20) then event:preventDefault();step(function() openNativeLog(state) end) end
  end)
  local function tab(name,tip,x,up,down,fn)
    local b=ui:button():parent(w):name(name):position(x,241)
      :image(hafen.asset():get("art/objectives/"..up..".png"),hafen.asset():get("art/objectives/"..down..".png"))
    b:tooltip(tip);b:on("Pressed",function() step(fn) end);return b
  end
  state.objLog=tab("open-log","Quest Log",7,"questu","questd",function() openNativeLog(state) end)
  state.objCredos=tab("open-credos","Credos",94,"skillu","skilld",function() show(state.credos) end)
  state.objCurrent=tab("current-credo","Load current credo quest objective",181,"currentu","currentd",function() credoQuest(state) end)
  -- IButton paints its own raster without drawing children. Keep the icon as
  -- a sibling picture above it; pictures let presses reach the button below.
  state.objCurrentIcon=ui:image():parent(w):name("current-credo-icon"):position(185,245):size(26,26):visible(false)
end
local function buildCredos(state)
  local w=window(state,"credos","Credos",500,300,680,440)
  state.credos=w
  state.catalogue=ui:scroll():parent(w):position(4,4):size(275,396)
  state.catalogInfo=ui:scroll():parent(w):position(289,4):size(386,396)
  state.catalogBody=surface(state.catalogInfo,"credo-description",0,0,365,350)
  state.catalogBody:on("Draw",function(event)
    local entry=state.catalogEntry
    if not entry then drawLines(event:g(),{"Select a credo to view its requirements", "and bonuses."},8,8);return end
    local g=event:g()
    g:color(255,255,255)
    g:image(hafen.asset():get(entry.image),8,8,120,130)
    local y=drawLines(g,{entry.name,state.catalogStatus or "Unavailable"},140,12,{255,230,130})
    y=150
    local width=math.max(15,math.floor((event:w()-20)/7))
    y=drawLines(g,Q.wrap(entry.description,width),8,y)+12
    y=drawLines(g,Q.wrap("Requires: "..(#entry.requires==0 and "None" or table.concat(entry.requires,", ")),width),8,y)+12
    y=drawLines(g,{"Bonuses:"},8,y,{255,255,100})
    for _, bonus in ipairs(entry.bonuses) do y=drawLines(g,Q.wrap("* "..bonus,width),8,y,{255,255,100}) end
  end)
  state.credoProgress=ui:label():parent(w):position(4,409):text("")
  state.catalogItems={}
end
local function buildHelper(state)
  local w=window(state,"helper","Quest Helper",187,50,390,360)
  state.helper=w
  state.helperScroll=ui:scroll():parent(w):position(4,35):size(382,285)
  state.helperBody=surface(state.helperScroll,"helper-list",0,0,360,280)
  state.helperBody:on("Draw",function(event)
    local g=event:g()
    for index,row in ipairs(state.helperRows or {}) do
      local y=(index-1)*42+3
      local color=row.ready and (row.current and {80,255,255} or {100,255,100}) or (row.current and {255,255,255} or {195,195,195})
      g:color(color)
      local prefix=row.credo and "[Credo] " or row.ready and "+ " or ""
      local label=prefix..row.description..(row.stale and " [refresh]" or "")
      local distance=row.distance and ("  "..row.distance) or ""
      local lines=Q.wrap(label,math.max(12,math.floor((event:w()-70)/7)))
      g:text(lines[1] or "",5,y)
      if lines[2] then g:text(lines[2],5,y+17) end
      if distance~="" then g:atext(distance,event:w()-5,y,1,0) end
    end
    if #(state.helperRows or {})==0 then drawLines(g,{"Open quests to collect their objectives.","Refresh all loads every pending quest."},8,8) end
  end)
  state.helperBody:on("MouseDown",function(event)
    if event:button()~=1 then return end
    local row=(state.helperRows or {})[math.floor(event:y()/42)+1]
    if row then event:preventDefault(); step(function() selectQuest(state,row.id) end) end
  end)
  state.helperBody:on("MouseMove",function(event)
    local row=(state.helperRows or {})[math.floor(event:y()/42)+1]
    state.helperBody:tooltip(row and (row.title.."\n"..row.description..(row.stale and "\nQuest changed since last viewed. Select it to refresh." or "")) or "")
  end)
  state.refreshButton=button(w,"Refresh all",4,4,110,function() Q.startRefresh(state) end)
  state.cancelButton=button(w,"Cancel",120,4,85,function() Q.stopRefresh(state,true) end)
  ui:check():parent(w):position(218,9):text("Ready first"):bind(readyFirst)
  state.helperStatus=ui:label():parent(w):position(4,331):text("")
end
local function dispose(state)
  if state.refresh then Q.stopRefresh(state,false) end
  if state.objectiveAdded then state.objectiveAdded:off() end
  restoreNativeTabs(state)
  for _, sub in ipairs(state.nativeTabHooks or {}) do sub:off() end
  -- Revert our QView hide rather than passing nil to the boolean setter.
  -- QViews carry only a visibility override from this addon; other addons'
  -- geometry/style levels are left alone by this owner-scoped undo.
  for w in pairs(state.hidden or {}) do if w:exists() then w:visible(true);w:revert() end end
  for _, key in ipairs({"objectivesButton","objectives","log","credos","helper"}) do
    local w=state[key];if w and w:exists() then w:destroy() end
  end
end
local function create(session)
  local hud=first(session,"@GameUI")
  if not hud or not session:character() then return end
  local state={session=session,character=session:character(),hud=hud,remembered={},confirmed={},quests={},hidden={},helperRows={}}
  states[session]=state
  buildObjectives(state);buildCredos(state);buildHelper(state)
  -- New quest HUDs arrive between timer ticks. Handle their arrival on the
  -- next UI step instead of leaving the native HUD up for up to 250 ms.
  state.objectiveAdded=session:ui():on("@QView","Added",function(native)
    if states[session]~=state or not native:exists() then return end
    if auto:value() and not state.refresh and session:quest():selected() then show(state.objectives) end
    nativeObjectives(state,native)
  end)
  local function face(suffix) return hafen.asset():get("art/objectives/rbtn-questobj"..suffix..".png") end
  state.objectivesButton=ui:check():parent(hud):name("objectives-toggle"):position(10,205)
    :image(face(""),face("-d"),face("-h"),face("-dh"))
    :value(state.objectives:visible()):remember("objectives-button")
    :tooltip("Quest Objectives")
  state.objectivesButton:on("Changed",function(checked)
    step(function() state.objectives:visible(checked);if checked then state.objectives:raise() end end)
  end)
  return state
end
local function stateFor(session)
  if not session or not session:exists() then return end
  local state=states[session]
  if state and (state.character~=session:character() or not state.hud:exists()) then dispose(state);states[session]=nil;state=nil end
  return state or create(session)
end
function Q.stopRefresh(state,restore)
  local scan=state.refresh
  if not scan then return end
  state.refresh=nil
  state.helperStatus:text("Refresh stopped.")
  -- Do not override a quest the user selected during the scan.
  if restore and (scan.original==nil or state.session:quest():get(scan.original)) then selectQuest(state,scan.original,true) end
end
function Q.startRefresh(state)
  if state.refresh then return end
  local selected=state.session:quest():selected()
  local ids={}
  for _, q in ipairs(state.session:quest():list()) do if q:status()=="pending" then ids[#ids+1]=q:id() end end
  if #ids==0 then state.helperStatus:text("No pending quests.");return end
  state.refresh={ids=ids,index=1,original=selected and selected:id(),elapsed=0,settled=0}
  state.helperStatus:text("Loading 1/"..#ids.."...")
  if not selectQuest(state,ids[1],true) then Q.stopRefresh(state,false) end
end
local function refreshStep(state)
  local scan=state.refresh
  if not scan then return end
  scan.elapsed=scan.elapsed+0.25
  local selected=state.selected
  local expected=scan.ids[scan.index]
  if selected and selected.id==expected then
    local signature={}
    for _,c in ipairs(selected.conditions) do signature[#signature+1]=c.description..tostring(c.status)..(c.tooltip or "") end
    local sig=table.concat(signature,"|")
    if scan.signature~=sig then scan.signature=sig;scan.settled=0 else scan.settled=scan.settled+0.25 end
    local confirmed=state.confirmed[expected]
    if not confirmed or not confirmed.widget:exists() or confirmed.modified~=selected.modified then
      if scan.elapsed<10 then return end
      scan.skipped=(scan.skipped or 0)+1
    elseif scan.settled<0.75 then
      if scan.elapsed<10 then return end
      scan.skipped=(scan.skipped or 0)+1
    end
  elseif scan.signature~=nil then
    Q.stopRefresh(state,false);state.helperStatus:text("Refresh stopped: quest selection changed.");return
  elseif scan.elapsed<5 then return
  else
    scan.skipped=(scan.skipped or 0)+1
  end
  scan.index=scan.index+1
  if scan.index>#scan.ids then
    state.refresh=nil
    state.helperStatus:text(scan.skipped and ("Refresh finished: "..scan.skipped.." unconfirmed; retry to load.") or "Refresh finished.")
    if scan.original==nil or state.session:quest():get(scan.original) then selectQuest(state,scan.original,true) end
    return
  end
  scan.elapsed,scan.settled,scan.signature=0,0,nil
  state.helperStatus:text("Loading "..scan.index.."/"..#scan.ids.."...")
  if not selectQuest(state,scan.ids[scan.index],true) then Q.stopRefresh(state,false) end
end
local function catalogue(state)
  local groups={Pursuing={},Available={},Acquired={},Unavailable={}}
  local live={}
  local pursuing=currentCredo(state)
  for _, cr in ipairs(state.session:char():credo():list()) do
    live[Q.key(cr:name())]=cr==pursuing and "Pursuing" or cr:acquired() and "Acquired" or "Available"
  end
  local signature={}
  for _, entry in ipairs(QuestUICatalog) do
    local status=live[Q.key(entry.name)] or "Unavailable"
    groups[status][#groups[status]+1]=entry
    signature[#signature+1]=entry.name..status
    if entry==state.catalogEntry then state.catalogStatus=status end
  end
  local sig=table.concat(signature,"|")
  if sig==state.catalogSignature then return end
  state.catalogSignature=sig
  for _, w in ipairs(state.catalogItems) do w:destroy() end
  state.catalogItems={}
  local y=0
  for _, group in ipairs({"Pursuing","Available","Acquired","Unavailable"}) do
    if #groups[group]>0 then
      local heading=ui:label():parent(state.catalogue):position(5,y):text(group)
      state.catalogItems[#state.catalogItems+1]=heading;y=y+24
      table.sort(groups[group],function(a,b) return a.name<b.name end)
      for index,entry in ipairs(groups[group]) do
        local x=((index-1)%4)*62+5
        local gy=y+math.floor((index-1)/4)*65
        local cell=surface(state.catalogue,"credo-"..Q.key(entry.name),x,gy,56,60)
        local asset=hafen.asset():get(entry.image)
        cell:tooltip(entry.name.." ("..group..")")
        cell:on("Draw",function(event)
          local g=event:g();g:color(255,255,255,group=="Unavailable" and 110 or 255)
          g:image(asset,3,3,50,54)
          if state.catalogEntry==entry then g:color(255,255,0);g:rect(0,0,56,60) end
        end)
        cell:on("MouseDown",function(event)
          if event:button()==1 then event:preventDefault();state.catalogEntry=entry;state.catalogStatus=group end
        end)
        state.catalogItems[#state.catalogItems+1]=cell
      end
      y=y+math.ceil(#groups[group]/4)*65+8
    end
  end
end
local function box(view,minw,minh)
  local sz=view:size();local w,h=math.max(minw,sz.w),math.max(minh,sz.h)
  if w~=sz.w or h~=sz.h then view:size(w,h) end
  return w,h
end
local function layout(state)
  local w,h=box(state.objectives,220,130)
  state.objectiveFrame:size(w+3,h-42)
  state.objectiveScroll:size(w-7,h-52)
  state.objLog:position(7,h-36);state.objCredos:position(94,h-36);state.objCurrent:position(181,h-36)
  state.objCurrentIcon:position(185,h-32)
  local width=w-9;local y=0;local lines={}
  local function line(text,color,gap)
    local opts={width=width}
    local measured=ui:measure(text,opts)
    lines[#lines+1]={text=text,color=color,y=y,opts=opts}
    y=y+measured.h+(gap or 0)
    return measured.h
  end
  local quest=state.selected
  if quest then
    state.objectiveTitleHeight=line("$b{$font[serif,16]{"..Q.quote(quest.title).."}}",{255,255,255},3)
    for _, c in ipairs(quest.conditions) do
      local prefix=c.status=="done" and "✓ " or c.status=="failed" and "✗ " or "• "
      local color=c.status=="done" and {64,255,64} or c.status=="failed" and {255,64,64} or {255,255,64}
      local text=prefix..c.description..(c.tooltip and c.tooltip~="" and (" "..c.tooltip) or "")
      line("$font[SansSerif,12]{"..Q.quote(text).."}",color)
    end
    if quest.id==state.credoId then y=y+5;line("$font[SansSerif,12]{"..state.progress.."}",{255,255,255}) end
  else
    state.objectiveTitleHeight=line("Select a quest in the Quest Log.",{255,255,255})
  end
  state.objectiveLines=lines
  state.objectiveBody:size(w-7,math.max(h-52,y+2))
  w,h=box(state.helper,360,170)
  state.helperScroll:size(w-8,h-78);state.helperBody:size(w-30,math.max(85,#state.helperRows*42+8))
  state.helperStatus:position(4,h-29)
  w,h=box(state.credos,620,260)
  state.catalogue:size(275,h-44);state.catalogInfo:size(w-294,h-44);state.credoProgress:position(4,h-31)
  width=w-315
  local entry=state.catalogEntry;local count=0
  if entry then
    count=#Q.wrap(entry.description,math.floor((width-20)/7))+#Q.wrap("Requires: "..table.concat(entry.requires,", "),math.floor((width-20)/7))+3
    for _, bonus in ipairs(entry.bonuses) do count=count+#Q.wrap("* "..bonus,math.floor((width-20)/7)) end
  end
  state.catalogBody:size(width,math.max(h-54,190+count*17))
end
local function update(state)
  state.quests,state.selected=Q.snapshot(state.session:quest(),state.remembered,state.confirmed)
  local cr=currentCredo(state)
  state.credoId=cr and cr:questId()
  state.progress=cr and string.format("Lv. %s/%s    Qt. %s/%s",cr:rank() or "?",cr:levelTotal() or "?",cr:questsDone() or "?",cr:questTotal() or "?") or ""
  local picture
  if cr then for _, entry in ipairs(QuestUICatalog) do if Q.key(entry.name)==Q.key(cr:name()) then picture=entry.image;break end end end
  if picture~=state.currentCredoPicture then
    state.currentCredoPicture=picture
    if picture then state.objCurrentIcon:source(hafen.asset():get(picture)) end
    state.objCurrentIcon:visible(picture~=nil)
  end
  state.credoProgress:text(cr and ((cr:name() or "Credo").."  "..state.progress) or "")
  state.objCurrent:enabled(state.credoId~=nil)
  state.objCurrentIcon:enabled(state.credoId~=nil)
  if state.selected and state.selected.id~=state.lastSelected then
    if auto:value() and not state.refresh then show(state.objectives) end
  end
  state.lastSelected=state.selected and state.selected.id
  state.helperRows=Q.helperRows(state.remembered,state.lastSelected,state.credoId,readyFirst:value(),state.quests)
  -- Read-only marker distances. No marker add/remove/color/onMap writes.
  local distances={}
  for _, row in ipairs(state.helperRows) do
    if row.giver then
      if distances[row.giver]==nil then
        local marker=hafen.map():marker():nearest(function(m) return m:name()==row.giver end)
        distances[row.giver]=marker and marker:distance() or false
      end
      local distance=distances[row.giver]
      -- Brodgar returns world units; Labyrinth's helper displays tile metres.
      row.distance=distance and string.format("%.0fm",distance/11) or nil
    end
  end
  catalogue(state);layout(state)
  local suppress=hideNative:value()
  for _, native in ipairs(state.session:ui():matchAll("@QView")) do
    nativeObjectives(state,native)
  end
  for native in pairs(state.hidden) do
    if not native:exists() then state.hidden[native]=nil
    elseif not suppress then native:visible(true);native:revert();state.hidden[native]=nil end
  end
  refreshStep(state)
  state.objectivesButton:value(state.objectives:visible())
  state.cancelButton:enabled(state.refresh~=nil);state.refreshButton:enabled(state.refresh==nil)
end
hafen.timer():every(0.25,function()
  syncNativeStyle()
  local session=hafen.session():current()
  local ok,err=pcall(function() local state=stateFor(session);if state then update(state) end end)
  if not ok then
    local state=states[session]
    if not state or state.lastError~=tostring(err) then report("Unavailable data skipped: "..tostring(err));if state then state.lastError=tostring(err) end end
  elseif states[session] then states[session].lastError=nil end
end)
hafen.event():on("SessionEnteredWorld",function(session)
  if states[session] then dispose(states[session]);states[session]=nil end
end)
hafen.event():on("SessionRemoved",function(session)
  if states[session] then dispose(states[session]);states[session]=nil end
end)
hafen.event():on("SessionSelected",function()
  -- The per-session windows follow their HUD automatically. Cancel pending
  -- helper scans rather than continuing to change a background character.
  for _, state in pairs(states) do if state.refresh then Q.stopRefresh(state,false) end end
end)
hafen.event():on("Disable",function()
  nativeSheet:release()
  nativeSheetInstalled=false
  for _, state in pairs(states) do dispose(state) end
  states={}
end)
-- Observe native selections immediately, including before a slow reply arrives.
-- Our sends are outside the character's input tree and bypass this stream.
hafen.event():action():on("qsel",function(event)
  local state=states[event:widget():session()]
  if state and state.refresh and not state.sendingQuest then
    Q.stopRefresh(state,false)
    state.helperStatus:text("Refresh stopped: quest selection changed.")
  end
end)
-- 'conds' is the native quest detail's objective reply. Observe it without
-- cancelling or rewriting; the next timer reads the applied conditions.
hafen.event():message():on("conds",function(event)
  local widget=event:widget()
  local state=states[widget:session()]
  if not state then return end
  local ancestor=widget:parent()
  while ancestor and ancestor:type()~="QuestWnd" do ancestor=ancestor:parent() end
  if not ancestor then return end
  local selected=state.session:quest():selected()
  if selected then state.confirmed[selected:id()]={widget=widget,modified=selected:modified()} end
end)
local function open(kind)
  local state=stateFor(hafen.session():current())
  if state then if kind=="log" then openNativeLog(state) else show(state[kind]) end;update(state) else report("Enter the world first") end
end
Q.open=function(kind) step(function() open(kind or "objectives") end) end
hafen.console():on("questui",function() Q.open("objectives") end)
local keys=hafen.client():options():keybindings()
for _, kind in ipairs({"objectives","log","credos","helper"}) do
  keys:on(kind,function() step(function()
    local state=stateFor(hafen.session():current())
    if state then if kind=="log" then openNativeLog(state) else local w=state[kind];w:visible(not w:visible());if w:visible() then w:raise() end end end
  end) end)
end
options:panel(function(root)
  root:gap(6)
  ui:check():parent(root):text("Show objectives when selecting a quest"):bind(auto)
  ui:check():parent(root):text("Hide native objectives completely"):bind(hideNative)
  ui:check():parent(root):text("Sort last remaining objectives first"):bind(readyFirst)
  for _, item in ipairs({{"objectives","Quest Objectives"},{"log","Quest Log"},{"credos","Credos"},{"helper","Quest Helper"}}) do
    local row=ui:row():parent(root):gap(8)
    ui:button():parent(row):size(160):text(item[2]):on("Pressed",function() Q.open(item[1]) end)
    ui:keybinding():parent(row):size(150):bind(keys:binding():get(item[1]))
  end
  ui:label():parent(root):text("Refresh all loads pending quests and restores the previous selection.")
end)
