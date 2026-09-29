#import <XCTest/XCTest.h>
#import "DWKWebView.h"

@interface DialogDelegate : NSObject <WKUIDelegate>
@property (nonatomic) NSUInteger calls;
@property (nonatomic, copy) void (^alertReply)(void);
@property (nonatomic, copy) void (^confirmReply)(BOOL);
@property (nonatomic, copy) void (^promptReply)(NSString *);
@end
@implementation DialogDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))handler {
    self.calls++;
    self.alertReply = handler;
}
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))handler {
    self.calls++;
    self.confirmReply = handler;
}
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)text initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))handler {
    self.calls++;
    self.promptReply = handler;
}
@end

@interface EchoBridge : NSObject
@end
@implementation EchoBridge
- (NSString *)echo:(NSString *)value { return value; }
@end

@interface DialogTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *controller;
@property (nonatomic, strong) DWKWebView *webView;
@property (nonatomic, strong) WKFrameInfo *frame;
@end
@implementation DialogTests
- (void)setUp {
    [super setUp];
    self.frame = [WKFrameInfo new];
    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class]) { scene = (UIWindowScene *)candidate; break; }
    }
    self.window = [[UIWindow alloc] initWithWindowScene:scene];
    self.controller = [UIViewController new];
    self.window.rootViewController = self.controller;
    [self.window makeKeyAndVisible];
    self.webView = [[DWKWebView alloc] initWithFrame:self.controller.view.bounds configuration:[WKWebViewConfiguration new]];
    [self.controller.view addSubview:self.webView];
}
- (void)tearDown {
    [self waitUntil:^BOOL { return !self.controller.presentedViewController.isBeingPresented; }];
    [self.webView removeFromSuperview];
    [self.controller dismissViewControllerAnimated:NO completion:nil];
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    self.webView = nil;
    self.controller = nil;
    self.window = nil;
    [super tearDown];
}
- (void)waitUntil:(BOOL (^)(void))condition {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) { return condition(); }];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:nil];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:5], XCTWaiterResultCompleted);
}
- (void)testDetachedWebViewResolvesAllDialogs {
    [self.webView removeFromSuperview];
    __block NSUInteger count = 0;
    [self.webView webView:self.webView runJavaScriptAlertPanelWithMessage:@"a" initiatedByFrame:self.frame completionHandler:^{ count++; }];
    [self.webView webView:self.webView runJavaScriptConfirmPanelWithMessage:@"c" initiatedByFrame:self.frame completionHandler:^(BOOL value) { XCTAssertFalse(value); count++; }];
    [self.webView webView:self.webView runJavaScriptTextInputPanelWithPrompt:@"p" defaultText:@"seed" initiatedByFrame:self.frame completionHandler:^(NSString *value) { XCTAssertEqualObjects(value, @""); count++; }];
    XCTAssertEqual(count, 3u);
    XCTAssertNil(self.controller.presentedViewController);
}
- (void)testDelegateRepliesOnlyOncePerRequest {
    DialogDelegate *delegate = [DialogDelegate new];
    self.webView.DSUIDelegate = delegate;
    __block NSUInteger alerts = 0, confirms = 0, prompts = 0;
    [self.webView webView:self.webView runJavaScriptAlertPanelWithMessage:@"a" initiatedByFrame:self.frame completionHandler:^{ alerts++; }];
    [self.webView webView:self.webView runJavaScriptConfirmPanelWithMessage:@"c" initiatedByFrame:self.frame completionHandler:^(BOOL value) { XCTAssertTrue(value); confirms++; }];
    [self.webView webView:self.webView runJavaScriptTextInputPanelWithPrompt:@"p" defaultText:@"seed" initiatedByFrame:self.frame completionHandler:^(NSString *value) { XCTAssertEqualObjects(value, @"reply"); prompts++; }];
    XCTAssertEqual(alerts + confirms + prompts, 0u);
    delegate.alertReply(); delegate.alertReply();
    delegate.confirmReply(YES); delegate.confirmReply(NO);
    delegate.promptReply(@"reply"); delegate.promptReply(nil);
    XCTAssertEqual(alerts, 1u); XCTAssertEqual(confirms, 1u); XCTAssertEqual(prompts, 1u);
    XCTAssertEqual(delegate.calls, 3u);
    XCTAssertNil(self.controller.presentedViewController);
}
- (void)testNonblockingDelegateCannotReplyTwice {
    DialogDelegate *delegate = [DialogDelegate new];
    self.webView.DSUIDelegate = delegate;
    [self.webView disableJavascriptDialogBlock:YES];
    __block NSUInteger alerts = 0, confirms = 0, prompts = 0;
    [self.webView webView:self.webView runJavaScriptAlertPanelWithMessage:@"a" initiatedByFrame:self.frame completionHandler:^{ alerts++; }];
    [self.webView webView:self.webView runJavaScriptConfirmPanelWithMessage:@"c" initiatedByFrame:self.frame completionHandler:^(BOOL value) { XCTAssertTrue(value); confirms++; }];
    [self.webView webView:self.webView runJavaScriptTextInputPanelWithPrompt:@"p" defaultText:@"seed" initiatedByFrame:self.frame completionHandler:^(NSString *value) { XCTAssertNil(value); prompts++; }];
    XCTAssertEqual(alerts, 1u); XCTAssertEqual(confirms, 1u); XCTAssertEqual(prompts, 1u);
    delegate.alertReply(); delegate.confirmReply(NO); delegate.promptReply(@"late");
    XCTAssertEqual(alerts, 1u); XCTAssertEqual(confirms, 1u); XCTAssertEqual(prompts, 1u);
    XCTAssertEqual(delegate.calls, 3u);
}
- (void)testBridgePromptRemainsSynchronousAndBypassesDelegate {
    DialogDelegate *delegate = [DialogDelegate new];
    self.webView.DSUIDelegate = delegate;
    [self.webView disableJavascriptDialogBlock:YES];
    [self.webView addJavascriptObject:[EchoBridge new] namespace:nil];
    __block NSUInteger count = 0;
    [self.webView webView:self.webView runJavaScriptTextInputPanelWithPrompt:@"_dsbridge=echo" defaultText:@"{\"data\":\"hello\"}" initiatedByFrame:self.frame completionHandler:^(NSString *value) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        XCTAssertEqualObjects(result[@"code"], @0);
        XCTAssertEqualObjects(result[@"data"], @"hello");
        count++;
    }];
    XCTAssertEqual(count, 1u);
    XCTAssertEqual(delegate.calls, 0u);
    XCTAssertNil(self.controller.presentedViewController);
}
- (void)testPromptLabelsDefaultTextAndDetachment {
    [self.webView customJavascriptDialogLabelTitles:@{@"promptCancelBtn": @"Back", @"promptOkBtn": @"Send"}];
    __block NSUInteger count = 0;
    [self.webView webView:self.webView runJavaScriptTextInputPanelWithPrompt:@"Question" defaultText:@"seed" initiatedByFrame:self.frame completionHandler:^(NSString *value) { XCTAssertEqualObjects(value, @""); count++; }];
    UIAlertController *alert = (UIAlertController *)self.controller.presentedViewController;
    XCTAssertTrue([alert isKindOfClass:UIAlertController.class]);
    XCTAssertEqualObjects(alert.title, @"Question");
    XCTAssertEqualObjects(alert.textFields.firstObject.text, @"seed");
    XCTAssertEqualObjects([alert.actions valueForKey:@"title"], (@[@"Back", @"Send"]));
    XCTAssertEqual(count, 0u);
    [self waitUntil:^BOOL { return !alert.isBeingPresented; }];
    [self.webView removeFromSuperview];
    XCTAssertEqual(count, 1u);
    [self waitUntil:^BOOL { return self.controller.presentedViewController == nil; }];
    XCTAssertEqual(count, 1u);
}
- (void)testConcurrentDialogsDoNotOverwriteFirstCompletion {
    __block NSUInteger first = 0, second = 0;
    [self.webView webView:self.webView runJavaScriptConfirmPanelWithMessage:@"first" initiatedByFrame:self.frame completionHandler:^(BOOL value) { XCTAssertFalse(value); first++; }];
    [self.webView webView:self.webView runJavaScriptConfirmPanelWithMessage:@"second" initiatedByFrame:self.frame completionHandler:^(BOOL value) { XCTAssertFalse(value); second++; }];
    XCTAssertEqual(first, 0u); XCTAssertEqual(second, 1u);
    [self waitUntil:^BOOL { return !self.controller.presentedViewController.isBeingPresented; }];
    [self.webView removeFromSuperview];
    XCTAssertEqual(first, 1u); XCTAssertEqual(second, 1u);
}
- (void)testProgrammaticDismissalResolvesPendingCompletion {
    __block NSUInteger count = 0;
    // Match UIKit's per-event autorelease pool rather than XCTest's method-wide pool.
    @autoreleasepool {
        [self.webView webView:self.webView runJavaScriptConfirmPanelWithMessage:@"confirm" initiatedByFrame:self.frame completionHandler:^(BOOL value) { XCTAssertFalse(value); count++; }];
    }
    [self waitUntil:^BOOL { return !self.controller.presentedViewController.isBeingPresented; }];
    @autoreleasepool {
        [self.controller dismissViewControllerAnimated:NO completion:nil];
    }
    [self waitUntil:^BOOL { return count == 1; }];
}
- (void)testUsesWebViewsWindowEvenWhenAnotherWindowIsKey {
    UIWindow *otherWindow = [[UIWindow alloc] initWithWindowScene:self.window.windowScene];
    otherWindow.rootViewController = [UIViewController new];
    [otherWindow makeKeyAndVisible];
    [self.webView webView:self.webView runJavaScriptAlertPanelWithMessage:@"alert" initiatedByFrame:self.frame completionHandler:^{}];
    XCTAssertTrue([self.controller.presentedViewController isKindOfClass:UIAlertController.class]);
    XCTAssertNil(otherWindow.rootViewController.presentedViewController);
    otherWindow.hidden = YES;
}
- (void)testExistingAlertIsNotCovered {
    UIAlertController *existing = [UIAlertController alertControllerWithTitle:@"existing" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [existing addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self.controller presentViewController:existing animated:NO completion:nil];
    __block NSUInteger count = 0;
    [self.webView webView:self.webView runJavaScriptConfirmPanelWithMessage:@"new" initiatedByFrame:self.frame completionHandler:^(BOOL value) { XCTAssertFalse(value); count++; }];
    XCTAssertEqual(count, 1u);
    XCTAssertEqual(self.controller.presentedViewController, existing);
    XCTAssertNil(existing.presentedViewController);
}
@end
