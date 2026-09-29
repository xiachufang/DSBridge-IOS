#import <UIKit/UIKit.h>
#import "DWKWebView.h"

@interface DialogTestController : UIViewController <WKNavigationDelegate>
@property (nonatomic, strong) DWKWebView *webView;
@property (nonatomic, strong) UILabel *result;
@end
@implementation DialogTestController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    self.webView = [[DWKWebView alloc] initWithFrame:CGRectZero configuration:[WKWebViewConfiguration new]];
    self.webView.navigationDelegate = self;
    [self.webView customJavascriptDialogLabelTitles:@{
        @"alertTitle": @"Alert title", @"alertBtn": @"OK",
        @"confirmTitle": @"Confirm title", @"confirmCancelBtn": @"Cancel", @"confirmOkBtn": @"OK",
        @"promptCancelBtn": @"Cancel", @"promptOkBtn": @"OK"
    }];
    self.result = [UILabel new];
    self.result.accessibilityIdentifier = @"result";
    self.result.text = @"loading";
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.result]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    for (NSString *name in @[@"alert", @"confirm", @"prompt", @"chain", @"nonblocking"]) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:name forState:UIControlStateNormal];
        button.accessibilityIdentifier = name;
        [button addTarget:self action:@selector(runDialog:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
    }
    [stack addArrangedSubview:self.webView];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
    [self.webView loadHTMLString:@"<html><body>DSBridge scene dialog tests</body></html>" baseURL:nil];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.result.text = @"ready";
}
- (void)runDialog:(UIButton *)button {
    NSString *name = button.currentTitle;
    [self.webView disableJavascriptDialogBlock:[name isEqualToString:@"nonblocking"]];
    NSString *script = @{
        @"alert": @"alert('alert message'); 'done'",
        @"confirm": @"String(confirm('confirm message'))",
        @"prompt": @"JSON.stringify(prompt('Prompt title', 'seed'))",
        @"chain": @"alert('first'); String(confirm('second'))",
        @"nonblocking": @"String(confirm('nonblocking message'))"
    }[name];
    self.result.text = @"waiting";
    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        weakSelf.result.text = error ? error.localizedDescription : [result description];
    }];
}
@end

@interface DialogTestSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation DialogTestSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [DialogTestController new];
    [self.window makeKeyAndVisible];
}
@end

@interface DialogTestAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation DialogTestAppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Tests" sessionRole:session.role];
    configuration.delegateClass = DialogTestSceneDelegate.class;
    return configuration;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(DialogTestAppDelegate.class));
    }
}
