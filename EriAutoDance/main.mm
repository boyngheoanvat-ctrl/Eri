#import <Foundation/Foundation.h>

static BOOL g_activeOn = NO;
static int g_modifiedCount = 0;
static time_t g_lastCheck = 0;
static int g_lastCount = 0;
static NSString *g_statusText = @"Sẵn sàng. Bật toggle để chạy tự động qua các trận.";

static void applyCombinedMod(BOOL enable) {
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
                        id obj = [objs objectAtIndexedSubscript:i];
                        if (obj) {
                            // Gán giá trị trực tiếp qua KVC/Method tương đương Lua
                            [obj setValue:@(4) forKey:@"judgeLevel"];
                            [obj setValue:@YES forKey:@"isHitBeat"];
                            [obj setValue:@YES forKey:@"isJudgeAllKey"];
                            count++;
                        }
                    }
                }
            }

            if (trackCtrlClass && [trackCtrlClass respondsToSelector:@selector(findObjects)]) {
                id ctrls = [trackCtrlClass performSelector:@selector(findObjects)];
                if (ctrls && [ctrls respondsToSelector:@selector(count)]) {
                    NSUInteger total = [[ctrls performSelector:@selector(count)] unsignedIntegerValue];
                    for (NSUInteger i = 0; i < total; i++) {
                        id ctrl = [ctrls objectAtIndexedSubscript:i];
                        if (ctrl) {
                            [ctrl setValue:@YES forKey:@"IsPlaying"];
                            count++;
                        }
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
    time_t currentTime = time(NULL);
    if (g_activeOn && (currentTime - g_lastCheck >= 2)) {
        g_lastCheck = currentTime;
        applyCombinedMod(YES);
        if (g_modifiedCount > 0 && g_modifiedCount != g_lastCount) {
            g_lastCount = g_modifiedCount;
            g_statusText = [NSString stringWithFormat:@"Đã tự động áp dụng cho trận mới! Objects=%d", g_modifiedCount];
        }
    }
}

void OnStop() {
    g_activeOn = NO;
    NSLog(@"AutoDance HexControl v4 stopped.");
}

__attribute__((constructor)) static void initNative() {
    NSLog(@"=== EriAutoDance Native Engine Loaded ===");
}
