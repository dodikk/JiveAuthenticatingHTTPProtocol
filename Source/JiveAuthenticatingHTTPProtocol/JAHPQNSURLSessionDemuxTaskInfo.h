//
//  JAHPQNSURLSessionDemuxTaskInfo.h
//  JiveAuthenticatingHTTPProtocol
//
//  Created by Alexander Dodatko on 7/27/18.
//

#import <Foundation/Foundation.h>

@interface JAHPQNSURLSessionDemuxTaskInfo : NSObject

- (instancetype)initWithTask:(NSURLSessionDataTask *)task
                    delegate:(id<NSURLSessionDataDelegate>)delegate
                       modes:(NSArray *)modes;

@property (atomic, strong, readonly ) NSURLSessionDataTask *        task;
@property (atomic, strong, readonly ) id<NSURLSessionDataDelegate>  delegate;
@property (atomic, strong, readonly ) NSThread *                    thread;
@property (atomic, copy,   readonly ) NSArray *                     modes;

- (void)performBlock:(dispatch_block_t)block;

- (void)invalidate;

@end

