#import "SRWebSocket.h"

typedef void (^WsJsonCallback)(NSDictionary* data);
typedef void (^WSJsonErrback)(NSString* message);

#define WSJSON_CONNECTED @"WSJSON_CONNECTED"
#define WSJSON_DISCONNECTED @"WSJSON_DISCONNECTED"
#define WSJSON_CONNECTION_ERROR @"WSJSON_CONNECTION_ERROR"

@interface WsJsonClient : NSObject<SRWebSocketDelegate>

+ (WsJsonClient*) sharedInstance;
- (void) connectToHost:(NSString*)host port:(int)port;
- (void) connectToHost:(NSString*)host port:(int)port username:(NSString*)username0 password:(NSString*)password0 timeout:(NSTimeInterval)timeout0 secure:(BOOL)secure cert:(NSString*)certName;
- (void) request:(NSString*)url callback:(WsJsonCallback)callback errback:(WSJsonErrback)errback;
- (void) request:(NSString*)url params:(NSDictionary*)params callback:(WsJsonCallback)callback errback:(WSJsonErrback)errback;

@end
