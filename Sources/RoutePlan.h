#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "RouteMath.h"
@interface RoutePlan : NSObject
@property(nonatomic,readonly) RLPlan plan;
@property(nonatomic,readonly) NSArray<NSArray<NSNumber *> *> *points;
- (instancetype)initWithPoints:(NSArray *)points meters:(double)meters seconds:(double)seconds;
- (CLLocation *)locationAt:(double)elapsed;
- (NSDictionary *)scenarioFrom:(double)elapsed;
- (NSData *)gpx;
@end
