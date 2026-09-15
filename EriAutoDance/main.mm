#import <Foundation/Foundation.h>

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

static int l_nativeLog(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg) {
        NSLog(@"[Lua Script Log]: %s", msg);
    }
    return 0;
}

static const char *kAutoDanceScript = R"lua(
-- AutoDance HexControl v4 — Auto Re-apply New Match (Optimized & Lag-free)
local state = {
  activeOn = false,
  status = "Sẵn sàng. Bật toggle để chạy tự động qua các trận.",
  PERFECT = 4,
  stats = { modified = 0 },
  lastCheck = 0,
  lastCount = 0
}

local function applyCombinedMod(enable)
  local count = 0
  local ok, err = pcall(function()
    local auditionGroupClass = Class.fromName("Dance.AuditionGroup")
    local trackCtrlClass = Class.fromName("GuidTrackDanceNoteCtrl")
    
    if enable then
      if auditionGroupClass and auditionGroupClass.findObjects then
        local objs = auditionGroupClass:findObjects()
        if objs and objs.count and objs.count > 0 then
          for i = 1, objs.count do
            local obj = objs[i]
            if obj then
              obj.judgeLevel = state.PERFECT
              obj.isHitBeat = true
              obj.isJudgeAllKey = true
              count = count + 1
            end
          end
        end
      end

      if trackCtrlClass and trackCtrlClass.findObjects then
        local ctrls = trackCtrlClass:findObjects()
        if ctrls and ctrls.count and ctrls.count > 0 then
          for i = 1, ctrls.count do
            local ctrl = ctrls[i]
            if ctrl then
              ctrl.IsPlaying = true
              count = count + 1
            end
          end
        end
      end
    end
  end)

  if ok then
    state.stats.modified = count
  end
  return count
end

function OnDraw()
  local currentTime = os.time()
  if state.activeOn and (currentTime - state.lastCheck >= 2) then
    state.lastCheck = currentTime
    local count = applyCombinedMod(true)
    if count > 0 and count ~= state.lastCount then
      state.lastCount = count
      state.status = "Đã tự động áp dụng cho trận mới! Objects=" .. tostring(count)
    end
  end

  if ImGui then
    ImGui.SetNextWindowSize(500, 340)
    local visible = ImGui.Begin("AutoDance HexControl v4 (Auto-Match)")
    if visible then
      local c1, v1 = ImGui.Checkbox("Bật Auto Tất Cả (Tự động bắt trận mới)", state.activeOn)
      if c1 then
        state.activeOn = v1
        if v1 then
          applyCombinedMod(true)
          state.status = "Đã BẬT. Đang theo dõi trận đấu..."
        else
          state.status = "Đã TẮT tính năng."
        end
      end

      ImGui.Text(state.activeOn and "[Trạng thái]: ĐANG BẬT (Auto)" or "[Trạng thái]: TẮT")
      ImGui.Text("Số lượng đối tượng hiện tại: " .. tostring(state.stats.modified))
      ImGui.SeparatorText("Status")
      ImGui.TextWrapped(state.status)

      if ImGui.Button("Reset / Khôi phục") then
        state.activeOn = false
        state.status = "Đã reset trạng thái."
      end
    end
    ImGui.End()
  end
end

function OnStop()
  state.activeOn = false
  print("AutoDance HexControl v4 stopped.")
end
)lua";

static lua_State *gL = NULL;

__attribute__((constructor)) static void initLuaEmbed() {
    @autoreleasepool {
        gL = luaL_newstate();
        if (gL) {
            luaL_openlibs(gL);
            lua_register(gL, "nativeLog", l_nativeLog);
            
            if (luaL_dostring(gL, kAutoDanceScript) != LUA_OK) {
                const char *err = lua_tostring(gL, -1);
                NSLog(@"[EriError]: %s", err);
                lua_pop(gL, 1);
            } else {
                NSLog(@"[EriSuccess]: Script loaded embedded.");
            }
        }
    }
}

void OnDraw() {
    if (!gL) return;
    lua_getglobal(gL, "OnDraw");
    if (lua_isfunction(gL, -1)) {
        if (lua_pcall(gL, 0, 0, 0) != LUA_OK) {
            lua_pop(gL, 1);
        }
    } else {
        lua_pop(gL, 1);
    }
}

void OnStop() {
    if (!gL) return;
    lua_getglobal(gL, "OnStop");
    if (lua_isfunction(gL, -1)) {
        lua_pcall(gL, 0, 0, 0);
    } else {
        lua_pop(gL, 1);
    }
}
