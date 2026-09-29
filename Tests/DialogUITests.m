#import <XCTest/XCTest.h>

@interface DialogUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end
@implementation DialogUITests
- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    self.app = [XCUIApplication new];
    [self.app launch];
    [self expectResult:@"ready"];
}
- (void)expectResult:(NSString *)value {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == %@", value];
    [self expectationForPredicate:predicate evaluatedWithObject:self.app.staticTexts[@"result"] handler:nil];
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        if (error) { NSLog(@"Expected result %@; actual %@", value, self.app.staticTexts[@"result"].label); }
    }];
}
- (XCUIElement *)openDialog:(NSString *)name {
    [self.app.buttons[name] tap];
    XCUIElement *alert = self.app.alerts.firstMatch;
    XCTAssertTrue([alert waitForExistenceWithTimeout:5]);
    return alert;
}
- (void)testAlertCompletesAfterOK {
    XCUIElement *alert = [self openDialog:@"alert"];
    XCTAssertTrue(alert.staticTexts[@"Alert title"].exists);
    [alert.buttons[@"OK"] tap];
    [self expectResult:@"done"];
}
- (void)testConfirmOKAndCancel {
    [[[self openDialog:@"confirm"] buttons][@"OK"] tap];
    [self expectResult:@"true"];
    [[[self openDialog:@"confirm"] buttons][@"Cancel"] tap];
    [self expectResult:@"false"];
}
- (void)testPromptInputAndCancel {
    XCUIElement *alert = [self openDialog:@"prompt"];
    XCUIElement *field = alert.textFields.firstMatch;
    XCTAssertEqualObjects(field.value, @"seed");
    [field tap];
    [field typeText:@"42"];
    NSString *input = field.value;
    XCTAssertTrue([input containsString:@"42"]);
    [alert.buttons[@"OK"] tap];
    [self expectResult:[NSString stringWithFormat:@"\"%@\"", input]];
    [[[self openDialog:@"prompt"] buttons][@"Cancel"] tap];
    [self expectResult:@"\"\""];
}
- (void)testConsecutiveJavaScriptDialogs {
    [[[self openDialog:@"chain"] buttons][@"OK"] tap];
    XCUIElement *second = self.app.alerts[@"Confirm title"];
    XCTAssertTrue([second waitForExistenceWithTimeout:5]);
    [second.buttons[@"OK"] tap];
    [self expectResult:@"true"];
}
- (void)testNonblockingConfirmReturnsBeforeSelection {
    XCUIElement *alert = [self openDialog:@"nonblocking"];
    [self expectResult:@"true"];
    [alert.buttons[@"Cancel"] tap];
    [self expectResult:@"true"];
}
@end
