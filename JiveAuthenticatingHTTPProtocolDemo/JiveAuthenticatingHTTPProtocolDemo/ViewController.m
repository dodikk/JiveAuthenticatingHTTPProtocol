//
//  ViewController.m
//  JiveAuthenticatingHTTPProtocolDemo
//
//  Created by Heath Borders on 3/26/15.
//  Copyright (c) 2015 Jive Software. All rights reserved.
//

#import "ViewController.h"
#import <JiveAuthenticatingHTTPProtocol/JAHPAuthenticatingHTTPProtocol.h>

@interface ViewController ()
<
      JAHPAuthenticatingHTTPProtocolDelegate
    , UIAlertViewDelegate
    , UIWebViewDelegate
>

@property (nonatomic, weak  ) IBOutlet UIWebView*             webView;

@property (nonatomic, strong) UIAlertView*                    authAlertView;
@property (nonatomic, strong) JAHPAuthenticatingHTTPProtocol* authenticatingHTTPProtocol;

@property (nonatomic, strong) NSURLCredential* userInput;

@end

@implementation ViewController

#pragma mark - UIViewController

-(void)setupWebViewAuthHook
{
    [JAHPAuthenticatingHTTPProtocol setDelegate: self];
    [JAHPAuthenticatingHTTPProtocol start];
    self.webView.delegate = self;
}

-(void)loadTestPageThatRequiresAuth
{
    NSURL* url = [NSURL URLWithString: @"https://httpbin.org/basic-auth/foo/bar"];
    
    NSURLRequest* request = [[NSURLRequest alloc] initWithURL: url];
    [self.webView loadRequest: request];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupWebViewAuthHook];
    [self loadTestPageThatRequiresAuth];
}

#pragma mark - JAHPAuthenticatingHTTPProtocolDelegate

- (BOOL)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol
canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    NSArray* interceptedAuthMethods =
    @[
      NSURLAuthenticationMethodHTTPBasic
      , NSURLAuthenticationMethodNTLM
    ];
    
    NSSet* interceptedAuthMethodsSet = [NSSet setWithArray: interceptedAuthMethods];
    
    BOOL canAuthenticate =
        [interceptedAuthMethodsSet containsObject: protectionSpace.authenticationMethod];
    
    return canAuthenticate;
}


#define USE_PROTOCOL_FOR_CANCELLATION 0
#if USE_PROTOCOL_FOR_CANCELLATION
- (JAHPDidCancelAuthenticationChallengeHandler)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol
                                        didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    self.authenticatingHTTPProtocol = authenticatingHTTPProtocol;
    
    self.authAlertView =
    [[UIAlertView alloc] initWithTitle: @"JAHPDemo"
                               message: @"Enter 'foo' for the username and 'bar' for the password"
                              delegate: self
                     cancelButtonTitle: @"Cancel"
                     otherButtonTitles: @"OK", nil];
    
    self.authAlertView.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    [self.authAlertView show];
    
//    JAHPDidCancelAuthenticationChallengeHandler logCancelEvent =
//    ^void(JAHPAuthenticatingHTTPProtocol * __nonnull authenticatingHTTPProtocol,
//          NSURLAuthenticationChallenge   * __nonnull challenge)
//    {
//        NSLog(@"=== JAHPDidCancelAuthenticationChallengeHandler")
//    }
    //return logCancelEvent;
    
    return nil;
} // authenticatingHTTPProtocol:didReceiveAuthenticationChallenge:

- (void)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol
  didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.authAlertView dismissWithClickedButtonIndex: self.authAlertView.cancelButtonIndex
                                             animated: YES];
    self.authAlertView = nil;
    self.authenticatingHTTPProtocol = nil;
    
    [[[UIAlertView alloc] initWithTitle: @"JAHPDemo"
                                message: @"The URL Loading System cancelled authentication"
                               delegate: nil
                      cancelButtonTitle: @"OK"
                      otherButtonTitles: nil] show];
}
#else
- (JAHPDidCancelAuthenticationChallengeHandler)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol
                                        didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    self.authenticatingHTTPProtocol = authenticatingHTTPProtocol;
    
    //=== result handler
    //
    __weak ViewController* weakSelf = self;
    JAHPDidCancelAuthenticationChallengeHandler result =
    ^void(
          JAHPAuthenticatingHTTPProtocol* authenticatingHTTPProtocol,
          NSURLAuthenticationChallenge*   challenge)
    {
        [weakSelf handleAuthChallenge: challenge
                          forProtocol: authenticatingHTTPProtocol];
    };

    
    //=== try using the stored credentials
    //    to avoid entering them all over again
    //
    if (nil != self.userInput)
    {
        [self passCredentialsInputToConnection];
        return result;
    }
    
    
    //=== show alert for the first time
    //    if we have no credentials yet
    //
    self.authAlertView =
    [[UIAlertView alloc] initWithTitle: @"JAHPDemo"
                               message: @"Enter 'foo' for the username and 'bar' for the password"
                              delegate: self
                     cancelButtonTitle: @"Cancel"
                     otherButtonTitles: @"OK", nil];
    
    self.authAlertView.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    [self.authAlertView show];
    
    return result;
}


-(void)handleAuthChallenge:(NSURLAuthenticationChallenge*)challenge
               forProtocol:(JAHPAuthenticatingHTTPProtocol*)authenticatingHTTPProtocol
{
    // TODO: maybe fix leaking `self`
    NSInteger cancelButtonIndex = self.authAlertView.cancelButtonIndex;
    
    [self.authAlertView dismissWithClickedButtonIndex: cancelButtonIndex
                                             animated: YES];
    self.authAlertView = nil;
    self.authenticatingHTTPProtocol = nil;
    
    UIAlertView* alert =
    [[UIAlertView alloc] initWithTitle: @"JAHPDemo"
                               message: @"The URL Loading System cancelled authentication"
                              delegate: nil
                     cancelButtonTitle: @"OK"
                     otherButtonTitles: nil];
    
    [alert show];

}

#endif

- (void)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol
                     logWithFormat:(NSString *)format
                         arguments:(va_list)arguments
{
    NSString* formatted =
        [[NSString alloc] initWithFormat: format
                               arguments: arguments];
    
    NSLog(@"logWithFormat: %@", formatted);
}

- (void)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol
                        logMessage:(NSString *)message
{
    NSLog(@"logMessage: %@", message);
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex
{
    BOOL isCancel = (buttonIndex == self.authAlertView.cancelButtonIndex);
    BOOL isSubmit = (buttonIndex == self.authAlertView.firstOtherButtonIndex);
    
    
    if (isCancel)
    {
        [self cancelChallengeAfterAlertViewDismissal];
    }
    else if (isSubmit)
    {
        [self useAuthAlertViewUsernamePasswordForChallenge];
    }
}

- (void)alertViewCancel:(UIAlertView *)alertView
{
    [self cancelChallengeAfterAlertViewDismissal];
}

#pragma mark - UIWebViewDelegate

- (void)webView:(UIWebView *)webView
didFailLoadWithError:(NSError *)error
{
    UIAlertView* alert =
        [[UIAlertView alloc] initWithTitle: @"JAHPDemo"
                                   message: error.localizedDescription
                                  delegate: nil
                         cancelButtonTitle: @"OK"
                         otherButtonTitles: nil];
    
    [alert show];
}

#pragma mark - Private API

- (void)cancelChallengeAfterAlertViewDismissal
{
    [self.authenticatingHTTPProtocol cancelPendingAuthenticationChallenge];
    self.authenticatingHTTPProtocol = nil;
    self.authAlertView = nil;
}

- (void)useAuthAlertViewUsernamePasswordForChallenge
{
    NSParameterAssert(nil == self.userInput);
    
    NSString* username = [self.authAlertView textFieldAtIndex:0].text;
    NSString* password = [self.authAlertView textFieldAtIndex:1].text;
    
    self.authAlertView = nil;
    NSURLCredential* credential =
        [NSURLCredential credentialWithUser: username
                                   password: password
                                persistence: NSURLCredentialPersistenceNone];
    self.userInput = credential;
    
    [self passCredentialsInputToConnection];
}

-(void)passCredentialsInputToConnection
{
    NSParameterAssert(nil != self.userInput);
    NSParameterAssert(nil != self.authenticatingHTTPProtocol);
    
    [self.authenticatingHTTPProtocol resolvePendingAuthenticationChallengeWithCredential:self.userInput];
    self.authenticatingHTTPProtocol = nil;
}

@end
