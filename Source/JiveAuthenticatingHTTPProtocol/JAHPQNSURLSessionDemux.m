/*
 File: JAHPQNSURLSessionDemux.m
 Abstract: A general class to demux NSURLSession delegate callbacks.
 Version: 1.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */

#import "JAHPQNSURLSessionDemux.h"
#import "JAHPQNSURLSessionDemuxTaskInfo.h"

@interface JAHPQNSURLSessionDemux () <NSURLSessionDataDelegate>

// keys NSURLSessionTask taskIdentifier, values are SessionManager
@property (atomic, strong, readonly ) NSMutableDictionary* taskInfoByTaskID;
@property (atomic, strong, readonly ) NSOperationQueue*    sessionDelegateQueue;

@end

@implementation JAHPQNSURLSessionDemux

- (instancetype)init
{
    return [self initWithConfiguration:nil];
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration
{
    // configuration may be nil
    self = [super init];
    
    if (self == nil)
    {
        return nil;
    }
        
    if (configuration == nil)
    {
        configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    self->_configuration = [configuration copy];
    
    self->_taskInfoByTaskID = [[NSMutableDictionary alloc] init];
    
    self->_sessionDelegateQueue = [[NSOperationQueue alloc] init];
    [self->_sessionDelegateQueue setMaxConcurrentOperationCount:1];
    [self->_sessionDelegateQueue setName:@"JAHPQNSURLSessionDemux"];
    
    self->_session =
        [NSURLSession sessionWithConfiguration:self->_configuration
                                      delegate:self
                                 delegateQueue:self->_sessionDelegateQueue];
    
    self->_session.sessionDescription = @"JAHPQNSURLSessionDemux";

    
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                                     delegate:(id<NSURLSessionDataDelegate>)delegate
                                        modes:(NSArray *)modes
{
    NSURLSessionDataTask*           task    ;
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo;
    
    NSParameterAssert(request != nil);
    NSParameterAssert(delegate != nil);
    // modes may be nil
    
    if ([modes count] == 0)
    {
        modes = @[ NSDefaultRunLoopMode ];
    }
    
    task = [self.session dataTaskWithRequest:request];
    NSParameterAssert(task != nil);
    
    taskInfo =
    [[JAHPQNSURLSessionDemuxTaskInfo alloc] initWithTask: task
                                                delegate: delegate
                                                   modes: modes];
    
    @synchronized (self)
    {
        self.taskInfoByTaskID[@(task.taskIdentifier)] = taskInfo;
    }
    
    return task;
}

- (JAHPQNSURLSessionDemuxTaskInfo *)taskInfoForTask:(NSURLSessionTask *)task
{
    JAHPQNSURLSessionDemuxTaskInfo* result;
    
    NSParameterAssert(task != nil);
    
    @synchronized (self)
    {
        result = self.taskInfoByTaskID[@(task.taskIdentifier)];
        NSParameterAssert(result != nil);
    }
    
    return result;
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)newRequest
 completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = nil;
    
    taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector: _cmd])
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession:session
                                     task:task
               willPerformHTTPRedirection:response
                               newRequest:newRequest
                        completionHandler:completionHandler];
        }];
    }
    else
    {
        completionHandler(newRequest);
    }
}


typedef void (^JAHUrlSessionChallengeHandler)(
    NSURLSessionAuthChallengeDisposition disposition,
    NSURLCredential *credential);


- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(JAHUrlSessionChallengeHandler)completionHandler
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = [self taskInfoForTask:task];
    
    if ([taskInfo.delegate respondsToSelector: _cmd])
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession:session
                                     task:task
                      didReceiveChallenge:challenge
                        completionHandler:completionHandler];
        }];
    }
    else
    {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

typedef void (^JAHUrlSessionBodyStreamHandler)(NSInputStream *bodyStream);

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
 needNewBodyStream:(JAHUrlSessionBodyStreamHandler)completionHandler
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector: _cmd])
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession: session
                                     task: task
                        needNewBodyStream: completionHandler];
        }];
    } else
    {
        completionHandler(nil);
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = [self taskInfoForTask:task];
    
    if ([taskInfo.delegate respondsToSelector: _cmd])
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession: session
                                     task: task
                          didSendBodyData: bytesSent
                           totalBytesSent: totalBytesSent
                 totalBytesExpectedToSend: totalBytesExpectedToSend];
        }];
    }
}

- (void)  URLSession:(NSURLSession *)session
                task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = [self taskInfoForTask:task];
    
    // This is our last delegate callback so we remove our task info record.
    
    @synchronized (self)
    {
        [self.taskInfoByTaskID removeObjectForKey:@(taskInfo.task.taskIdentifier)];
    }
    
    // Call the delegate if required.  In that case we invalidate the task info on the client thread
    // after calling the delegate, otherwise the client thread side of the -performBlock: code can
    // find itself with an invalidated task info.
    
    if ([taskInfo.delegate respondsToSelector: _cmd])
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession:session
                                     task:task
                     didCompleteWithError:error];
            
            [taskInfo invalidate];
        }];
    }
    else
    {
        [taskInfo invalidate];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = [self taskInfoForTask:dataTask];
    
    BOOL canPropagateDelegateCall =
        [taskInfo.delegate respondsToSelector: _cmd];
    
    if (canPropagateDelegateCall)
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession: session
                                 dataTask: dataTask
                       didReceiveResponse: response
                        completionHandler: completionHandler];
        }];
    }
    else
    {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = [self taskInfoForTask:dataTask];
    
    BOOL canPropagateDelegateCall =
        [taskInfo.delegate respondsToSelector: _cmd];
    
    if (canPropagateDelegateCall)
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession: session
                                 dataTask: dataTask
                    didBecomeDownloadTask: downloadTask];
        }];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = [self taskInfoForTask:dataTask];
    
    BOOL canPropagateDelegateCall =
    [taskInfo.delegate respondsToSelector: _cmd];
    
    if (canPropagateDelegateCall)
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession: session
                                 dataTask: dataTask
                           didReceiveData: data];
        }];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler
{
    JAHPQNSURLSessionDemuxTaskInfo* taskInfo = nil;
    
    taskInfo = [self taskInfoForTask:dataTask];
 
    BOOL canPropagateDelegateCall =
        ([taskInfo.delegate respondsToSelector: _cmd]);
    
    if (canPropagateDelegateCall)
    {
        [taskInfo performBlock:^void()
        {
            [taskInfo.delegate URLSession: session
                                 dataTask: dataTask
                        willCacheResponse: proposedResponse
                        completionHandler: completionHandler];
        }];
    }
    else
    {
        completionHandler(proposedResponse);
    }
}

@end

