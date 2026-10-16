#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ToolWindow.h"

__attribute__((constructor))
static void libtool_init(void) {
    NSLog(@"[ToolKit] loaded");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        @try {
            // KHÔNG tạo ToolWindow ở đây — để lazy create trong handleTripleTap
            // (tạo sớm có thể crash vì app chưa fully active)

            // Tìm key window (không phải ToolWindow)
            UIWindow *kw = nil;
            for (UIWindow *w in UIApplication.sharedApplication.windows) {
                if (w.isKeyWindow && ![w isKindOfClass:[ToolWindow class]]) {
                    kw = w;
                    break;
                }
            }

            // Fallback: lấy window đầu tiên không phải ToolWindow
            if (!kw) {
                for (UIWindow *w in UIApplication.sharedApplication.windows) {
                    if (![w isKindOfClass:[ToolWindow class]]) {
                        kw = w;
                        break;
                    }
                }
            }

            if (kw) {
                [[ToolGestureManager shared] attachToWindow:kw];
                NSLog(@"[ToolKit] Gesture attached to %@", kw);
            } else {
                NSLog(@"[ToolKit] No key window found — thu lai sau 2s");

                // Thử lại sau 2 giây (game có thể chưa tạo window)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    UIWindow *kw2 = nil;
                    for (UIWindow *w in UIApplication.sharedApplication.windows) {
                        if (![w isKindOfClass:[ToolWindow class]]) {
                            kw2 = w;
                            break;
                        }
                    }
                    if (kw2) {
                        [[ToolGestureManager shared] attachToWindow:kw2];
                        NSLog(@"[ToolKit] Gesture attached (retry) to %@", kw2);
                    }
                });
            }
        } @catch (NSException *e) {
            NSLog(@"[ToolKit] libtool_init crash: %@", e);
        }
    });
}
