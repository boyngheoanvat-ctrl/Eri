#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ToolWindow.h"

__attribute__((constructor))
static void libtool_init(void) {
    NSLog(@"[ToolKit] loaded");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        @try {
            // Tìm key window hợp lệ để kiểm tra môi trường ứng dụng khi khởi động
            UIWindow *kw = nil;
            for (UIWindow *w in UIApplication.sharedApplication.windows) {
                if (w.isKeyWindow && ![w isKindOfClass:[ToolWindow class]]) {
                    kw = w;
                    break;
                }
            }

            if (!kw) {
                for (UIWindow *w in UIApplication.sharedApplication.windows) {
                    if (![w isKindOfClass:[ToolWindow class]]) {
                        kw = w;
                        break;
                    }
                }
            }

            if (kw) {
                NSLog(@"[ToolKit] Initialized successfully on window: %@", kw);
            } else {
                NSLog(@"[ToolKit] No valid window found during init");
            }
        } @catch (NSException *e) {
            NSLog(@"[ToolKit] libtool_init crash: %@", e);
        }
    });
}
