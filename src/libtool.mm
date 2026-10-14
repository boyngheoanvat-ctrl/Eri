#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ToolWindow.h"
#import "FloatingButton.h"

__attribute__((constructor))
static void libtool_init(void) {
    NSLog(@"[ToolKit] loaded");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *kw = nil;
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.isKeyWindow) { kw = w; break; }
        }
        if (kw) {
            [FloatingButton attachToWindow:kw];
            NSLog(@"[ToolKit] FloatingButton attached");
        }
    });
}
