#import <Foundation/Foundation.h>

static BOOL g_activeOn = NO;
static int g_modifiedCount = 0;

static void applyMod(BOOL enable) {
    int count = 0;
    @try {
        Class auditionGroupClass = NSClassFromString(@"Dance.AuditionGroup");
        Class trackCtrlClass = NSClassFromString(@"GuidTrackDanceNoteCtrl");
        
        if (enable) {
            if (auditionGroupClass && [auditionGroupClass respondsToSelector:@selector(findObjects)]) {
                id objs = [auditionGroupClass performSelector:@selector(findObjects)];
                if (objs && [objs respondsToSelector:@selector(count)]) {
                    NSUInteger total = [[objs performSelector:@selector(count)] unsignedIntegerValue];
                    for (NSUInteger i = 0; i < total; i++) {
                        count++;
                    }
                }
            }
            if (trackCtrlClass && [trackCtrlClass respondsToSelector:@selector(findObjects)]) {
                id ctrls = [trackCtrlClass performSelector:@selector(findObjects)];
                if (ctrls && [ctrls respondsToSelector:@selector(count)]) {
                    NSUInteger total = [[ctrls performSelector:@selector(count)] unsignedIntegerValue];
                    for (NSUInteger i = 0; i < total; i++) {
                        count++;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[EriError]: %@", exception.reason);
    }
    g_modifiedCount = count;
}

void OnDraw() {
    static time_t lastCheck = 0;
    time_t currentTime = time(NULL);
    
    if (g_activeOn && (currentTime - lastCheck >= 2)) {
        lastCheck = currentTime;
        applyMod(YES);
    }

    if (&ImGui::SetNextWindowSize) {
        ImGui::SetNextWindowSize(500, 340, 0);
        if (ImGui::Begin("AutoDance HexControl v4 (Auto-Match)", NULL, 0)) {
            if (ImGui::Checkbox("Bật Auto Tất Cả (Tự động bắt trận mới)", &g_activeOn)) {
                if (g_activeOn) {
                    applyMod(YES);
                }
            }
            
            if (g_activeOn) {
                ImGui::Text("[Trạng thái]: ĐANG BẬT (Auto)");
            } else {
                ImGui::Text("[Trạng thái]: TẮT");
            }
            
            ImGui::Text("Số lượng đối tượng hiện tại: %d", g_modifiedCount);
            ImGui::Separator();
            
            if (ImGui::Button("Reset / Khôi phục", ImVec2(0, 0))) {
                g_activeOn = NO;
                g_modifiedCount = 0;
            }
        }
        ImGui::End();
    }
}

__attribute__((constructor)) static void init() {
    NSLog(@"=== EriAutoDance Native Loaded Successfully ===");
}


