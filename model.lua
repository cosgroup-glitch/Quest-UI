QuestUI = {}
local Q = QuestUI
function Q.quote(text) return (text or ""):gsub("([$}{])", function(c) return "$"..c end) end
function Q.key(text) return (text or ""):lower():gsub("[^%w]", "") end
function Q.conditions(quest)
  local out = {}
  for _, c in ipairs(quest:conditions():list()) do
    out[#out + 1] = {description=c:description() or "", status=c:status(), tooltip=c:tooltip()}
  end
  return out
end
function Q.snapshot(log, remembered, confirmed)
  local quests, present = {}, {}
  for _, q in ipairs(log:list()) do
    local id, status = q:id(), q:status()
    present[id] = true
    quests[#quests + 1] = {id=id, title=q:title() or ("Quest " .. id), res=q:res(), status=status, modified=q:modified() or 0}
    if status ~= "pending" then remembered[id] = nil;if confirmed then confirmed[id]=nil end end
  end
  for id in pairs(remembered) do if not present[id] then remembered[id] = nil end end
  for id in pairs(confirmed or {}) do if not present[id] then confirmed[id]=nil end end
  local selected = log:selected()
  if selected then
    local id = selected:id()
    local conditions = Q.conditions(selected)
    -- These are plain snapshots, not handles whose reads go nil after deselection.
    local receipt=confirmed and confirmed[id]
    local fresh=receipt and receipt.widget:exists() and receipt.modified==selected:modified()
    if present[id] and selected:status() == "pending" and fresh then
      remembered[id] = {title=selected:title() or ("Quest " .. id), conditions=conditions, modified=selected:modified()}
    end
    return quests, {id=id, title=selected:title() or ("Quest " .. id), conditions=conditions,modified=selected:modified()}
  end
  return quests
end
function Q.questRows(quests, completed, search)
  local rows = {}
  search = (search or ""):lower()
  for _, q in ipairs(quests) do
    local isCompleted = q.status == "done" or q.status == "failed"
    if isCompleted == completed and q.title:lower():find(search, 1, true) then
      rows[#rows+1] = {id=q.id, icon=q.res, text=(q.status=="failed" and "[Failed] " or q.status=="disabled" and "[Disabled] " or "") .. q.title, modified=q.modified}
    end
  end
  table.sort(rows, function(a,b) if a.modified~=b.modified then return a.modified>b.modified end; return a.id<b.id end)
  return rows
end
function Q.giver(description)
  return description:match("Tell ([%w]+)") or description:match("Greet ([%w]+)")
      or description:match(" to ([%w]+)") or description:match(" at ([%w]+)")
end
function Q.helperRows(remembered, selectedId, credoId, readyFirst, quests)
  local stamps = {}; for _, q in ipairs(quests or {}) do stamps[q.id]=q.modified end
  local rows = {}
  for id, q in pairs(remembered) do
    local outstanding = 0
    for _, c in ipairs(q.conditions) do if c.status ~= "done" then outstanding=outstanding+1 end end
    for index,c in ipairs(q.conditions) do
      if c.status=="pending" then
        local ready = outstanding<=1
        rows[#rows+1]={id=id, title=q.title, description=c.description, tooltip=c.tooltip,
          current=id==selectedId, credo=id==credoId, ready=ready, endpoint=index==#q.conditions,
          stale=stamps[id]~=q.modified, giver=Q.giver(c.description)}
      end
    end
  end
  table.sort(rows,function(a,b)
    if a.current~=b.current then return a.current end
    if a.credo~=b.credo then return a.credo end
    if a.ready~=b.ready then return a.ready==readyFirst end
    if a.description~=b.description then return a.description<b.description end
    return a.id<b.id
  end)
  return rows
end
function Q.wrap(text, width)
  -- Conservative plain-text wrapping for the small objective HUD/catalogue.
  local out = {}
  width=math.max(12, math.floor(width))
  for paragraph in ((text or "").."\n"):gmatch("(.-)\n") do
    local line=""
    for word in paragraph:gmatch("%S+") do
      if #line>0 and #line+1+#word>width then out[#out+1]=line;line="" end
      while #word>width do
        if #line>0 then out[#out+1]=line;line="" end
        out[#out+1]=word:sub(1,width);word=word:sub(width+1)
      end
      if #word>0 then line=line=="" and word or (line.." "..word) end
    end
    out[#out+1]=line
  end
  return out
end
