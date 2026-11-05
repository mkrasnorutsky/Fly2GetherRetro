// FlightJoy v2 wire encoder. See docs/PROTOCOL-V2.md; no native struct layout on wire.
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <math.h>
#define F2G_V2_PORT 4211
#define F2G_V2_AXES 32
#define F2G_V2_BUTTONS 128
#define F2G_V2_AXIS_PROPELLER 5
#define F2G_V2_AXIS_MIXTURE 6
static inline int16_t F2GUnitAxis(double value) {
    double unit = isfinite(value) ? fmax(0, fmin(1, value)) : 0;
    return (int16_t)(65534 * (unit - 0.5));
}
static inline void F2GWriteLE(uint8_t *p, uint64_t v, size_t n) {
    for (size_t i = 0; i < n; i++) p[i] = (uint8_t)(v >> (i * 8));
}
static inline size_t F2GEncodeV2(uint8_t *out, uint8_t type, uint64_t session,
                               uint32_t sequence, const int16_t *values, uint16_t count) {
    if (!out || (count && !values) || !session || type < 1 || type > 3 || (type == 3 && count) ||
        (type == 1 && count > F2G_V2_AXES) || (type == 2 && count > F2G_V2_BUTTONS)) return 0;
    if (type == 2) for (uint16_t i=0; i<count; i++) if (values[i] != 0 && values[i] != 1) return 0;
    out[0]='F'; out[1]='J'; out[2]='O'; out[3]='Y'; out[4]=2; out[5]=type;
    F2GWriteLE(out+6, count*4, 2); F2GWriteLE(out+8, session, 8); F2GWriteLE(out+16, sequence, 4);
    for (uint16_t i=0; i<count; i++) {
        F2GWriteLE(out+20+i*4, i, 2); F2GWriteLE(out+22+i*4, (uint16_t)values[i], 2);
    }
    return 20+count*4;
}

// Only a complete, valid v2 claim may transfer control between phones.
static inline int F2GIsV2Claim(const uint8_t *bytes, size_t count) {
    if (!bytes || count != 20 || bytes[0]!='F' || bytes[1]!='J' || bytes[2]!='O' || bytes[3]!='Y' ||
        bytes[4]!=2 || bytes[5]!=3 || bytes[6]!=0 || bytes[7]!=0) return 0;
    uint8_t session = 0;
    for (size_t i=8; i<16; i++) session |= bytes[i];
    return session != 0;
}
