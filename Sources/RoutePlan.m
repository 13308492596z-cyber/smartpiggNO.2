#import "RoutePlan.h"
#include <math.h>
#import "LSMGPXParserDelegate.h"
@implementation RoutePlan {
    NSData *_storage;
}
- (instancetype)initWithPoints:(NSArray *)points meters:(double)meters seconds:(double)seconds {
    if(!(self=[super init])) return nil;
    if(points.count<2 || points.count>1000) return nil;
    NSMutableData *buffer=[NSMutableData dataWithLength:sizeof(RLPoint)*points.count];
    RLPoint *values=buffer.mutableBytes;
    for(NSUInteger i=0;i<points.count;i++) {
        id p=points[i];
        if(![p isKindOfClass:NSArray.class] || [p count]!=2 || ![p[0] isKindOfClass:NSNumber.class] || ![p[1] isKindOfClass:NSNumber.class]) return nil;
        values[i]=(RLPoint){[p[0] doubleValue],[p[1] doubleValue]};
    }
    _storage=buffer.copy;
    if(!RLMakePlan(_storage.bytes,points.count,meters,seconds,&_plan)) return nil;
    _points=[[NSArray alloc] initWithArray:points copyItems:YES];
    return self;
}
- (CLLocation *)locationAt:(double)elapsed {
    double d=_plan.meters*fmax(0,fmin(_plan.seconds,elapsed))/_plan.seconds;
    RLPoint p=RLPointAt(&_plan,d);
    return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(p.lat,p.lon) altitude:0 horizontalAccuracy:5 verticalAccuracy:5 timestamp:NSDate.date];
}
- (NSArray *)tracksFrom:(double)elapsed {
    NSMutableArray *tracks=NSMutableArray.array;
    NSTimeInterval epoch=NSDate.date.timeIntervalSince1970;
    double remaining=_plan.seconds-elapsed;
    NSUInteger samples=(NSUInteger)ceil(remaining);
    for(NSUInteger i=0;i<=samples;i++) {
        double t=fmin(i,remaining);
        RLPoint p=RLPointAt(&_plan,_plan.meters*(elapsed+t)/_plan.seconds);
        [tracks addObject:@{@"lat":@(p.lat).stringValue,@"lon":@(p.lon).stringValue,@"time":@(epoch+t).stringValue,@"ele":@"0"}];
    }
    return tracks;
}
- (NSDictionary *)scenarioFrom:(double)elapsed {
    LSMGPXParserDelegate *encoder=LSMGPXParserDelegate.new;
    encoder.tracks=[self tracksFrom:elapsed];
    encoder.hAccuracy=5;encoder.vAccuracy=5;
    encoder.lifeSpan=30;encoder.locationDeliveryBehavior=2;encoder.locationRepeatBehavior=0;
    return encoder.scenario;
}
- (NSData *)gpx {
    NSISO8601DateFormatter *formatter=NSISO8601DateFormatter.new;
    NSMutableString *xml=[NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx version=\"1.1\" creator=\"RouteLab\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><name>Route test</name><trkseg>"];
    for(NSDictionary *p in [self tracksFrom:0]) {
        NSString *time=[formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[p[@"time"] doubleValue]]];
        [xml appendFormat:@"<trkpt lat=\"%@\" lon=\"%@\"><time>%@</time></trkpt>",p[@"lat"],p[@"lon"],time];
    }
    [xml appendString:@"</trkseg></trk></gpx>"];
    return [xml dataUsingEncoding:NSUTF8StringEncoding];
}
@end
