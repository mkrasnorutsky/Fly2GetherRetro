#import "RetroInput.h"
#import "F2GProtocolV2.h"
#import <arpa/inet.h>
#import <errno.h>
#import <fcntl.h>
#import <math.h>
#import <unistd.h>

enum { AxisCount = 32, ButtonCount = 128, ReportSize = 80 };
static const NSTimeInterval InputTimeout = 2;

static uint64_t ReadLE(const uint8_t *bytes, size_t count) {
    uint64_t result = 0;
    for (size_t i = 0; i < count; i++) result |= (uint64_t)bytes[i] << (8 * i);
    return result;
}

static NSError *SocketError(int code, uint16_t port) {
    NSString *message = [NSString stringWithFormat:@"Unable to get ready (UDP %u): %s", port, strerror(code)];
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation RetroInput {
    int _socket;
    uint16_t _port;
    NSString *_owner;
    uint64_t _session;
    uint32_t _sequences[3];
    BOOL _seenSequence[3];
    NSTimeInterval _lastReceived, _lastAxes, _lastButtons;
    int16_t _axes[AxisCount];
    uint8_t _buttons[ButtonCount / 8];
    NSMutableOrderedSet<NSString *> *_retired;
}

- (instancetype)initWithPort:(uint16_t)port error:(NSError **)error {
    self = [super init];
    if (!self) return nil;

    _port = port;
    _socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    struct sockaddr_in address = {
        .sin_len = sizeof(address), .sin_family = AF_INET, .sin_port = htons(port)
    };
    if (_socket < 0 ||
        bind(_socket, (const struct sockaddr *)&address, sizeof(address)) < 0 ||
        fcntl(_socket, F_SETFL, O_NONBLOCK) < 0) {
        if (error) *error = SocketError(errno, port);
        return nil;
    }
    _retired = [NSMutableOrderedSet orderedSet];
    [self reset];
    return self;
}

- (void)dealloc {
    if (_socket >= 0) close(_socket);
}

- (NSString *)owner { return _owner; }

- (void)resetAxes {
    memset(_axes, 0, sizeof(_axes));
    _axes[3] = INT16_MIN;
}

- (void)reset {
    [self resetAxes];
    memset(_buttons, 0, sizeof(_buttons));
    memset(_seenSequence, 0, sizeof(_seenSequence));
    _owner = nil;
    _session = 0;
    _lastAxes = _lastButtons = -INFINITY;
}

- (void)expireAtTime:(NSTimeInterval)now {
    if (_owner && now - _lastReceived >= InputTimeout) {
        [self reset];
        return;
    }
    if (now - _lastAxes >= InputTimeout) [self resetAxes];
    if (now - _lastButtons >= InputTimeout) memset(_buttons, 0, sizeof(_buttons));
}

- (void)receive:(const uint8_t *)bytes length:(size_t)length
           host:(NSString *)host time:(NSTimeInterval)now {
    if (length < 20 || length > 532 || memcmp(bytes, "FJOY", 4) || bytes[4] != 2) return;
    uint8_t type = bytes[5];
    if (type < 1 || type > 3) return;

    size_t limit = type == 1 ? AxisCount : type == 2 ? ButtonCount : 0;
    size_t payload = length - 20;
    uint64_t session = ReadLE(bytes + 8, 8);
    if (!session || ReadLE(bytes + 6, 2) != payload || payload % 4 || payload / 4 > limit) return;

    int16_t values[ButtonCount] = {0};
    BOOL seen[ButtonCount] = {0};
    for (size_t offset = 20; offset < length; offset += 4) {
        size_t index = ReadLE(bytes + offset, 2);
        int16_t value = (int16_t)ReadLE(bytes + offset + 2, 2);
        if (index >= limit || seen[index] || (type == 2 && value != 0 && value != 1)) return;
        seen[index] = YES;
        values[index] = value;
    }

    [self expireAtTime:now];
    NSString *identity = [NSString stringWithFormat:@"%@/%llu", host, (unsigned long long)session];
    if ([_retired containsObject:identity]) return;
    BOOL sameOwner = [_owner isEqualToString:host] && _session == session;

    if (type == 3) {
        if (sameOwner) return;
        if (_owner) {
            [_retired addObject:[NSString stringWithFormat:@"%@/%llu", _owner, (unsigned long long)_session]];
            if (_retired.count > 64) [_retired removeObjectAtIndex:0];
        }
        [self reset];
    } else {
        if (_owner && !sameOwner) return;
        uint32_t sequence = (uint32_t)ReadLE(bytes + 16, 4);
        uint32_t difference = sequence - _sequences[type];
        if (_seenSequence[type] && (difference == 0 || difference >= 0x80000000u)) return;
        _seenSequence[type] = YES;
        _sequences[type] = sequence;
        if (type == 1) {
            memcpy(_axes, values, sizeof(_axes));
            _lastAxes = now;
        } else {
            memset(_buttons, 0, sizeof(_buttons));
            for (size_t i = 0; i < ButtonCount; i++) {
                if (values[i]) _buttons[i / 8] |= 1u << (i % 8);
            }
            _lastButtons = now;
        }
    }
    _owner = host;
    _session = session;
    _lastReceived = now;
}

- (BOOL)pollAtTime:(NSTimeInterval)now error:(NSError **)error {
    for (NSUInteger i = 0; i < 256; i++) {
        uint8_t bytes[2048];
        struct sockaddr_in address;
        socklen_t length = sizeof(address);
        ssize_t count = recvfrom(_socket, bytes, sizeof(bytes), 0, (struct sockaddr *)&address, &length);
        if (count < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            if (errno == EINTR) continue;
            if (error) *error = SocketError(errno, _port);
            return NO;
        }
        char host[INET_ADDRSTRLEN];
        if (inet_ntop(AF_INET, &address.sin_addr, host, sizeof(host))) {
            [self receive:bytes length:(size_t)count host:@(host) time:now];
        }
    }
    [self expireAtTime:now];
    return YES;
}

- (BOOL)hasActiveInputAtTime:(NSTimeInterval)now {
    return _owner && (now - _lastAxes < InputTimeout || now - _lastButtons < InputTimeout);
}

- (int16_t)axisAtIndex:(NSUInteger)index { return _axes[index]; }
- (BOOL)buttonAtIndex:(NSUInteger)index { return (_buttons[index / 8] & (1u << (index % 8))) != 0; }

- (NSData *)report {
    uint8_t bytes[ReportSize];
    for (size_t i = 0; i < AxisCount; i++) F2GWriteLE(bytes + 2 * i, (uint16_t)_axes[i], 2);
    memcpy(bytes + 2 * AxisCount, _buttons, sizeof(_buttons));
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSData *)safeReport {
    uint8_t bytes[ReportSize] = {[7] = 0x80};
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSData *)descriptor {
    const uint8_t prefix[] = {0x05,0x01,0x09,0x04,0xa1,0x01};
    const uint8_t usages[] = {0x30,0x31,0x35,0x32,0x36,0x33,0x34,0x37};
    const uint8_t suffix[] = {0x16,0x00,0x80,0x26,0xff,0x7f,0x75,0x10,0x95,0x20,0x81,0x02,
        0x05,0x09,0x19,0x01,0x29,0x80,0x15,0x00,0x25,0x01,0x75,0x01,0x95,0x80,0x81,0x02,0xc0};
    NSMutableData *descriptor = [NSMutableData dataWithBytes:prefix length:sizeof(prefix)];
    for (size_t i = 0; i < AxisCount; i++) {
        const uint8_t usage[] = {0x09, i < sizeof(usages) ? usages[i] : 0x36};
        [descriptor appendBytes:usage length:sizeof(usage)];
    }
    [descriptor appendBytes:suffix length:sizeof(suffix)];
    return descriptor;
}
@end
