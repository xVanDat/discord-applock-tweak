#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

#define PREF_KEY_ENABLED @"DiscordAppLock_Enabled"
#define PREF_KEY_STYLE   @"DiscordAppLock_Style"     // 0 = Blur, 1 = Discord Logo
#define PREF_KEY_TIMEOUT @"DiscordAppLock_Timeout"   // seconds (0 = immediate)
#define PREF_KEY_REASON  @"DiscordAppLock_Reason"

static BOOL isCurrentlyLocked = NO;
static BOOL isAuthenticating = NO;
static NSTimeInterval lastBackgroundTime = 0;
static UIView *lockOverlayView = nil;
static UIButton *unlockButton = nil;
static UILabel *statusLabel = nil;
static UILabel *subLabel = nil;

// MARK: - Preferences Helper (Directly from NSUserDefaults)
static NSUserDefaults *getPrefs() {
    return [NSUserDefaults standardUserDefaults];
}

static BOOL isLockEnabled() {
    NSUserDefaults *defaults = getPrefs();
    if ([defaults objectForKey:PREF_KEY_ENABLED] == nil) {
        return YES; // Default enabled
    }
    return [defaults boolForKey:PREF_KEY_ENABLED];
}

static void setLockEnabled(BOOL enabled) {
    [getPrefs() setBool:enabled forKey:PREF_KEY_ENABLED];
    [getPrefs() synchronize];
}

static NSInteger getOverlayStyle() {
    NSUserDefaults *defaults = getPrefs();
    if ([defaults objectForKey:PREF_KEY_STYLE] == nil) {
        return 1; // Default 1 = Discord Logo
    }
    return [defaults integerForKey:PREF_KEY_STYLE];
}

static void setOverlayStyle(NSInteger style) {
    [getPrefs() setInteger:style forKey:PREF_KEY_STYLE];
    [getPrefs() synchronize];
}

static NSInteger getTimeoutSeconds() {
    return [getPrefs() integerForKey:PREF_KEY_TIMEOUT];
}

static void setTimeoutSeconds(NSInteger timeout) {
    [getPrefs() setInteger:timeout forKey:PREF_KEY_TIMEOUT];
    [getPrefs() synchronize];
}

static NSString *getCustomReasonText() {
    NSString *reason = [getPrefs() stringForKey:PREF_KEY_REASON];
    if (reason && reason.length > 0) {
        return reason;
    }
    return @"Mở khoá ứng dụng Discord";
}

static void setCustomReasonText(NSString *reason) {
    [getPrefs() setObject:reason forKey:PREF_KEY_REASON];
    [getPrefs() synchronize];
}

// MARK: - Official App Icon Extractor
static UIImage *getDiscordOfficialAppIcon() {
    NSDictionary *infoPlist = [[NSBundle mainBundle] infoDictionary];
    NSDictionary *bundleIcons = infoPlist[@"CFBundleIcons"];
    NSDictionary *primaryIcon = bundleIcons[@"CFBundlePrimaryIcon"];
    NSArray *iconFiles = primaryIcon[@"CFBundleIconFiles"];
    NSString *iconName = iconFiles.lastObject;
    if (iconName) {
        UIImage *img = [UIImage imageNamed:iconName];
        if (img) return img;
    }

    NSArray *candidates = @[@"AppIcon60x60", @"AppIcon76x76", @"AppIcon", @"DiscordLogo", @"icon", @"Icon"];
    for (NSString *cand in candidates) {
        UIImage *img = [UIImage imageNamed:cand];
        if (img) return img;
    }

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:bundlePath error:nil];
    for (NSString *file in files) {
        if ([file hasPrefix:@"AppIcon"] && [file hasSuffix:@".png"]) {
            UIImage *img = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:file]];
            if (img) return img;
        }
    }

    return nil;
}

static UIImage *createDiscordVectorLogo(CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);

    UIColor *discordBlurple = [UIColor colorWithRed:88.0/255.0 green:101.0/255.0 blue:242.0/255.0 alpha:1.0];
    [discordBlurple setFill];

    UIBezierPath *bgCircle = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:size * 0.28];
    [bgCircle fill];

    UIColor *whiteColor = [UIColor whiteColor];
    [whiteColor setFill];

    CGFloat scale = size / 100.0;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(50 * scale, 24 * scale)];
    [path addCurveToPoint:CGPointMake(24 * scale, 38 * scale) controlPoint1:CGPointMake(39 * scale, 24 * scale) controlPoint2:CGPointMake(29 * scale, 29 * scale)];
    [path addCurveToPoint:CGPointMake(20 * scale, 76 * scale) controlPoint1:CGPointMake(19 * scale, 48 * scale) controlPoint2:CGPointMake(18 * scale, 62 * scale)];
    [path addCurveToPoint:CGPointMake(34 * scale, 82 * scale) controlPoint1:CGPointMake(24 * scale, 79 * scale) controlPoint2:CGPointMake(29 * scale, 81 * scale)];
    [path addCurveToPoint:CGPointMake(38 * scale, 75 * scale) controlPoint1:CGPointMake(35 * scale, 79 * scale) controlPoint2:CGPointMake(37 * scale, 77 * scale)];
    [path addCurveToPoint:CGPointMake(32 * scale, 72 * scale) controlPoint1:CGPointMake(36 * scale, 74 * scale) controlPoint2:CGPointMake(34 * scale, 73 * scale)];
    [path addCurveToPoint:CGPointMake(50 * scale, 78 * scale) controlPoint1:CGPointMake(37 * scale, 76 * scale) controlPoint2:CGPointMake(43 * scale, 78 * scale)];
    [path addCurveToPoint:CGPointMake(68 * scale, 72 * scale) controlPoint1:CGPointMake(57 * scale, 78 * scale) controlPoint2:CGPointMake(63 * scale, 76 * scale)];
    [path addCurveToPoint:CGPointMake(62 * scale, 75 * scale) controlPoint1:CGPointMake(66 * scale, 73 * scale) controlPoint2:CGPointMake(64 * scale, 74 * scale)];
    [path addCurveToPoint:CGPointMake(66 * scale, 82 * scale) controlPoint1:CGPointMake(63 * scale, 77 * scale) controlPoint2:CGPointMake(65 * scale, 79 * scale)];
    [path addCurveToPoint:CGPointMake(80 * scale, 76 * scale) controlPoint1:CGPointMake(71 * scale, 81 * scale) controlPoint2:CGPointMake(76 * scale, 79 * scale)];
    [path addCurveToPoint:CGPointMake(76 * scale, 38 * scale) controlPoint1:CGPointMake(82 * scale, 62 * scale) controlPoint2:CGPointMake(81 * scale, 48 * scale)];
    [path addCurveToPoint:CGPointMake(50 * scale, 24 * scale) controlPoint1:CGPointMake(71 * scale, 29 * scale) controlPoint2:CGPointMake(61 * scale, 24 * scale)];
    [path closePath];
    [path fill];

    [discordBlurple setFill];
    UIBezierPath *leftEye = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(36 * scale, 47 * scale, 10 * scale, 10 * scale)];
    [leftEye fill];

    UIBezierPath *rightEye = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(54 * scale, 47 * scale, 10 * scale, 10 * scale)];
    [rightEye fill];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// MARK: - UI Helpers
static UIWindow *getAppKeyWindow() {
    UIWindow *foundWindow = nil;
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) {
            foundWindow = window;
            break;
        }
    }
    if (!foundWindow && windows.count > 0) {
        foundWindow = windows.firstObject;
    }
    return foundWindow;
}

// Forward declarations
static void triggerBiometricAuth(BOOL isInteractive);
static void showSettingsActionSheet();

// MARK: - Lock Overlay Creation
static void showLockOverlay() {
    UIWindow *window = getAppKeyWindow();
    if (!window) return;

    if (!lockOverlayView) {
        lockOverlayView = [[UIView alloc] initWithFrame:window.bounds];
        lockOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        lockOverlayView.backgroundColor = [UIColor colorWithRed:24.0/255.0 green:25.0/255.0 blue:28.0/255.0 alpha:1.0]; // Discord Dark

        NSInteger style = getOverlayStyle();
        if (style == 0) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurView.frame = lockOverlayView.bounds;
            blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [lockOverlayView addSubview:blurView];
        }

        UIView *centerContainer = [[UIView alloc] init];
        centerContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [lockOverlayView addSubview:centerContainer];

        [NSLayoutConstraint activateConstraints:@[
            [centerContainer.centerXAnchor constraintEqualToAnchor:lockOverlayView.centerXAnchor],
            [centerContainer.centerYAnchor constraintEqualToAnchor:lockOverlayView.centerYAnchor constant:-20.0],
            [centerContainer.widthAnchor constraintEqualToAnchor:lockOverlayView.widthAnchor multiplier:0.85]
        ]];

        UIImage *officialIcon = getDiscordOfficialAppIcon();
        UIImageView *logoImageView = nil;
        if (officialIcon) {
            logoImageView = [[UIImageView alloc] initWithImage:officialIcon];
            logoImageView.layer.cornerRadius = 20.0;
            logoImageView.layer.masksToBounds = YES;
        } else {
            logoImageView = [[UIImageView alloc] initWithImage:createDiscordVectorLogo(90)];
        }
        logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
        logoImageView.layer.shadowColor = [UIColor blackColor].CGColor;
        logoImageView.layer.shadowOpacity = 0.35;
        logoImageView.layer.shadowOffset = CGSizeMake(0, 4);
        logoImageView.layer.shadowRadius = 8.0;
        [centerContainer addSubview:logoImageView];

        statusLabel = [[UILabel alloc] init];
        statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        statusLabel.text = @"Discord đã khoá";
        statusLabel.textColor = [UIColor whiteColor];
        statusLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        statusLabel.textAlignment = NSTextAlignmentCenter;
        [centerContainer addSubview:statusLabel];

        subLabel = [[UILabel alloc] init];
        subLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subLabel.text = getCustomReasonText();
        subLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        subLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        subLabel.textAlignment = NSTextAlignmentCenter;
        [centerContainer addSubview:subLabel];

        unlockButton = [UIButton buttonWithType:UIButtonTypeSystem];
        unlockButton.translatesAutoresizingMaskIntoConstraints = NO;
        [unlockButton setTitle:@"Mở khoá Discord" forState:UIControlStateNormal];
        [unlockButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        unlockButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        unlockButton.backgroundColor = [UIColor colorWithRed:88.0/255.0 green:101.0/255.0 blue:242.0/255.0 alpha:1.0];
        unlockButton.layer.cornerRadius = 22.0;
        unlockButton.clipsToBounds = YES;
        [unlockButton addTarget:[NSBlockOperation blockOperationWithBlock:^{
            triggerBiometricAuth(YES);
        }] action:@selector(main) forControlEvents:UIControlEventTouchUpInside];
        [centerContainer addSubview:unlockButton];

        [NSLayoutConstraint activateConstraints:@[
            [logoImageView.centerXAnchor constraintEqualToAnchor:centerContainer.centerXAnchor],
            [logoImageView.topAnchor constraintEqualToAnchor:centerContainer.topAnchor],
            [logoImageView.widthAnchor constraintEqualToConstant:90],
            [logoImageView.heightAnchor constraintEqualToConstant:90],

            [statusLabel.topAnchor constraintEqualToAnchor:logoImageView.bottomAnchor constant:24],
            [statusLabel.leadingAnchor constraintEqualToAnchor:centerContainer.leadingAnchor],
            [statusLabel.trailingAnchor constraintEqualToAnchor:centerContainer.trailingAnchor],

            [subLabel.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:8],
            [subLabel.leadingAnchor constraintEqualToAnchor:centerContainer.leadingAnchor],
            [subLabel.trailingAnchor constraintEqualToAnchor:centerContainer.trailingAnchor],

            [unlockButton.topAnchor constraintEqualToAnchor:subLabel.bottomAnchor constant:32],
            [unlockButton.centerXAnchor constraintEqualToAnchor:centerContainer.centerXAnchor],
            [unlockButton.widthAnchor constraintEqualToConstant:220],
            [unlockButton.heightAnchor constraintEqualToConstant:46],
            [unlockButton.bottomAnchor constraintEqualToAnchor:centerContainer.bottomAnchor]
        ]];
    }

    lockOverlayView.frame = window.bounds;
    lockOverlayView.alpha = 1.0;
    if (statusLabel) {
        statusLabel.text = @"Discord đã khoá";
    }
    if (subLabel) {
        subLabel.text = getCustomReasonText();
    }
    if (lockOverlayView.superview == nil) {
        [window addSubview:lockOverlayView];
        [window bringSubviewToFront:lockOverlayView];
    }
}

static void hideLockOverlayAnimated() {
    if (lockOverlayView && lockOverlayView.superview) {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            lockOverlayView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [lockOverlayView removeFromSuperview];
            lockOverlayView = nil;
        }];
    }
}

// MARK: - Biometric Trigger
static void triggerBiometricAuth(BOOL isInteractive) {
    // If already authenticating or not locked, do not trigger duplicate prompt!
    if (isAuthenticating || !isCurrentlyLocked) {
        return;
    }

    isAuthenticating = YES;

    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @"Nhập mật mã";

    NSString *reason = getCustomReasonText();

    NSError *authError = nil;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&authError]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
                localizedReason:reason
                          reply:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                isAuthenticating = NO;
                if (success) {
                    isCurrentlyLocked = NO;
                    lastBackgroundTime = [NSDate timeIntervalSinceReferenceDate];
                    hideLockOverlayAnimated();
                    AudioServicesPlaySystemSound(1519); // Success feedback
                } else {
                    isCurrentlyLocked = YES;
                    if (error.code == LAErrorUserCancel || error.code == LAErrorSystemCancel || error.code == LAErrorAppCancel) {
                        statusLabel.text = @"Discord đã khoá";
                    } else {
                        statusLabel.text = @"Xác thực không thành công";
                        AudioServicesPlaySystemSound(1521); // Error feedback
                    }
                }
            });
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            isAuthenticating = NO;
            statusLabel.text = @"Thiết bị không hỗ trợ xác thực";
        });
    }
}

// MARK: - App Lifecycle Notifications
static void handleWillResignActive(NSNotification *note) {
    // CRITICAL FIX: If authentication is currently in progress,
    // this notification is caused by Touch ID / Passcode prompt appearing!
    // We MUST ignore it so we don't relock or interfere with the prompt!
    if (isAuthenticating) {
        return;
    }

    if (!isLockEnabled()) return;

    // Truly entering App Switcher or leaving app
    isCurrentlyLocked = YES;
    showLockOverlay();
}

static void handleDidEnterBackground(NSNotification *note) {
    if (isAuthenticating) return;
    lastBackgroundTime = [NSDate timeIntervalSinceReferenceDate];
}

static void handleDidBecomeActive(NSNotification *note) {
    // CRITICAL FIX: If we just finished authenticating or are in the middle of it,
    // this notification is caused by Touch ID / Passcode dismissing!
    // DO NOT TRIGGER A DUPLICATE PROMPT!
    if (isAuthenticating) {
        return;
    }

    if (!isLockEnabled()) {
        hideLockOverlayAnimated();
        isCurrentlyLocked = NO;
        return;
    }

    if (!isCurrentlyLocked) {
        // App is already unlocked! Do nothing!
        return;
    }

    // Check timeout
    NSInteger timeout = getTimeoutSeconds();
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (timeout > 0 && lastBackgroundTime > 0 && (now - lastBackgroundTime) < timeout) {
        // Within grace period
        isCurrentlyLocked = NO;
        hideLockOverlayAnimated();
        return;
    }

    // Must lock & prompt
    showLockOverlay();
    triggerBiometricAuth(NO);
}

// MARK: - 3-Finger Long Press Settings Gesture
@interface DiscordAppLockGestureHandler : NSObject
+ (instancetype)shared;
- (void)handleThreeFingerPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation DiscordAppLockGestureHandler

+ (instancetype)shared {
    static DiscordAppLockGestureHandler *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[DiscordAppLockGestureHandler alloc] init];
    });
    return inst;
}

- (void)handleThreeFingerPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    // Haptic feedback
    AudioServicesPlaySystemSound(1519);

    // Require biometric auth before opening settings to prevent unauthorized tampering!
    LAContext *context = [[LAContext alloc] init];
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:@"Xác thực để mở Cài đặt Discord AppLock"
                      reply:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                showSettingsActionSheet();
            }
        });
    }];
}

@end

static void showSettingsActionSheet() {
    UIWindow *window = getAppKeyWindow();
    UIViewController *rootVC = window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 Cài đặt Discord AppLock"
                                                                   message:@"Tuỳ chỉnh tính năng bảo mật sinh trắc học và che màn hình đa nhiệm"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // 1. Toggle Lock
    BOOL enabled = isLockEnabled();
    NSString *toggleTitle = enabled ? @"✅ Khoá Touch ID / Face ID: [ĐANG BẬT]" : @"❌ Khoá Touch ID / Face ID: [ĐANG TẮT]";
    [alert addAction:[UIAlertAction actionWithTitle:toggleTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        setLockEnabled(!enabled);
        showSettingsActionSheet();
    }]];

    // 2. Overlay Style
    NSInteger style = getOverlayStyle();
    NSString *styleTitle = (style == 1) ? @"🖼 Kiểu che: [Logo Discord]" : @"🌫 Kiểu che: [Làm mờ Blur]";
    [alert addAction:[UIAlertAction actionWithTitle:styleTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        setOverlayStyle(style == 1 ? 0 : 1);
        showSettingsActionSheet();
    }]];

    // 3. Timeout Selection
    NSInteger timeout = getTimeoutSeconds();
    NSString *timeoutStr = (timeout == 0) ? @"Ngay lập tức" : (timeout == 30) ? @"30 giây" : (timeout == 60) ? @"1 phút" : [NSString stringWithFormat:@"%ld giây", (long)timeout];
    NSString *timeoutTitle = [NSString stringWithFormat:@"⏱ Thời gian khoá lại: [%@]", timeoutStr];
    [alert addAction:[UIAlertAction actionWithTitle:timeoutTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIAlertController *timeoutAlert = [UIAlertController alertControllerWithTitle:@"Thời gian khoá lại" message:@"Chọn khoảng thời gian không hỏi lại vân tay khi quay lại app" preferredStyle:UIAlertControllerStyleActionSheet];
        [timeoutAlert addAction:[UIAlertAction actionWithTitle:@"Ngay lập tức (Mặc định)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { setTimeoutSeconds(0); }]];
        [timeoutAlert addAction:[UIAlertAction actionWithTitle:@"Sau 30 giây" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { setTimeoutSeconds(30); }]];
        [timeoutAlert addAction:[UIAlertAction actionWithTitle:@"Sau 1 phút" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { setTimeoutSeconds(60); }]];
        [timeoutAlert addAction:[UIAlertAction actionWithTitle:@"Sau 5 phút" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { setTimeoutSeconds(300); }]];
        [timeoutAlert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [rootVC presentViewController:timeoutAlert animated:YES completion:nil];
    }]];

    // 4. Custom Reason Text
    [alert addAction:[UIAlertAction actionWithTitle:@"✏️ Đổi lời nhắn xác thực (Subtitle)..." style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIAlertController *promptAlert = [UIAlertController alertControllerWithTitle:@"Đổi lời nhắn xác thực"
                                                                             message:@"Nhập câu chữ hiển thị dưới bảng Touch ID / Face ID"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
        [promptAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.text = getCustomReasonText();
            textField.placeholder = @"Ví dụ: Mở khoá tin nhắn bí mật";
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        }];
        [promptAlert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            UITextField *tf = promptAlert.textFields.firstObject;
            if (tf.text && tf.text.length > 0) {
                setCustomReasonText(tf.text);
            }
        }]];
        [promptAlert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [rootVC presentViewController:promptAlert animated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    [rootVC presentViewController:alert animated:YES completion:nil];
}

static void attachThreeFingerGestureToWindow(UIWindow *window) {
    if (!window) return;
    for (UIGestureRecognizer *g in window.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]] && ((UILongPressGestureRecognizer *)g).numberOfTouchesRequired == 3) {
            return; // Already attached
        }
    }

    UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:[DiscordAppLockGestureHandler shared] action:@selector(handleThreeFingerPress:)];
    recognizer.numberOfTouchesRequired = 3;
    recognizer.minimumPressDuration = 0.7;
    recognizer.cancelsTouchesInView = NO;
    [window addGestureRecognizer:recognizer];
}

// MARK: - Lifecycle Observer
@interface DiscordAppLockObserver : NSObject
@end

@implementation DiscordAppLockObserver

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) { handleWillResignActive(note); }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) { handleDidEnterBackground(note); }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        UIWindow *window = getAppKeyWindow();
        if (window) {
            attachThreeFingerGestureToWindow(window);
        }
        handleDidBecomeActive(note);
    }];
}

@end

// MARK: - Constructor
%ctor {
    NSLog(@"[DiscordAppLock] Native Tweak Initialized with 3-finger gesture settings!");
}
