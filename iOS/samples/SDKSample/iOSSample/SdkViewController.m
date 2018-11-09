//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//

#import "SdkViewController.h"
#import "AppDataSource.h"
#import "AppServiceProvider.h"
#import "IdentityViewController.h"
#import "LaunchUriProvider.h"
#import "NotificationProvider.h"
#import <ConnectedDevices/Core/MCDPlatform.h>
#import <ConnectedDevices/Hosting/MCDRemoteSystemAppHostingRegistration.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@implementation SdkViewController : UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Wait to enable the buttons until platform is initialized
    [self.deviceRelayButton setEnabled:NO];
    [self.activityFeedButton setEnabled:NO];

    UIBarButtonItem* signOutButton =
        [[UIBarButtonItem alloc] initWithTitle:@"Sign Out" style:UIBarButtonItemStyleDone target:self action:@selector(_signOutClicked:)];
    self.navigationItem.rightBarButtonItem = signOutButton;

    [self initializePlatform];
}

- (void)initializePlatform
{
    // Only register for APNs if this app is enabled for push notifications
    NotificationProvider* notificationProvider;
    if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications])
    {
        notificationProvider = [AppDataSource sharedInstance].notificationProvider;
    }
    else
    {
        NSLog(@"Initializing platform without a notification provider!");
        notificationProvider = nil;
    }

    // Initialize platform
    [AppDataSource sharedInstance].platform = [MCDPlatform platformWithAccountProvider:[AppDataSource sharedInstance].accountProvider notificationProvider:notificationProvider];

    // App is registered asynchronously.
    MCDRemoteSystemAppHostingRegistration* registration = [MCDRemoteSystemAppHostingRegistration new];
    [registration setLaunchUriProvider:[[LaunchUriProvider alloc] initWithDelegate:[AppDataSource sharedInstance].inboundRequestLogger]];
    [registration addAppServiceProvider:[[AppServiceProvider alloc] initWithDelegate:[AppDataSource sharedInstance].inboundRequestLogger]];
    [registration addAttribute:@"ExampleAttribute" forName:@"ExampleName"];
    
    [registration.statusChanged subscribe:^(__unused MCDRemoteSystemAppHostingRegistration* reg, MCDRemoteSystemAppRegistrationStatusChangedEventArgs* args) {
        NSLog(@"Registration Status Changed listener");
        switch (args.status) {
            case MCDRemoteSystemAppRegistrationStatusFailed:
                NSLog(@"Registration completed with status Failed");
                break;
            case MCDRemoteSystemAppRegistrationStatusInProgress:
                NSLog(@"Registration in progress");
                break;
            case MCDRemoteSystemAppRegistrationStatusNotStarted:
                NSLog(@"Registration not started");
                break;
            case MCDRemoteSystemAppRegistrationStatusSucceeded:
                dispatch_async(dispatch_get_main_queue(), ^{
                    // The app has been registered.  It is safe to enable button.
                    [self.deviceRelayButton setEnabled:YES];
                    [self.activityFeedButton setEnabled:YES];
                });
                break;
        }
    }];
    
    [registration save];
}

- (void)_signOutClicked:(id)sender
{
    // Disable buttons when starting sign-out
    [self.deviceRelayButton setEnabled:NO];
    [self.activityFeedButton setEnabled:NO];

    if ([AppDataSource sharedInstance].accountProvider.signedIn)
    {
        [[AppDataSource sharedInstance].accountProvider
            signOutWithCompletionCallback:^(BOOL successful, SampleAccountActionFailureReason reason) {
                NSLog(@"%@", (successful ? @"Currently signed out" : @"Sign out failed"));
                dispatch_async(dispatch_get_main_queue(), ^{ [self dismissViewControllerAnimated:YES completion:nil]; });
            }];
    }
    else
    {
        // If we're somehow already signed out, just dismiss
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end