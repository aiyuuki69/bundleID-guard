// BundleIDGuard.m
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#include <signal.h>
#include <unistd.h>

#ifndef EXPECTED_BUNDLE_ID
#define EXPECTED_BUNDLE_ID "com.example.app"
#endif

#define TAG @"[BundleIDGuard]"

@protocol BundleIDGuardJSExport <JSExport>
- (void)Bundleid:(NSString *)expected;
@end

@interface BundleIDGuard : NSObject <BundleIDGuardJSExport>
+ (instancetype)shared;
- (BOOL)matches:(NSString *)actual;
- (void)checkNow;
@end

static BOOL gAlertShown = NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static UIWindow *GuardActiveWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return app.keyWindow ?: app.windows.firstObject;
}
#pragma clang diagnostic pop

static UIViewController *GuardTopController(void) {
    UIViewController *vc = GuardActiveWindow().rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static void GuardTerminate(void) {
    NSLog(@"%@ Terminating app due to Bundle ID mismatch", TAG);
    kill(getpid(), SIGKILL);
}

@implementation BundleIDGuard {
    NSArray<NSString *> *_allowed;
}

+ (instancetype)shared {
    static BundleIDGuard *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [BundleIDGuard new]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        [self Bundleid:@EXPECTED_BUNDLE_ID];
    }
    return self;
}

- (void)Bundleid:(NSString *)expected {
    NSMutableArray *list = [NSMutableArray array];
    for (NSString *s in [expected componentsSeparatedByString:@","]) {
        NSString *t = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length) [list addObject:t];
    }
    _allowed = list;
}

- (BOOL)matches:(NSString *)actual {
    return actual && [_allowed containsObject:actual];
}

- (void)checkNow {
    NSString *actual = NSBundle.mainBundle.bundleIdentifier;
    if ([self matches:actual]) {
        NSLog(@"%@ OK (%@)", TAG, actual);
        return;
    }
    NSLog(@"%@ Bundle ID mismatch! expected=%@, actual=%@", TAG, [_allowed componentsJoinedByString:@","], actual);
    [self showAlertWithActual:actual];
}

- (void)showAlertWithActual:(NSString *)actual {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gAlertShown) return;
        UIViewController *top = GuardTopController();
        if (!top) {
            static int retries = 0;
            if (++retries > 20) { GuardTerminate(); return; }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self showAlertWithActual:actual]; });
            return;
        }
        gAlertShown = YES;
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"Bundle IDが一致しません"
                             message:[NSString stringWithFormat:@"このアプリでは使用できません。\n現在: %@", actual ?: @"(不明)"]
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"OK"
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *a) { GuardTerminate(); }]];
        [top presentViewController:ac animated:YES completion:nil];
    });
}

@end

// 外部から参照
Class BundleIDGuardGetClass(void) { return BundleIDGuard.class; }

__attribute__((constructor))
static void BundleIDGuardInit(void) {
    NSLog(@"%@ Tweak loaded successfully", TAG);
    [NSNotificationCenter.defaultCenter
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *n) { [BundleIDGuard.shared checkNow]; }];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateBackground
            && UIApplication.sharedApplication.windows.count > 0) {
            [BundleIDGuard.shared checkNow];
        }
    });
}