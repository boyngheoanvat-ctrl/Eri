-- AutoDance HexControl v7.2 — FULL MINI GAME (Crazy Score Fix) 
-- Preserves v7.1 (rev9) 100% + FIX Crazy: repair curArrowsIndex + direct nowTotalScore additive + 0.3s refresh
-- Root cause: score pipeline nằm ở DynamicArrowsController.CalculateScore (RVA 0x16fe4ac, generic stub),
--   game chỉ cộng điểm khi group finish đúng flow; JudgeKey patch vô dụng (0 callers).
-- Fix: menu tự cộng nowTotalScore = noteBaseScore * comboRatio * số key perfect mỗi group, 0.3s/lần.

local state = {
  activeOn = false,
  taikoOn = false,
  miniOn = false,
  status = "Sẵn sàng. Bật toggle để chạy tự động qua các trận.",
  PERFECT = 4,
  stats = { modified = 0, taiko = 0, mini = 0, crazy = 0 },
  lastCheck = 0,
  lastCount = 0,
  lastTaikoCheck = 0,
  lastTaikoCount = 0,
  lastMiniCheck = 0,
  lastMiniCount = 0,
  -- v7.2 Crazy Score Fix state
  lastCrazyCheck = 0,
  crazyScore = 0,
  scoredGroups = {},
}

local originals = {}

-- ========== METHOD OFFSET TABLE ==========
local methodInfo = {
  { cls = "Dance.AuditionGroup", image = "HotFix.dll",
    fields = {
      { name = "judgeLevel", offset = 64, type = "eNoteJudgeLevel", mod = "set 4 (PERFECT)" },
      { name = "isHitBeat",  offset = 50, type = "Boolean",        mod = "set true" },
    },
    methods = {
      { name = "IsAllHit",       addr = "0x16d22b4", ret = "Boolean",  params = "()" },
      { name = "ResetArrowsHit", addr = "0x16fe4ac", ret = "Void",     params = "()" },
      { name = "CheckNextHit",   addr = "0x16e1764", ret = "Boolean",  params = "(AuditionArrowsDirection)" },
    },
  },
  { cls = "GuidTrackDanceNoteCtrl", image = "HotFix.dll",
    fields = {
      { name = "isPlay", offset = 408, type = "Boolean", mod = "set true (via IsPlaying)" },
    },
    methods = {
      { name = "get_IsPlaying",    addr = "0x16d22b4", ret = "Boolean",  params = "()" },
      { name = "set_IsPlaying",    addr = "0x170cb8c", ret = "Void",     params = "(Boolean)" },
      { name = "JudgeNotePress",   addr = "0x1702a5c", ret = "Void",     params = "(eTrackDirection,Boolean,Boolean)" },
    },
  },
  { cls = "UI_TaikoNoteBase", image = "HotFix.dll",
    fields = {
      { name = "isJudgeLevel", offset = 48, type = "Boolean",          mod = "set true" },
      { name = "JudgeLevel",   offset = 56, type = "eNoteJudgeLevel",  mod = "set 4 (PERFECT)" },
      { name = "IsHit",        offset = 64, type = "Boolean",          mod = "set true" },
    },
    methods = {
      { name = "set_isJudgeLevel", addr = "0x170cb8c", ret = "Void", params = "(Boolean)" },
      { name = "get_IsHit",        addr = "0x16d22b4", ret = "Boolean", params = "()" },
      { name = "set_IsHit",        addr = "0x170cb8c", ret = "Void", params = "(Boolean)" },
      { name = "InitData",         addr = "0x170cb34", ret = "Void", params = "(TaikoNote)" },
    },
  },
  { cls = "DanceTaikoController", image = "HotFix.dll",
    fields = {},
    methods = {
      { name = "GetJudgeLevel",  addr = "0x16aedec", ret = "eNoteJudgeLevel", params = "(Single,Single)   ◆ PATCHED→4" },
      { name = "CheckHit",       addr = "0x16d30b0", ret = "Boolean",        params = "(eTaikoDirection,Boolean)" },
      { name = "CalculateSoul",  addr = "0x170d84c", ret = "Void",           params = "(TaikoNote,eNoteJudgeLevel)" },
      { name = "ShowJudgeEffect",addr = "0x16feaf4", ret = "Void",           params = "(eNoteJudgeLevel)" },
    },
  },
  { cls = "Dance.DynamicArrowsController", image = "HotFix.dll",
    fields = {},
    methods = {
      { name = "CalculateScore",       addr = "0x16fe4ac", ret = "Void", params = "()" },
      { name = "OnOneGroupFinish",     addr = "0x16fe4ac", ret = "Void", params = "()" },
      { name = "GetComboRatio",        addr = "0x16e3574", ret = "UInt32", params = "(UInt32)" },
      { name = "SendRoundScoreToServer",addr = "0x170d84c", ret = "Void", params = "(DynamicGroup, Int32)" },
    },
  },
}

-- ========== TOOL USAGE TABLE ==========
local toolUsage = {
  { tool = "find_objects",     desc = "Tìm live instance AuditionGroup / TrackCtrl / TaikoNote", slot = "read-only" },
  { tool = "class_info",       desc = "Đọc field offset + method RVA từ IL2CPP metadata",        slot = "read-only" },
  { tool = "inspect_object",   desc = "Đọc toàn bộ field state trước/sau mutation",             slot = "read-only" },
  { tool = "write_field",      desc = "Ghi judgeLevel=4, isHitBeat=true, IsPlaying=true",        slot = "0 slots" },
  { tool = "patch_method",     desc = "DanceTaikoController.GetJudgeLevel → 4 (ACTIVE)",         slot = "1/6" },
  { tool = "run_ui_lua",       desc = "Render ImGui menu auto-reapply mỗi 2 giây",               slot = "0 slots" },
  { tool = "save_script",      desc = "Lưu script vào libTool-files/script/",                    slot = "utility" },
}

-- ========== CAPTURE / RESTORE ==========
local function captureKey(key, obj, fields)
  if not originals[key] and obj then
    local vals = {}
    for _, f in ipairs(fields) do
      local ok, v = pcall(function() return obj[f] end)
      vals[f] = ok and v or nil
    end
    originals[key] = { obj = obj, vals = vals }
  end
end

local function captureOriginal(group, track, taikoNote)
  if group then
    captureKey("group:" .. tostring(group), group, { "judgeLevel", "isHitBeat" })
  end
  if track then
    captureKey("track:" .. tostring(track), track, { "IsPlaying" })
  end
  if taikoNote then
    captureKey("taiko:" .. tostring(taikoNote), taikoNote, { "JudgeLevel", "isJudgeLevel", "IsHit" })
  end
end

local function restoreOriginal()
  local restored = 0
  for _, rec in pairs(originals) do
    local o = rec.obj
    if o then
      pcall(function()
        for f, v in pairs(rec.vals) do
          if v ~= nil then o[f] = v end
        end
      end)
      restored = restored + 1
    end
  end
  originals = {}
  state.stats.modified = 0
  state.stats.taiko = 0
  state.stats.mini = 0
  state.stats.crazy = 0
  state.scoredGroups = {}
  return restored
end

-- ========== v7.0 MINI-GAME HELPERS (dynamic access, preflight-safe) ==========
local function setF(o, f, v)
  if not o then return false end
  local ok = pcall(function() o[f] = v end)
  return ok
end
local function getF(o, f)
  if not o then return nil end
  local ok, v = pcall(function() return o[f] end)
  return ok and v or nil
end
local function callM(o, m, a1, a2)
  if not o then return false end
  local ok
  if a2 ~= nil then
    ok = pcall(function() o[m](o, a1, a2) end)
  elseif a1 ~= nil then
    ok = pcall(function() o[m](o, a1) end)
  else
    ok = pcall(function() o[m](o) end)
  end
  return ok
end
local function captureMini(o, fields)
  if not o then return end
  local mkey = "mini:" .. tostring(o)
  if originals[mkey] then return end
  local vals = {}
  for _, f in ipairs(fields) do
    vals[f] = getF(o, f)
  end
  originals[mkey] = { obj = o, vals = vals }
end
local function restoreMini()
  local restored = 0
  for mkey, rec in pairs(originals) do
    if type(mkey) == "string" and string.sub(mkey, 1, 5) == "mini:" then
      local o = rec.obj
      if o then
        pcall(function()
          for f, v in pairs(rec.vals) do
            if v ~= nil then o[f] = v end
          end
        end)
        restored = restored + 1
      end
      originals[mkey] = nil
    end
  end
  return restored
end

-- ========== APPLY MODS ==========
local function applyAuditionMod()
  local count = 0
  local ok = pcall(function()
    local cls = Class.fromName("Dance.AuditionGroup")
    if cls and cls.findObjects then
      local objs = cls:findObjects()
      if objs and objs.count and objs.count > 0 then
        for i = 1, objs.count do
          local g = objs[i]
          if g then
            captureOriginal(g, nil, nil)
            g.judgeLevel = state.PERFECT
            g.isHitBeat = true
            count = count + 1
          end
        end
      end
    end
    local tc = Class.fromName("GuidTrackDanceNoteCtrl")
    if tc and tc.findObjects then
      local tracks = tc:findObjects()
      if tracks and tracks.count and tracks.count > 0 then
        for i = 1, tracks.count do
          local trk = tracks[i]
          if trk then
            captureOriginal(nil, trk, nil)
            trk.IsPlaying = true
            count = count + 1
          end
        end
      end
    end
  end)
  if not ok then count = 0 end
  return count
end

local function applyTaikoMod()
  local count = 0
  local ok = pcall(function()
    local cls = Class.fromName("UI_TaikoNoteBase")
    if cls and cls.findObjects then
      local notes = cls:findObjects()
      if notes and notes.count and notes.count > 0 then
        for i = 1, notes.count do
          local n = notes[i]
          if n then
            captureOriginal(nil, nil, n)
            n.JudgeLevel = state.PERFECT  -- eNoteJudgeLevel.Perfect = 4
            n.isJudgeLevel = true
            local okHit, hit = pcall(function() return n.IsHit end)
            if okHit and hit == false then n.IsHit = true end
            count = count + 1
          end
        end
      end
    end
  end)
  if not ok then count = 0 end
  return count
end

-- ========== v7.1 FULL MINI GAME APPLY (Crazy FIX: JudgeRatio=100) ==========
local MINI_MODES = {
  { label = "Bubble", judge = 4,
    classes = {
      { "Modules.UI.UI_DanceBallSingleNote", { "judgeLevel" } },
      { "Modules.UI.UI_DanceBallLongNote",   { "judgeLevel" } },
      { "BubbleNoteController",               { "isAutoPlay" } },
    },
    methodCls = { "Modules.UI.UI_BubbleNoteBase" },
  },
  { label = "VOS", judge = 4,
    classes = {
      { "Modules.UI.UI_Note_VOS",    { "judgeLevel", "isJudge" } },
      { "Modules.UI.UI_LongNote_VOS",{ "judgeLevel" } },
    },
  },
  { label = "Burst", judge = 4,
    classes = {
      { "BurstAuGroup", { "judgeLevel", "isHitBeat" } },
    },
  },
  { label = "Crazy", judge = 4,
    classes = {
      { "DynamicGroup",       { "judgeLevel" } },
      { "DynamicOneBeatKeys", { "judgeLevel", "JudgeRatio" } },  -- JudgeRatio 0%=miss,100%=perfect
    },
  },
  { label = "Quỷ đạo", judge = 0, -- eGuideNoteJudgeLevel: perfect=0
    classes = {
      { "GuideNote",       { "judgeLevel", "haveDone" } },
      { "GuideLongNote",   { "curLevel" } },
      { "GuideDoubleNote", { "judgeLevel" } },
      { "GuideSlideNote",  { "judgeLevel" } },
    },
  },
  { label = "4K/Track", judge = 4,
    classes = {
      { "Dance.MusicTool.TrackNote", { "judgeLevel" } },
    },
  },
}

local miniCounts = {}
local function applyMiniMod()
  local total = 0
  local ok = pcall(function()
    local ratioFields = { JudgeRatio = 100 }
    local function applyOne(clsName, fields, judgeVal, needTrue)
      local cls = Class.fromName(clsName)
      if not (cls and cls.findObjects) then return 0 end
      local objs = cls:findObjects()
      if not (objs and objs.count) then return 0 end
      local cnt = 0
      for i = 1, objs.count do
        local o = objs[i]
        if o then
          captureMini(o, fields)
          for _, f in ipairs(fields) do
            if needTrue[f] then setF(o, f, true)
            elseif ratioFields[f] then setF(o, f, ratioFields[f])
            else setF(o, f, judgeVal) end
          end
          cnt = cnt + 1
        end
      end
      return cnt
    end
    for _, mode in ipairs(MINI_MODES) do
      local modeCnt = 0
      for _, entry in ipairs(mode.classes) do
        local clsName, fields = entry[1], entry[2]
        local needTrue = {}
        for _, f in ipairs(fields) do
          if f == "isAutoPlay" or f == "isJudge" or f == "isHitBeat" or f == "haveDone" then needTrue[f] = true end
        end
        modeCnt = modeCnt + applyOne(clsName, fields, mode.judge, needTrue)
      end
      for _, mcls in ipairs(mode.methodCls or {}) do
        local cls = Class.fromName(mcls)
        if cls and cls.findObjects then
          local objs = cls:findObjects()
          if objs and objs.count then
            for i = 1, objs.count do
              local o = objs[i]
              if o then
                local okC = callM(o, "ChangeJudgeLevel", 4)
                callM(o, "AutoPlay")
                if okC then modeCnt = modeCnt + 1 end
              end
            end
          end
        end
      end
      miniCounts[mode.label] = modeCnt
      total = total + modeCnt
    end
  end)
  if not ok then total = 0 end
  return total
end

-- ========== v7.2 CRAZY SCORE FIX ==========
-- 1) Repair curArrowsIndex desync (probe cũ có thể set 999 > arrows.length → game không judge)
-- 2) Direct additive score: game không cộng điểm → menu tự cộng nowTotalScore theo key perfect
local function repairCrazyKeys()
  local repaired = 0
  local cls = Class.fromName("DynamicOneBeatKeys")
  if cls and cls.findObjects then
    local keys = cls:findObjects()
    if keys and keys.count then
      for i = 1, keys.count do
        local k = keys[i]
        if k then
          local idx = getF(k, "curArrowsIndex")
          -- Get arrows length via collectionItems on arrows field pointer
          local okA, arrowsPtr = pcall(function() return k.arrows end)
          local len = 0
          if okA and arrowsPtr then
            local items = collectionItems(arrowsPtr, 32000, 0)
            if items and items.count then len = items.count end
          end
          if len > 0 and (idx == nil or idx >= len) then
            setF(k, "curArrowsIndex", 0)
            repaired = repaired + 1
          end
        end
      end
    end
  end
  return repaired
end

local function applyCrazyScoreFix()
  local added = 0
  pcall(function()
    local ctrlCls = Class.fromName("Dance.DynamicArrowsController")
    if not (ctrlCls and ctrlCls.findObjects) then return end
    local ctrls = ctrlCls:findObjects()
    if not (ctrls and ctrls.count and ctrls.count > 0) then return end
    local ctrl = ctrls[1]
    if not ctrl then return end

    local base = getF(ctrl, "noteBaseScore")
    if base == nil or base == 0 then base = 100 end  -- fallback nếu config chưa load
    local combo = getF(ctrl, "curComboLevel")
    if combo == nil or combo < 1 then combo = 1 end
    local comboMul = 1 + (combo - 1) * 0.05  -- x1=1.0, x2=1.05...
    local nowScore = getF(ctrl, "nowTotalScore")
    if nowScore == nil then nowScore = 0 end

    -- Count perfect keys in all totalGroup
    local okG, grpList = pcall(function() return ctrl.totalGroup end)
    local groups = 0
    if okG and grpList then
      local items = collectionItems(grpList, 32000, 0)
      if items and items.count then groups = items.count end
      for gi = 1, (items and items.count or 0) do
        local grp = items[gi]
        if grp then
          local gKey = "crazyG:" .. tostring(grp)
          if not state.scoredGroups[gKey] then
            local jl = getF(grp, "judgeLevel")
            local allHit = getF(grp, "isJudgeAllKey")
            if allHit == true and jl ~= nil then
              -- group hoàn thành → cộng điểm 1 lần
              local keysCnt = getF(grp, "curKeysIndex")
              if keysCnt == nil then keysCnt = 1 end
              local gain = math.floor(base * comboMul * math.max(keysCnt, 1))
              setF(ctrl, "nowTotalScore", nowScore + gain)
              state.scoredGroups[gKey] = true
              state.crazyScore = nowScore + gain
              added = added + gain
            end
          end
        end
      end
    end
    -- force perfect state trên keys để UI display + game flow thấy đủ key hit
    local dkCls = Class.fromName("DynamicOneBeatKeys")
    if dkCls and dkCls.findObjects then
      local keys = dkCls:findObjects()
      if keys and keys.count then
        for i = 1, keys.count do
          local k = keys[i]
          if k then
            captureMini(k, { "judgeLevel", "JudgeRatio", "isJudge" })
            setF(k, "judgeLevel", 4)
            setF(k, "JudgeRatio", 100)
            setF(k, "isJudge", true)
          end
        end
      end
    end
  end)
  return added
end

-- ========== UI DRAW ==========
function OnDraw()
  local currentTime = os.time()
  if state.activeOn and (currentTime - state.lastCheck >= 2) then
    state.lastCheck = currentTime
    local arrow = applyAuditionMod()
    if arrow > 0 and arrow ~= state.lastCount then
      state.lastCount = arrow
      state.status = "Arrow: áp dụng cho trận mới! Objects=" .. tostring(arrow)
    end
  end
  if state.taikoOn and (currentTime - state.lastTaikoCheck >= 2) then
    state.lastTaikoCheck = currentTime
    local taiko = applyTaikoMod()
    if taiko > 0 and taiko ~= state.lastTaikoCount then
      state.lastTaikoCount = taiko
      state.status = "Taiko: Perfect áp dụng! Notes=" .. tostring(taiko)
    end
  end
  if state.miniOn and (currentTime - state.lastMiniCheck >= 2) then
    state.lastMiniCheck = currentTime
    local mini = applyMiniMod()
    if mini > 0 and mini ~= state.lastMiniCount then
      state.lastMiniCount = mini
      state.status = "Full Mini Game: Perfect áp dụng! Objects=" .. tostring(mini)
    end
  end
  -- v7.2: Crazy Score Fix chạy 0.3s (bắt kịp frame 60fps) khi miniOn
  if state.miniOn and (currentTime - state.lastCrazyCheck >= 0.3) then
    local repaired = repairCrazyKeys()
    local gain = applyCrazyScoreFix()
    state.lastCrazyCheck = currentTime
    if gain > 0 or repaired > 0 then
      state.stats.crazy = state.stats.crazy + gain
    end
  end

  ImGui.SetNextWindowSize(660, 680)
  local visible = ImGui.Begin("AutoDance HexControl v7.2 FULL MINI (Crazy Score Fix)")
  if visible then
    if ImGui.BeginTabBar("##mainTabs") then
      -- ===== TAB 1: CONTROL =====
      if ImGui.BeginTabItem("🎮 Control") then
        local c1, v1 = ImGui.Checkbox("Bật Auto Arrow (Audition)", state.activeOn)
        if c1 then
          if v1 then
            state.activeOn = true
            local arrow = applyAuditionMod()
            state.lastCheck = os.time()
            state.lastCount = arrow
            state.status = "Arrow BẬT. Objects=" .. tostring(arrow)
          else
            state.activeOn = false
            local restored = restoreOriginal()
            state.status = "Arrow TẮT. Khôi phục " .. tostring(restored) .. " object."
          end
        end

        local c2, v2 = ImGui.Checkbox("Bật Auto Taiko (Perfect All Notes)", state.taikoOn)
        if c2 then
          if v2 then
            state.taikoOn = true
            local taiko = applyTaikoMod()
            state.lastTaikoCheck = os.time()
            state.lastTaikoCount = taiko
            state.status = "Taiko Perfect BẬT. Notes=" .. tostring(taiko)
          else
            state.taikoOn = false
            local restored = restoreOriginal()
            state.status = "Taiko TẮT. Khôi phục " .. tostring(restored) .. " object."
          end
        end

        local c3, v3 = ImGui.Checkbox("🎯 Bật FULL MINI GAME (Bubble/VOS/Burst/Crazy/Quỷ đạo/4K)", state.miniOn)
        if c3 then
          if v3 then
            state.miniOn = true
            local mini = applyMiniMod()
            state.lastMiniCheck = os.time()
            state.lastMiniCount = mini
            state.status = "FULL MINI GAME BẬT. Objects=" .. tostring(mini)
          else
            state.miniOn = false
            local restored = restoreMini()
            state.scoredGroups = {}
            state.crazyScore = 0
            state.status = "FULL MINI GAME TẮT. Khôi phục " .. tostring(restored) .. " object."
          end
        end

        ImGui.Separator()
        ImGui.Text("Arrow: " .. (state.activeOn and "⚡ ON" or "OFF") .. "  |  Taiko: " .. (state.taikoOn and "⚡ ON" or "OFF") .. "  |  Mini: " .. (state.miniOn and "⚡ ON" or "OFF"))
        ImGui.Text("Objects Arrow: " .. tostring(state.stats.modified) .. " | Taiko: " .. tostring(state.stats.taiko) .. " | Mini: " .. tostring(state.stats.mini))
        ImGui.SeparatorText("🎯 Crazy Score Fix (0.3s refresh)")
        ImGui.Text("  Bonus đã cộng: " .. tostring(state.stats.crazy) .. " điểm")
        ImGui.Text("  nowTotalScore (menudấu): " .. tostring(state.crazyScore))
        ImGui.Text("  Công thức: noteBaseScore × comboRatio × keyCount per finished group")
        if state.miniOn then
          ImGui.SeparatorText("Mini per-mode (2s refresh)")
          for _, mode in ipairs(MINI_MODES) do
            ImGui.Text("  " .. mode.label .. " : " .. tostring(miniCounts[mode.label] or 0))
          end
        end
        ImGui.SeparatorText("Status")
        ImGui.TextWrapped(state.status)

        if ImGui.Button("Reset / Khôi phục tất cả") then
          state.activeOn = false
          state.taikoOn = false
          state.miniOn = false
          local restored = restoreOriginal()
          state.scoredGroups = {}
          state.crazyScore = 0
          state.status = "Đã reset + khôi phục " .. tostring(restored) .. " object."
        end
        ImGui.EndTabItem()
      end

      -- ===== TAB 2: FIELD OFFSET =====
      if ImGui.BeginTabItem("📐 Field Offset") then
        for _, info in ipairs(methodInfo) do
          if #info.fields > 0 then
            ImGui.SeparatorText(info.cls .. "  [" .. info.image .. "]")
            for _, f in ipairs(info.fields) do
              ImGui.Text(string.format("  0x%03X  %-14s  %-20s  → %s", f.offset, f.name, f.type, f.mod))
            end
          end
        end
        ImGui.SeparatorText("Mini-game judge fields (find_field_owners eNoteJudgeLevel)")
        ImGui.Text("  UI_DanceBallSingleNote.judgeLevel @0x078 → 4 (Bubble)")
        ImGui.Text("  UI_DanceBallLongNote.judgeLevel   @0x08C → 4 (Bubble)")
        ImGui.Text("  UI_Note_VOS.judgeLevel @0x058 / isJudge @0x05C → 4 / true")
        ImGui.Text("  UI_LongNote_VOS.judgeLevel @0x020 → 4")
        ImGui.Text("  BurstAuGroup.judgeLevel @0x040 / isHitBeat @0x032 → 4 / true")
        ImGui.Text("  DynamicGroup.judgeLevel @0x038 → 4 (Crazy)")
        ImGui.Text("  DynamicOneBeatKeys.judgeLevel @0x020 → 4 + JudgeRatio @0x034 → 100")
        ImGui.Text("  DynamicOneBeatKeys.curArrowsIndex @0x024 → repair 0 (v7.2)")
        ImGui.Text("  DynamicArrowsController.nowTotalScore @0x040 → additive (v7.2)")
        ImGui.Text("  GuideNote.judgeLevel @0x058 / haveDone @0x05C → 0 (perfect) / true")
        ImGui.Text("  GuideLongNote.curLevel @0x0A0 → 0 (perfect)")
        ImGui.Text("  TrackNote.judgeLevel @0x028 → 4 (4K)")
        ImGui.EndTabItem()
      end

      -- ===== TAB 3: METHOD OFFSET =====
      if ImGui.BeginTabItem("📍 Method Offset") then
        for _, info in ipairs(methodInfo) do
          ImGui.SeparatorText(info.cls)
          for _, m in ipairs(info.methods) do
            ImGui.Text(string.format("  %s  %-20s  → %s %s", m.addr, m.name, m.ret, m.params))
          end
        end
        ImGui.SeparatorText("RVA đặc biệt (score pipeline)")
        ImGui.Text("  0x16fe4ac  DynamicArrowsController.CalculateScore = OnOneGroupFinish (generic stub)")
        ImGui.Text("  0x15cdcf8  shared helper call (real score math inside)")
        ImGui.EndTabItem()
      end

      -- ===== TAB 4: TOOLS =====
      if ImGui.BeginTabItem("🔧 Tools") then
        ImGui.SeparatorText("LibTool Tools đang dùng")
        for _, tu in ipairs(toolUsage) do
          ImGui.Text(string.format("  %-18s  %-12s  %s", tu.tool, tu.slot, tu.desc))
        end
        ImGui.SeparatorText("Tool Slots")
        ImGui.Text("  Patch slots : 1 / 6 (DanceTaikoController.GetJudgeLevel → 4)")
        ImGui.Text("  Mini writes : 0 slot (dynamic field write)")
        ImGui.Text("  Redirect    : 0")
        ImGui.Text("  JudgeKey patch : RESTORED (0 callers → vô dụng, đã free slot)")
        ImGui.EndTabItem()
      end

      ImGui.EndTabBar()
    end
  end
  ImGui.End()
end

function OnStop()
  state.activeOn = false
  state.taikoOn = false
  state.miniOn = false
  local restored = restoreOriginal()
  state.scoredGroups = {}
  state.crazyScore = 0
  print("AutoDance HexControl v7.2 stopped. Restored=" .. tostring(restored))
end
