#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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
}

static void showControlPanel() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
        
        UIViewController *rootVC = keyWindow.rootViewController;
        if (!rootVC) return;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"EriAutoDance Control"
                                                                       message:@"Chọn tính năng Auto-Match"
                                                                preferredStyle:UIAlertControllerStyleAlert];
                                                                
        [alert addAction:[UIAlertAction actionWithTitle:(g_activeOn ? @"Tắt Auto" : @"Bật Auto")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            g_activeOn = !g_activeOn;
            applyMod(g_activeOn);
            NSLog(@"[EriAuto]: Trạng thái Auto = %@", g_activeOn ? @"BẬT" : @"TẮT");
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

__attribute__((constructor)) static void init() {
    NSLog(@"=== EriAutoDance Native Loaded Successfully ===");
    showControlPanel();
}
