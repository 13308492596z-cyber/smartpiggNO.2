#import "RoutePlan.h"
@interface SimulationController : NSObject
@property(nonatomic,readonly) NSString *phase;
@property(nonatomic,readonly) NSString *message;
@property(nonatomic,readonly) RoutePlan *route;
@property(nonatomic,readonly) double elapsed;
@property(nonatomic,readonly) BOOL needsRestore;
@property(nonatomic,readonly) NSInteger countdownRemaining;
@property(nonatomic,copy) void (^changed)(void);
- (BOOL)anchor:(RoutePlan *)route;
- (void)countdown;
- (void)pause;
- (void)resume;
- (void)restore;
@end
