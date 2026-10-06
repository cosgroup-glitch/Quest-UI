-- Run from the addon directory with LuaJ's lua entry point.
for _, path in ipairs({'catalog.lua','model.lua','main.lua'}) do assert(loadfile(path)) end
dofile('model.lua')
local Q=QuestUI
local file=assert(io.open('main.lua'));local source=file:read('*a');file:close()
local function extract(first,last,env,name)
  local start=assert(source:find(first,1,true))
  local finish=assert(source:find(last,start+#first,true))
  return assert(load(source:sub(start,finish-1)..' return '..name,'regression','t',
    setmetatable(env,{__index=_G})))()
end
local widget={exists=function() return true end}
local conditions={{description=function() return 'Tell Sage' end,status=function() return 'pending' end,tooltip=function() end}}
local stamp=2
local quest={id=function() return 1 end,title=function() return 'Quest' end,
  status=function() return 'pending' end,modified=function() return stamp end,
  res=function() end,conditions=function() return {list=function() return conditions end} end}
local log={list=function() return {quest} end,selected=function() return quest end,get=function() return quest end}
local remembered={[1]={title='Quest',conditions={{description='Old',status='pending'}},modified=1}}
local confirmed={}
Q.snapshot(log,remembered,confirmed)
assert(remembered[1].modified==1,'unconfirmed data must not replace cache')
assert(Q.helperRows(remembered,1,nil,true,{{id=1,modified=2}})[1].stale,
  'selected stale snapshots must retain refresh indicator')
confirmed[1]={widget=widget,modified=2}
Q.snapshot(log,remembered,confirmed)
assert(remembered[1].modified==2 and remembered[1].conditions[1].description=='Tell Sage')
confirmed[1].widget={exists=function() return false end}
conditions[1].description=function() return 'Unconfirmed' end
Q.snapshot(log,remembered,confirmed)
assert(remembered[1].conditions[1].description=='Tell Sage','destroyed reply widget cannot confirm data')
confirmed[1].widget=widget
stamp=3
Q.snapshot(log,remembered,confirmed)
assert(remembered[1].modified==2,'later stamp requires a new objective reply')
conditions={};confirmed[1].modified=3
Q.snapshot(log,remembered,confirmed)
assert(#remembered[1].conditions==0,'confirmed empty reply must clear old objectives')
local pages={}
local function page(visible)
  local p={shown=visible,held=true}
  function p:exists() return true end
  function p:visible(v) self.shown=v;self.held=not v;return self end
  function p:revert() self.held=false;return self end
  return p
end
local a,b=page(false),page(true)
pages[a]=true;pages[b]=false
local restore=extract('local function restoreNativeTabs','local function openNativeLog',{},'restoreNativeTabs')
local tabState={nativeTabVisibility=pages}
restore(tabState)
assert(a.shown and not b.shown and not a.held and not b.held)
assert(tabState.nativeTabVisibility==nil)
local calls={}
local refresh=extract('local function refreshStep','local function catalogue',{
  Q=Q,selectQuest=function(_,id) calls[#calls+1]=id;return true end},'refreshStep')
Q.stopRefresh=function(s) s.refresh=nil end
local function state()
  return {refresh={ids={1},index=1,original=9,elapsed=0,settled=0},
    confirmed={},selected={id=1,modified=3,conditions={}},
    helperStatus={text=function(self,s) self.message=s end},session={quest=function() return log end}}
end
local s=state()
for _=1,39 do refresh(s) end
assert(s.refresh and #calls==0,'empty unconfirmed data must wait for reply')
refresh(s)
assert(not s.refresh and s.helperStatus.message:find('unconfirmed',1,true))
s=state();s.confirmed[1]={widget=widget,modified=3}
for _=1,4 do refresh(s) end
assert(not s.refresh and s.helperStatus.message=='Refresh finished.')
local actions={}
local actionsSource=assert(source:match('(hafen.event%(%)%:action%(%)%:on%("qsel",function%(event%).-)\n%-%-'))
local active=state()
local session={}
assert(load(actionsSource,'actions','t',setmetatable({Q=Q,states={[session]=active},
  hafen={event=function() return {action=function() return {on=function(_,_,fn) actions.qsel=fn end} end} end}},
  {__index=_G})))()
local event={widget=function() return {session=function() return session end} end}
active.sendingQuest=true;actions.qsel(event);assert(active.refresh)
active.sendingQuest=nil;actions.qsel(event)
assert(not active.refresh,'native selection must cancel before expected reply')
local messages={}
local receiptSource=assert(source:match('(hafen.event%(%)%:message%(%)%:on%("conds",function%(event%).-)\nlocal function open'))
active.session={quest=function() return log end}
assert(load(receiptSource,'receipts','t',setmetatable({states={[session]=active},
  hafen={event=function() return {message=function() return {on=function(_,_,fn) messages.conds=fn end} end} end}},
  {__index=_G})))()
local detail={session=function() return session end,parent=function() return {type=function() return 'QuestWnd' end} end}
messages.conds({widget=function() return detail end})
assert(active.confirmed[1].widget==detail and active.confirmed[1].modified==3)
local hide=true
local sheet={active=false,installs=0,releases=0}
-- Installed client has no sheet:installed(); keep this mock equally strict.
setmetatable(sheet,{__index=function(_,key) error('unsupported sheet method: '..key) end})
function sheet:install() self.active=true;self.installs=self.installs+1 end
function sheet:release() self.active=false;self.releases=self.releases+1 end
local syncStyle=extract('local function syncNativeStyle()','local function report',
  {nativeSheet=sheet,nativeSheetInstalled=false,hideNative={value=function() return hide end}},'syncNativeStyle')
syncStyle();assert(sheet.active and sheet.installs==1,'placement rule must stay installed between quest changes')
hide=false;syncStyle();assert(not sheet.active and sheet.releases==1,'turning suppression off must restore native placement')
hide=true;syncStyle();assert(sheet.active and sheet.installs==2)
local loadedRules
function sheet:load(rules) loadedRules=rules;return self end
local startupBegin=assert(source:find('local nativeSheet=ui:sheet()',1,true))
local startupEnd=assert(source:find('local function report',startupBegin,true))
sheet.active=false
assert(load(source:sub(startupBegin,startupEnd-1),'stylesheet-startup','t',setmetatable({
  ui={sheet=function() return sheet end},hideNative={value=function() return true end}},
  {__index=_G})))()
assert(sheet.active and loadedRules['@QView'].position.x==-100000,
  'stylesheet startup must work with installed-client methods and table position')
local showWindow=extract('local function show(w)','local function nativeObjectives',{},'show')
local opening={shown=false,opens=0,raises=0}
function opening:visible(value)
  if value==nil then return self.shown end
  self.shown=value;self.opens=self.opens+1;return self
end
function opening:raise() self.raises=self.raises+1;return self end
showWindow(opening)
showWindow(opening)
showWindow(opening)
assert(opening.opens==1 and opening.raises==3,'quest switches must not restart window opening animation')
opening.shown=false;showWindow(opening)
assert(opening.opens==2,'closed window must still reopen')
local hudState={hidden={},objectives={visible=function() return true end}}
local hideHUD=extract('local function nativeObjectives','local function selectQuest',
  {hideNative={value=function() return hide end}},'nativeObjectives')
local native=page(true)
hideHUD(hudState,native)
assert(not native.shown and hudState.hidden[native],'new HUD must be hidden immediately')
hudState.objectives.visible=function() return false end
local another=page(true);hideHUD(hudState,another)
assert(not another.shown,'native HUD must stay hidden when addon window is closed')
hide=false;hudState.hidden={};native.shown=true
hideHUD(hudState,native)
assert(native.shown,'hide-native preference must be respected')
local arrival
local login={ui=function() return {on=function(_,selector,key,fn)
  assert(selector=='@QView' and key=='Added');arrival=fn;return {off=function() end}
end} end,quest=function() return log end}
local shown=0
local setupStart=assert(source:find('  state.objectiveAdded=session:ui():on',1,true))
local setupEnd=assert(source:find('  local function face',setupStart,true))
assert(load(source:sub(setupStart,setupEnd-1),'arrival','t',setmetatable({
  state=hudState,session=login,states={[login]=hudState},
  auto={value=function() return true end},show=function() shown=shown+1 end,
  nativeObjectives=hideHUD},{__index=_G})))()
hide=true;arrival(native)
assert(shown==1 and not native.shown,'arrival must show addon and hide native without timer tick')
hudState.refresh={};arrival(native)
assert(shown==1,'refresh scan must not open objectives')
print('PASS: syntax, tab release, snapshots, refresh, HUD arrival, persistent visibility, placement-rule lifecycle, complete native suppression')
