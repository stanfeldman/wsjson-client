#import "SRWebSocket.h"

typedef void (^WsJsonCallback)(NSDictionary* data);
typedef void (^WSJsonErrback)(NSString* message);

@interface WsJsonClient : NSObject<SRWebSocketDelegate>

+ (WsJsonClient*) sharedInstance;
- (void) connectToHost:(NSString*)host port:(int)port username:(NSString*)username0 password:(NSString*)password0 timeout:(NSTimeInterval)timeout0;
- (void) request:(NSString*)url callback:(WsJsonCallback)callback errback:(WSJsonErrback)errback;
- (void) request:(NSString*)url params:(NSDictionary*)params callback:(WsJsonCallback)callback errback:(WSJsonErrback)errback;

@end
