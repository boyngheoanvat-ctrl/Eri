#import <Foundation/Foundation.h>

// Khai báo nguyên mẫu C cho Lua
extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

// -----------------------------------------------------------------
// Hàm C/Objective-C để mở rộng (Ví dụ: ImGui bridge hoặc log)
// -----------------------------------------------------------------
static int l_nativeLog(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg) {
        NSLog(@"[Lua Script Log]: %s", msg);
    }
    return 0;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"=== KHOI DONG MOI TRUONG LUA & SCRIPT AUTO-DANCE ===");
        
        // 1. Khởi tạo Lua State
        lua_State *L = luaL_newstate();
        if (L == NULL) {
            NSLog(@"Loi: Khong the khoi tao lua_State!");
            return -1;
        }
        
        // 2. Nạp thư viện chuẩn
        luaL_openlibs(L);
        
        // 3. Đăng ký hàm giao tiếp native (nếu cần)
        lua_register(L, "nativeLog", l_nativeLog);
        
        // 4. Đoạn mã script Lua 'AutoDance HexControl v4' của bạn
        const char *autoDanceScript = R"lua(
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
  -- Cơ chế thông minh: Chỉ kiểm tra định kỳ nhẹ nhàng mỗi 2 giây khi bật toggle 
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
          local count = applyCombinedMod(true)
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
  nativeLog("AutoDance HexControl v4 stopped.")
end

nativeLog("AutoDance HexControl v4 da duoc nap thanh cong vao Lua State!")
        )lua";
        
        // 5. Thực thi script Lua
        if (luaL_dostring(L, autoDanceScript) != LUA_OK) {
            const char *errorMsg = lua_tostring(L, -1);
            NSLog(@"Loi thuc thi AutoDance Script: %s", errorMsg);
            lua_pop(L, 1);
        }
        
        // (Tùy chọn) Gọi hàm OnDraw hoặc OnStop giả lập vòng lặp nếu app chạy luồng native
        // lua_getglobal(L, "OnDraw");
        // if (lua_isfunction(L, -1)) { lua_pcall(L, 0, 0, 0); } else { lua_pop(L, 1); }

        // 6. Dọn dẹp (nếu chương trình kết thúc)
        // lua_close(L);
        NSLog(@"=== HOAN TAT NAP SCRIPT VAO MOI TRUONG OBJECTIVE-C ===");
    }
    return 0;
}
