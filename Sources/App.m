#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "SimulationController.h"
@class RouteViewController;
@interface WeakReceiver : NSObject <WKScriptMessageHandler>
@property(nonatomic,weak) RouteViewController *target;
@end
@interface RouteViewController : UIViewController <WKScriptMessageHandler, WKNavigationDelegate>
@property(nonatomic,strong) WKWebView *web;
@property(nonatomic,strong) SimulationController *sim;
@end
@implementation WeakReceiver
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message { [self.target userContentController:controller didReceiveScriptMessage:message]; }
@end
@implementation RouteViewController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.sim=SimulationController.new;
    WKWebViewConfiguration *config=WKWebViewConfiguration.new;
    WeakReceiver *receiver=WeakReceiver.new;receiver.target=self;
    [config.userContentController addScriptMessageHandler:receiver name:@"routeLab"];
    self.web=[[WKWebView alloc] initWithFrame:CGRectZero configuration:config];self.web.navigationDelegate=self;
    self.web.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:self.web];
    UILayoutGuide *g=self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[[self.web.topAnchor constraintEqualToAnchor:g.topAnchor],[self.web.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],[self.web.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],[self.web.trailingAnchor constraintEqualToAnchor:g.trailingAnchor]]];
    NSURL *folder=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"web" isDirectory:YES];
    [self.web loadFileURL:[folder URLByAppendingPathComponent:@"index.html"] allowingReadAccessToURL:folder];
}
- (NSDictionary *)snapshot {
    double elapsed=self.sim.elapsed;
    RoutePlan *route=self.sim.route;
    double seconds=route?route.plan.seconds:1;
    NSDictionary *plan=route?@{@"points":route.points,@"meters":@(route.plan.meters),@"seconds":@(seconds),@"route_length":@(route.plan.length)}:nil;
    NSString *phase=self.sim.phase;
    if([phase isEqual:@"running"] && elapsed>=seconds)phase=@"finished";
    CLLocation *point=route && self.sim.needsRestore?[route locationAt:elapsed]:nil;
    return @{@"phase":phase,@"message":self.sim.message?:@"",@"needs_restore":@(self.sim.needsRestore),@"elapsed":@(elapsed),@"countdown_remaining":@(self.sim.countdownRemaining),@"traveled":@(route?route.plan.meters*elapsed/seconds:0),@"plan":plan?:NSNull.null,@"point":point?@[@(point.coordinate.latitude),@(point.coordinate.longitude)]:NSNull.null,@"token":@"native",@"device":@{@"name":@"本机定位接口 · 待实测",@"connected":@(NSClassFromString(@"CLSimulationManager")!=nil)}};
}
- (void)reply:(NSNumber *)identifier result:(id)result error:(NSString *)error {
    NSArray *arguments=@[identifier,result?:NSNull.null,error?:NSNull.null];
    NSData *json=[NSJSONSerialization dataWithJSONObject:arguments options:NSJSONWritingFragmentsAllowed error:nil];
    if(!json)return;
    NSString *script=[NSString stringWithFormat:@"window.routeLabReply(...%@)",[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [self.web evaluateJavaScript:script completionHandler:nil];
}
- (RoutePlan *)plan:(NSDictionary *)data {
    if(![data[@"points"] isKindOfClass:NSArray.class])return nil;
    return [[RoutePlan alloc] initWithPoints:data[@"points"] meters:[data[@"meters"] doubleValue] seconds:[data[@"minutes"] doubleValue]*60];
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    if(!message.frameInfo.isMainFrame || !message.frameInfo.request.URL.isFileURL)return;
    NSString *root=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"web/"];
    if(![message.frameInfo.request.URL.path hasPrefix:root])return;
    NSDictionary *body=message.body;if(![body isKindOfClass:NSDictionary.class])return;
    NSNumber *identifier=body[@"id"];NSString *action=body[@"action"];NSDictionary *data=body[@"data"];
    if(![identifier isKindOfClass:NSNumber.class]||![action isKindOfClass:NSString.class]||![data isKindOfClass:NSDictionary.class])return;
    @try {
        id result=nil;NSString *error=nil;
        if([action isEqual:@"config"]){NSData *bytes=[NSData dataWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"config" withExtension:@"json"]];result=[NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil];}
        else if([action isEqual:@"state"] || [action isEqual:@"refresh"]) result=[self snapshot];
        else if([@[@"preview",@"anchor",@"share"] containsObject:action]) {
            RoutePlan *route=[self plan:data];
            if(!route)error=@"路线无效：请闭合重复路线，距离 1～10000 米、时长 0.02～60 分钟";
            else if([action isEqual:@"preview"])result=@{@"route_length":@(route.plan.length),@"meters":@(route.plan.meters),@"seconds":@(route.plan.seconds)};
            else if([action isEqual:@"anchor"]){[self.sim anchor:route];result=[self snapshot];}
            else {
                NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"route-test.gpx"]];
                if(![[route gpx] writeToURL:url atomically:YES])error=@"GPX 写入失败";
                else {UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];share.popoverPresentationController.sourceView=self.view;share.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds),1,1);[self presentViewController:share animated:YES completion:nil];result=@{};}
            }
        }
        else if([action isEqual:@"countdown"]){RoutePlan *route=[self plan:data];if(!route || !self.sim.route || ![route.points isEqual:self.sim.route.points] || route.plan.meters!=self.sim.route.plan.meters || route.plan.seconds!=self.sim.route.plan.seconds)error=@"请先确认同一条路线的起点";else{[self.sim countdown];result=[self snapshot];}}
        else if([action isEqual:@"pause"]){[self.sim pause];result=[self snapshot];}
        else if([action isEqual:@"resume"]){[self.sim resume];result=[self snapshot];}
        else if([action isEqual:@"restore"]){[self.sim restore];result=[self snapshot];}
        else error=@"未知本机操作";
        [self reply:identifier result:result error:error];
    } @catch(NSException *exception){[self reply:identifier result:nil error:@"本机操作异常，请重新打开应用并恢复定位"];}
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url=action.request.URL;
    if(url.isFileURL && [url.path hasPrefix:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"web/"]]){decisionHandler(WKNavigationActionPolicyAllow);return;}
    if(action.navigationType==WKNavigationTypeLinkActivated && [@[@"https",@"http"] containsObject:url.scheme.lowercaseString]) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    decisionHandler(WKNavigationActionPolicyCancel);
}
@end
@interface RouteSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation RouteSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if(![scene isKindOfClass:UIWindowScene.class])return;
    self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController=RouteViewController.new;[self.window makeKeyAndVisible];
}
@end
@interface RouteAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation RouteAppDelegate
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *config=[[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];config.delegateClass=RouteSceneDelegate.class;return config;
}
@end
int main(int argc,char *argv[]) { @autoreleasepool {return UIApplicationMain(argc,argv,nil,NSStringFromClass(RouteAppDelegate.class));} }
