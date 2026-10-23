#pragma once
#include <stdbool.h>
#include <stddef.h>
typedef struct { double lat, lon; } RLPoint;
typedef struct {
    const RLPoint *points;
    size_t count;
    double length;
    double meters;
    double seconds;
    bool closed;
} RLPlan;
double RLDistance(RLPoint a, RLPoint b);
bool RLMakePlan(const RLPoint *points, size_t count, double meters, double seconds, RLPlan *out);
RLPoint RLPointAt(const RLPlan *plan, double distance);
RLPoint RLMapToWGS(RLPoint p, bool chinaCorrection);
RLPoint RLWGSToMap(RLPoint p, bool chinaCorrection);
