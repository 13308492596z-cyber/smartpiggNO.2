#include "../Sources/RouteMath.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
int main(void) {
    RLPoint loop[]={{0,0},{0,.001},{.001,.001},{.001,0},{0,0}};
    RLPlan p;
    assert(RLMakePlan(loop,5,1100,330,&p));
    assert(p.closed && p.length>440 && p.length<450);
    RLPoint start=RLPointAt(&p,0), repeat=RLPointAt(&p,p.length);
    assert(RLDistance(start,repeat)<.001);
    for(double d=1;d<=1100;d+=1)assert(RLDistance(RLPointAt(&p,d-1),RLPointAt(&p,d))<1.01);
    assert(!RLMakePlan(loop,4,1100,330,&p));
    assert(!RLMakePlan(loop,5,NAN,330,&p));
    assert(!RLMakePlan(loop,5,1000,0,&p));
    RLPoint invalid[]={{91,0},{0,1}};assert(!RLMakePlan(invalid,2,1,10,&p));
    RLPoint dateline[]={{0,179.999},{0,-179.999}};assert(RLMakePlan(dateline,2,200,60,&p));
    RLPoint mid=RLPointAt(&p,p.length/2);assert(fabs(fabs(mid.lon)-180)<.00001);
    RLPoint china={30,110}, displayed=RLWGSToMap(china,true), restored=RLMapToWGS(displayed,true);
    assert(RLDistance(china,restored)<.01);
    RLPoint elsewhere={0,0};assert(RLDistance(elsewhere,RLWGSToMap(elsewhere,true))==0);
    puts("Route math checks passed");return 0;
}
