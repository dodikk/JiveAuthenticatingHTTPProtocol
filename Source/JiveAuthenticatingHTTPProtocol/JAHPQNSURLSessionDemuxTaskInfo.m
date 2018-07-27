//
//  JAHPQNSURLSessionDemuxTaskInfo.m
//  JiveAuthenticatingHTTPProtocol
//
//  Created by Alexander Dodatko on 7/27/18.
//

#import "JAHPQNSURLSessionDemuxTaskInfo.h"

@interface JAHPQNSURLSessionDemuxTaskInfo ()

@property (atomic, strong, readwrite) id<NSURLSessionDataDelegate>  delegate;
@property (atomic, strong, readwrite) NSThread *                    thread;

@end

@implementation JAHPQNSURLSessionDemuxTaskInfo

- (instancetype)initWithTask:(NSURLSessionDataTask *)task
                    delegate:(id<NSURLSessionDataDelegate>)delegate
                       modes:(NSArray *)modes
{
    NSParameterAssert(task     != nil);
    NSParameterAssert(delegate != nil);
    NSParameterAssert(modes    != nil);
    
    self = [super init];
    
    if (nil == self)
    {
        return nil;
    }
    
    self->_task     = task;
    self->_delegate = delegate;
    self->_thread   = [NSThread currentThread];
    self->_modes    = [modes copy];
    
    return self;
}

- (void)performBlock:(dispatch_block_t)block
{
    NSParameterAssert(self.delegate != nil);
    NSParameterAssert(self.thread   != nil);
    
    [self performSelector: @selector(performBlockOnClientThread:)
                 onThread: self.thread
               withObject: [block copy]
            waitUntilDone: NO
                    modes: self.modes];
}

- (void)performBlockOnClientThread:(dispatch_block_t)block
{
    NSParameterAssert([NSThread currentThread] == self.thread);
    block();
}

- (void)invalidate
{
    self.delegate = nil;
    self.thread   = nil;
}

@end
