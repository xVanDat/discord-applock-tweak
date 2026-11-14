#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

#define PREF_KEY_ENABLED @"DiscordAppLock_Enabled"
#define PREF_KEY_STYLE   @"DiscordAppLock_Style"     // 0 = Blur, 1 = Discord Logo
#define PREF_KEY_TIMEOUT @"DiscordAppLock_Timeout"   // seconds (0 = immediate)
#define PREF_KEY_REASON  @"DiscordAppLock_Reason"

static BOOL isCurrentlyLocked = NO;
static NSTimeInterval lastBackgroundTime = 0;
static UIView *lockOverlayView = nil;
static UIButton *unlockButton = nil;
static UILabel *statusLabel = nil;

// MARK: - Config Helper (Reads shared config from Documents/applock_config.json or NSUserDefaults)
static NSDictionary *loadSharedConfig() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) return nil;
    NSString *configPath = [paths.firstObject stringByAppendingPathComponent:@"applock_config.json"];
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    if (!data) return nil;
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if ([json isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)json;
    }
    return nil;
}

static BOOL isLockEnabled() {
    NSDictionary *cfg = loadSharedConfig();
    if (cfg && cfg[@"enabled"] != nil) {
        return [cfg[@"enabled"] boolValue];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:PREF_KEY_ENABLED] == nil) {
        return YES; // Default enabled
    }
    return [defaults boolForKey:PREF_KEY_ENABLED];
}

static NSInteger getOverlayStyle() {
    NSDictionary *cfg = loadSharedConfig();
    if (cfg && cfg[@"overlayStyle"] != nil) {
        return [cfg[@"overlayStyle"] integerValue];
    }
    return [[NSUserDefaults standardUserDefaults] integerForKey:PREF_KEY_STYLE];
}

static NSInteger getTimeoutSeconds() {
    NSDictionary *cfg = loadSharedConfig();
    if (cfg && cfg[@"timeout"] != nil) {
        return [cfg[@"timeout"] integerValue];
    }
    return [[NSUserDefaults standardUserDefaults] integerForKey:PREF_KEY_TIMEOUT];
}

static NSString *getCustomReasonText() {
    NSDictionary *cfg = loadSharedConfig();
    if (cfg && [cfg[@"customReason"] isKindOfClass:[NSString class]] && [cfg[@"customReason"] length] > 0) {
        return cfg[@"customReason"];
    }
    NSString *def = [[NSUserDefaults standardUserDefaults] stringForKey:PREF_KEY_REASON];
    if (def && def.length > 0) {
        return def;
    }
    return @"Mở khoá ứng dụng Discord";
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

// Draw a smooth Discord Clyde Logo
static UIImage *createDiscordLogo(CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *discordBlurple = [UIColor colorWithRed:88.0/255.0 green:101.0/255.0 blue:242.0/255.0 alpha:1.0];
    [discordBlurple setFill];

    // Background rounded circle
    UIBezierPath *bgCircle = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:size * 0.28];
    [bgCircle fill];

    // Inner icon shape
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

    // Eyes
    [discordBlurple setFill];
    UIBezierPath *leftEye = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(36 * scale, 47 * scale, 10 * scale, 10 * scale)];
    [leftEye fill];

    UIBezierPath *rightEye = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(54 * scale, 47 * scale, 10 * scale, 10 * scale)];
    [rightEye fill];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// Forward declaration
static void triggerBiometricAuth(BOOL isInteractive);

// MARK: - Lock Overlay Creation
static void showLockOverlay() {
    UIWindow *window = getAppKeyWindow();
    if (!window) return;

    if (!lockOverlayView) {
        lockOverlayView = [[UIView alloc] initWithFrame:window.bounds];
        lockOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        lockOverlayView.backgroundColor = [UIColor colorWithRed:24.0/255.0 green:25.0/255.0 blue:28.0/255.0 alpha:1.0]; // Discord Dark #18191c

        NSInteger style = getOverlayStyle();
        if (style == 0) {
            // Blur Effect
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurView.frame = lockOverlayView.bounds;
            blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [lockOverlayView addSubview:blurView];
        }

        // Center Container
        UIView *centerContainer = [[UIView alloc] init];
        centerContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [lockOverlayView addSubview:centerContainer];

        [NSLayoutConstraint activateConstraints:@[
            [centerContainer.centerXAnchor constraintEqualToAnchor:lockOverlayView.centerXAnchor],
            [centerContainer.centerYAnchor constraintEqualToAnchor:lockOverlayView.centerYAnchor, constant:-20.0],
            [centerContainer.widthAnchor constraintEqualToAnchor:lockOverlayView.widthAnchor, multiplier:0.85]
        ]];

        // Discord Logo
        UIImageView *logoImageView = [[UIImageView alloc] initWithImage:createDiscordLogo(90)];
        logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
        logoImageView.layer.shadowColor = [UIColor blackColor].CGColor;
        logoImageView.layer.shadowOpacity = 0.35;
        logoImageView.layer.shadowOffset = CGSizeMake(0, 4);
        logoImageView.layer.shadowRadius = 8.0;
        [centerContainer addSubview:logoImageView];

        // Status Label
        statusLabel = [[UILabel alloc] init];
        statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        statusLabel.text = @"Discord đã khoá";
        statusLabel.textColor = [UIColor whiteColor];
        statusLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
        statusLabel.textAlignment = NSTextAlignmentCenter;
        [centerContainer addSubview:statusLabel];

        UILabel *subLabel = [[UILabel alloc] init];
        subLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subLabel.text = getCustomReasonText();
        subLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        subLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        subLabel.textAlignment = NSTextAlignmentCenter;
        [centerContainer addSubview:subLabel];

        // Unlock Button
        unlockButton = [UIButton buttonWithType:UIButtonTypeSystem];
        unlockButton.translatesAutoresizingMaskIntoConstraints = NO;
        [unlockButton setTitle:@"Mở khoá Discord" forState:UIControlStateNormal];
        [unlockButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        unlockButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        unlockButton.backgroundColor = [UIColor colorWithRed:88.0/255.0 green:101.0/255.0 blue:242.0/255.0 alpha:1.0]; // Blurple
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
    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @"Nhập mật mã iPhone";

    NSString *reason = getCustomReasonText();

    NSError *authError = nil;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&authError]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
                localizedReason:reason
                          reply:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    isCurrentlyLocked = NO;
                    hideLockOverlayAnimated();
                    AudioServicesPlaySystemSound(1519); // Peek feedback
                } else {
                    isCurrentlyLocked = YES;
                    statusLabel.text = @"Xác thực không thành công";
                    AudioServicesPlaySystemSound(1521); // Error feedback
                }
            });
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            statusLabel.text = @"Thiết bị không hỗ trợ xác thực";
        });
    }
}

// MARK: - App Lifecycle Notifications
static void handleWillResignActive(NSNotification *note) {
    if (!isLockEnabled()) return;

    // Immediately show overlay synchronously before App Switcher snapshot is captured by iOS
    isCurrentlyLocked = YES;
    showLockOverlay();
}

static void handleDidEnterBackground(NSNotification *note) {
    lastBackgroundTime = [NSDate timeIntervalSinceReferenceDate];
}

static void handleDidBecomeActive(NSNotification *note) {
    if (!isLockEnabled()) {
        hideLockOverlayAnimated();
        isCurrentlyLocked = NO;
        return;
    }

    NSInteger timeout = getTimeoutSeconds();
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    // Check if timeout elapsed
    if (timeout > 0 && lastBackgroundTime > 0 && (now - lastBackgroundTime) < timeout) {
        // Within grace period
        isCurrentlyLocked = NO;
        hideLockOverlayAnimated();
        return;
    }

    // Must lock & prompt
    isCurrentlyLocked = YES;
    showLockOverlay();
    triggerBiometricAuth(NO);
}

// MARK: - React Native Native Module (DCDLocalAuth)
@interface DCDLocalAuth : NSObject
@end

@implementation DCDLocalAuth

+ (void)load {
    // Register lifecycle observers
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
                                                  usingBlock:^(NSNotification *note) { handleDidBecomeActive(note); }];
}

@end

// MARK: - Constructor
%ctor {
    NSLog(@"[DiscordAppLock] Native Tweak Initialized successfully!");
}
