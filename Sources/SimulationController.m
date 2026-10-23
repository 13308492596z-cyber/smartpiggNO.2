#import "SimulationController.h"
#import <UIKit/UIKit.h>
#include <math.h>
// Private service interface researched from Geranium and locsim; TrollStore installation required.
@protocol RLPrivateSimulator <NSObject>
@property(assign,nonatomic) uint8_t locationDeliveryBehavior;
@property(assign,nonatomic) uint8_t locationRepeatBehavior;
- (void)stopLocationSimulation;
- (void)clearSimulatedLocations;
- (void)appendSimulatedLocation:(CLLocation *)location;
- (void)loadScenarioFromURL:(NSURL *)url;
- (void)flush;
- (void)startLocationSimulation;
@end
@implementation SimulationController {
    id<RLPrivateSimulator> _manager;
    NSTimeInterval _started;
    double _held;
    NSUInteger _generation;
    NSDate *_deadline;
}
- (instancetype)init {
    if(!(self=[super init])) return nil;
    _needsRestore=[NSUserDefaults.standardUserDefaults boolForKey:@"simulation-needs-restore"];
    _phase=_needsRestore?@"recovery":@"idle";
    _message=_needsRestore?@"上次模拟未恢复，请先恢复真实定位":@"尚未开始模拟";
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationWillResignActiveNotification object:nil];
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (double)elapsed {
    if([_phase isEqual:@"running"]) return fmin(_route.plan.seconds,_held+NSProcessInfo.processInfo.systemUptime-_started);
    return _held;
}
- (NSInteger)countdownRemaining {return [_phase isEqual:@"countdown"]?(NSInteger)ceil(MAX(0,[_deadline timeIntervalSinceNow])):0;}
- (void)notify { if(_changed) _changed(); }
- (void)flag:(BOOL)value {
    _needsRestore=value;
    [NSUserDefaults.standardUserDefaults setBool:value forKey:@"simulation-needs-restore"];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (BOOL)perform:(void (^)(id<RLPrivateSimulator> manager))operation {
    @try {
        if(!_manager) {
            Class cls=NSClassFromString(@"CLSimulationManager");
            if(!cls) [NSException raise:@"Unavailable" format:@"当前系统没有定位模拟接口"];
            _manager=[cls new];
        }
        operation(_manager);
        return YES;
    } @catch(NSException *error) {
        _phase=@"error";_message=[NSString stringWithFormat:@"定位接口调用失败：%@；请恢复定位",error.reason?:error.name];
        [self notify];return NO;
    }
}
- (BOOL)anchor:(RoutePlan *)route {
    if(_needsRestore){_message=@"请先恢复真实定位，再修改路线";[self notify];return NO;}
    _route=route;_held=0;[self flag:YES];
    BOOL ok=[self perform:^(id<RLPrivateSimulator> m){
        [m stopLocationSimulation];[m clearSimulatedLocations];
        [m appendSimulatedLocation:[route locationAt:0]];[m flush];[m startLocationSimulation];
    }];
    if(ok){_phase=@"positioned";_message=@"起点请求已发送，请在地图核对后开始";}
    [self notify];return ok;
}
- (void)background {
    if([_phase isEqual:@"countdown"]){_generation++;_phase=@"positioned";_message=@"倒计时因切换应用而取消，起点保持";[self notify];}
}
- (void)countdown {
    if(![_phase isEqual:@"positioned"])return;
    _phase=@"countdown";_deadline=[NSDate dateWithTimeIntervalSinceNow:10];
    NSUInteger generation=++_generation;
    _message=@"10 秒后加载路线；归零后切换到测试地图";[self notify];
    [self tickCountdown:generation];
}
- (void)tickCountdown:(NSUInteger)generation {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(generation!=self->_generation || ![self->_phase isEqual:@"countdown"])return;
        double left=[self->_deadline timeIntervalSinceNow];
        if(left < -2){self->_phase=@"positioned";self->_message=@"倒计时中断，请重新开始";[self notify];return;}
        if(left<=0){[self resumeRoute];return;}
        self->_message=[NSString stringWithFormat:@"准备开始：%ld 秒",(long)ceil(left)];
        [self notify];[self tickCountdown:generation];
    });
}
- (void)resumeRoute {
    if(!_route || _held>=_route.plan.seconds)return;
    NSDictionary *scenario=[_route scenarioFrom:_held];
    NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"route-scenario.plist"]];
    if(![scenario writeToURL:url atomically:YES]){_phase=@"error";_message=@"路线文件写入失败，请恢复定位";[self notify];return;}
    BOOL ok=[self perform:^(id<RLPrivateSimulator> m){
        [m stopLocationSimulation];[m clearSimulatedLocations];
        m.locationDeliveryBehavior=2;m.locationRepeatBehavior=0;
        [m loadScenarioFromURL:url];[m flush];[m startLocationSimulation];
    }];
    if(ok){_started=NSProcessInfo.processInfo.systemUptime;_phase=@"running";_message=@"轨迹已交给系统，后台持续运行需实机确认";}
    [self notify];
}
- (void)pause {
    if([_phase isEqual:@"countdown"]){_generation++;_phase=@"positioned";_message=@"倒计时已取消";[self notify];return;}
    if(![_phase isEqual:@"running"])return;
    _held=self.elapsed;
    CLLocation *point=[_route locationAt:_held];
    BOOL ok=[self perform:^(id<RLPrivateSimulator> m){[m stopLocationSimulation];[m clearSimulatedLocations];[m appendSimulatedLocation:point];[m flush];[m startLocationSimulation];}];
    if(ok){_phase=@"paused";_message=@"暂停请求已发送，保留当前模拟点";}
    [self notify];
}
- (void)resume {if([_phase isEqual:@"paused"])[self resumeRoute];}
- (void)restore {
    _generation++;
    BOOL ok=[self perform:^(id<RLPrivateSimulator> m){[m stopLocationSimulation];[m clearSimulatedLocations];[m flush];}];
    if(ok){[self flag:NO];_phase=@"idle";_held=0;_message=@"停止模拟请求已发送，请在手机地图核对真实位置";}
    [self notify];
}
@end
