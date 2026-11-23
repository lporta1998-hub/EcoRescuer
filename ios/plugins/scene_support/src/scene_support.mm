// Green Guardians: UIScene lifecycle support for Godot 4.5 on iOS 27+.
// iOS 27 aborts apps built with the iOS 27 SDK that don't adopt UIScene
// (UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption). Godot 4.5
// creates its UIWindow in the app delegate, so this scene delegate attaches
// that window to the scene and forwards the lifecycle events that UIKit no
// longer sends to the app delegate once scenes are in use.
#import <UIKit/UIKit.h>

@interface GGSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(strong, nonatomic) UIWindow *window;
@end

@implementation GGSceneDelegate

static void gg_forward(SEL sel) {
	UIApplication *app = UIApplication.sharedApplication;
	id<UIApplicationDelegate> delegate = app.delegate;
	if ([delegate respondsToSelector:sel]) {
		((void (*)(id, SEL, UIApplication *))[(NSObject *)delegate methodForSelector:sel])(delegate, sel, app);
	}
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
	if (![scene isKindOfClass:[UIWindowScene class]]) {
		return;
	}
	UIWindowScene *windowScene = (UIWindowScene *)scene;
	id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
	UIWindow *old = [delegate respondsToSelector:@selector(window)] ? delegate.window : nil;
	UIViewController *vc = old.rootViewController;
	if (vc == nil) {
		NSLog(@"[SceneSupport] Godot window not found");
		return;
	}
	// Re-parenting Godot's window onto the scene leaves it with the safe-area
	// insets it got without a scene (portrait: notch at the top), which makes
	// get_display_safe_area() wrong in landscape. Move Godot's view controller
	// into a window created for the scene instead, and hand that window back
	// to Godot's app delegate service.
	old.rootViewController = nil;
	old.hidden = YES;
	UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
	window.rootViewController = vc;
	self.window = window;
	Class appDelegateClass = NSClassFromString(@"GDTApplicationDelegate");
	if ([appDelegateClass respondsToSelector:@selector(services)]) {
		for (id service in [appDelegateClass performSelector:@selector(services)]) {
			if ([service respondsToSelector:@selector(setWindow:)]) {
				[service setWindow:window];
			}
		}
	}
	[window makeKeyAndVisible];
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
	gg_forward(@selector(applicationDidBecomeActive:));
}

- (void)sceneWillResignActive:(UIScene *)scene {
	gg_forward(@selector(applicationWillResignActive:));
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
	gg_forward(@selector(applicationWillEnterForeground:));
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
	gg_forward(@selector(applicationDidEnterBackground:));
}

@end

// Called by Godot's generated plugin loader (C++ linkage). Referencing the
// class here keeps the linker from stripping it.
void scene_support_init() {
	[GGSceneDelegate class];
}

void scene_support_deinit() {
}
