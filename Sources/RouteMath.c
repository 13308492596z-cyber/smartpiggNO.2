#include "RouteMath.h"
#include <math.h>
#define PI 3.14159265358979323846
static double radians(double x) { return x * PI / 180.0; }
static double delta(double x) { return x - 360.0 * floor((x + 180.0) / 360.0); }
double RLDistance(RLPoint a, RLPoint b) {
    double dlat = radians(b.lat-a.lat), dlon = radians(delta(b.lon-a.lon));
    double s = sin(dlat/2)*sin(dlat/2) + cos(radians(a.lat))*cos(radians(b.lat))*sin(dlon/2)*sin(dlon/2);
    return 12742017.6 * asin(sqrt(fmax(0, fmin(1, s))));
}
bool RLMakePlan(const RLPoint *points, size_t count, double meters, double seconds, RLPlan *out) {
    if (!points || !out || count<2 || count>1000 || !isfinite(meters) || !isfinite(seconds) || meters<1 || meters>10000 || seconds<1.2 || seconds>3600) return false;
    double length=0;
    for (size_t i=0;i<count;i++) {
        if (!isfinite(points[i].lat) || !isfinite(points[i].lon) || fabs(points[i].lat)>90 || fabs(points[i].lon)>180) return false;
        if (i) length+=RLDistance(points[i-1],points[i]);
    }
    if (length<=1) return false;
    bool closed=RLDistance(points[0],points[count-1])<=0.001;
    if (meters>length+0.001 && !closed) return false;
    *out=(RLPlan){points,count,length,meters,seconds,closed};
    return true;
}
RLPoint RLPointAt(const RLPlan *plan, double distance) {
    double d=fmax(0,fmin(plan->meters,distance));
    d=plan->closed ? fmod(d,plan->length) : fmin(d,plan->length);
    for (size_t i=1;i<plan->count;i++) {
        double length=RLDistance(plan->points[i-1],plan->points[i]);
        if (length<0.000001) continue;
        if (d<=length || i==plan->count-1) {
            double t=fmax(0,fmin(1,d/length));
            RLPoint a=plan->points[i-1],b=plan->points[i];
            return (RLPoint){a.lat+(b.lat-a.lat)*t,delta(a.lon+delta(b.lon-a.lon)*t)};
        }
        d-=length;
    }
    return plan->points[plan->count-1];
}
// GCJ-02 correction is optional and applies only inside the usual mainland bounds.
static bool inChina(RLPoint p) {return p.lon>=72.004 && p.lon<=137.8347 && p.lat>=0.8293 && p.lat<=55.8271;}
static double latOffset(double x,double y) {
    double z=-100+2*x+3*y+.2*y*y+.1*x*y+.2*sqrt(fabs(x));
    z+=(20*sin(6*x*PI)+20*sin(2*x*PI))*2/3;
    z+=(20*sin(y*PI)+40*sin(y/3*PI))*2/3;
    return z+(160*sin(y/12*PI)+320*sin(y*PI/30))*2/3;
}
static double lonOffset(double x,double y) {
    double z=300+x+2*y+.1*x*x+.1*x*y+.1*sqrt(fabs(x));
    z+=(20*sin(6*x*PI)+20*sin(2*x*PI))*2/3;
    z+=(20*sin(x*PI)+40*sin(x/3*PI))*2/3;
    return z+(150*sin(x/12*PI)+300*sin(x/30*PI))*2/3;
}
RLPoint RLWGSToMap(RLPoint p,bool correction) {
    if (!correction || !inChina(p)) return p;
    double r=radians(p.lat), s=sin(r), magic=1-.00669342162296594323*s*s, sq=sqrt(magic);
    double a=latOffset(p.lon-105,p.lat-35)*180/((6378245*(1-.00669342162296594323))/(magic*sq)*PI);
    double b=lonOffset(p.lon-105,p.lat-35)*180/(6378245/sq*cos(r)*PI);
    return (RLPoint){p.lat+a,p.lon+b};
}
RLPoint RLMapToWGS(RLPoint p,bool correction) {
    if (!correction || !inChina(p)) return p;
    RLPoint guess=p;
    for(int i=0;i<5;i++){RLPoint m=RLWGSToMap(guess,true);guess.lat-=m.lat-p.lat;guess.lon-=m.lon-p.lon;}
    return guess;
}
