#import "WsJsonClient.h"

@implementation WsJsonClient {
    SRWebSocket* socket;
    BOOL connected;
    NSString* serverUrl;
    NSMutableArray* requestsQueue;
    NSMutableDictionary* callbacks;
    NSMutableDictionary* errbacks;
    NSString* username;
    NSString* password;
    NSTimeInterval timeout;
    NSTimer* timeoutTimer;
    NSString* cert;
}

+ (WsJsonClient*) sharedInstance {
    static dispatch_once_t pred;
    static WsJsonClient* instance = nil;
    
    dispatch_once(&pred, ^{
        instance = [self new];
    });
    return instance;
}

- (void) connectToHost:(NSString*)host port:(int)port {
    [self connectToHost:host port:port username:nil password:nil timeout:3 secure:NO cert:nil];
}

// cert is der certificate name in project
- (void) connectToHost:(NSString*)host port:(int)port username:(NSString*)username0 password:(NSString*)password0 timeout:(NSTimeInterval)timeout0 secure:(BOOL)secure cert:(NSString*)certName {
    NSString* pathPattern = @"ws://%@:%i";
    if(secure)
        pathPattern = @"wss://%@:%i";
    serverUrl = [NSString stringWithFormat:pathPattern, host, port];
    username = username0;
    password = password0;
    timeout = timeout0;
    cert = certName;
    [self reconnect];
}

- (void) request:(NSString*)url callback:(WsJsonCallback)callback errback:(WSJsonErrback)errback {
    [self request:url params:nil callback:callback errback:errback];
}

- (void) request:(NSString*)url params:(NSDictionary*)params callback:(WsJsonCallback)callback errback:(WSJsonErrback)errback {
    NSMutableDictionary* result = nil;
    if(params)
        result = [params mutableCopy];
    else
        result = [NSMutableDictionary new];
    [result setValue:url forKey:@"url"];
    if(username && password)
        [result setValue:@{@"username":username, @"password": password} forKey:@"auth"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    if (!jsonData) {
        if(errback)
            errback(nil);
        return;
    }
    if(callback)
        [callbacks setValue:callback forKey:url];
    if(errback)
        [errbacks setValue:errback forKey:url];
    NSString* request = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if(connected)
        [socket send:request];
    else
        [requestsQueue addObject:request];
}

# pragma mark delegate methods
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    NSString* url = [json valueForKey:@"url"];
    NSNumber* success = [json valueForKey:@"success"];
    if(![success isEqualToNumber:@YES]) {
        NSString* errorMsg = [json valueForKey:@"error"];
        WSJsonErrback errback = [errbacks valueForKey:url];
        if(errback) {
            errback(errorMsg);
            [callbacks removeObjectForKey:url];
            [errbacks removeObjectForKey:url];
        }
        // нужно ли посылать уведомление об ошибке?
    }
    else {
        WsJsonCallback callback = [callbacks valueForKey:url];
        if(callback) {
            callback(json);
            [callbacks removeObjectForKey:url];
            [errbacks removeObjectForKey:url];
        }
        else
            [[NSNotificationCenter defaultCenter] postNotificationName:url object:json];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"error %@", error.userInfo);
    [self cancelTimeoutTimer];
    connected = NO;
    [self onError];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"connected");
    [self cancelTimeoutTimer];
    connected = YES;
    [self resendQueue];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"disconnected %i %@", code, reason);
    connected = NO;
    [self onError];
}

- (void) didTimeout {
    [self cancelTimeoutTimer];
    [self webSocket:socket didFailWithError:[NSError errorWithDomain:@"ru.limehat.ios.intelsound" code:5 userInfo:@{NSLocalizedDescriptionKey:@"connection timed out"}]];
}

- (void) cancelTimeoutTimer {
    [timeoutTimer invalidate];
    timeoutTimer = nil;
}

- (void) resendQueue {
    if(!connected)
        return;
    for(NSString* request in requestsQueue)
        [socket send:request];
    [requestsQueue removeAllObjects];
}

- (void) onError {
    [self cancelTimeoutTimer];
    for(WSJsonErrback errback in errbacks.allValues) {
        if(errback)
            errback(nil);
    }
    [errbacks removeAllObjects];
    // как только пропало соединение пытаемся его восстановить
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self reconnect];
    });
}

- (void) reconnect {
    socket.delegate = nil;
    [socket close];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:serverUrl]];
    if(cert) {
        NSData* certData = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:cert ofType:@"der"]];
        SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
        request.SR_SSLPinnedCertificates = @[(__bridge id)certificate];
    }
    socket = [[SRWebSocket alloc] initWithURLRequest:request];
    socket.delegate = self;
    NSDate* futureDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    timeoutTimer = [[NSTimer alloc] initWithFireDate:futureDate interval:0 target:self selector:@selector(didTimeout) userInfo:nil repeats:NO];
    [[NSRunLoop SR_networkRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
    [socket open];
}

#pragma mark private methods
- (id) init {
    self = [super init];
    if(self){
        requestsQueue = [NSMutableArray new];
        callbacks = [NSMutableDictionary new];
        errbacks = [NSMutableDictionary new];
    }
    return self;
}

@end
