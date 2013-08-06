//
//  UpdateManager.m
//
//  Created by Stephen L. McMahon on 8/4/13.
//

static NSString *const kPreferenceAskUpdate = @"pref_ask_update";

#import "UpdateManager.h"
#import "AFNetworking.h"
#import "UIAlertView+Blocks.h"
#import "RIButtonItem.h"

@implementation UpdateManager

+ (UpdateManager *)sharedManager {
    static UpdateManager *sharedManager = nil;
    if (!sharedManager)
    {
        sharedManager = [[super allocWithZone:nil] init];
    }
    return sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [self sharedManager];
}

// This will return the version by combining both the version and build fields in
// the iOS Application Target found in the summary section of the current build target
- (NSString *)appVersion {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [info objectForKey:@"CFBundleVersion"];
    if ([build isEqualToString:@""]) {
        return [NSString stringWithFormat:@"%@", version];
    } else {
        return [NSString stringWithFormat:@"%@.%@", version, build];
    }
}

- (BOOL)shouldAskForUpdate {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if ([prefs valueForKey:kPreferenceAskUpdate] == nil) {
        return YES;
    }
    return [prefs boolForKey:kPreferenceAskUpdate];
}

// this is exposed as a public method in case you would like to create another view, an App Update
// view perhaps, that explains that there is an update for the application and allow the user to
// manually update in case they opted NOT to when initially prompted.
- (void)disableAskUpdate {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:NO forKey:kPreferenceAskUpdate];
    [prefs synchronize];
}

- (void)performUpdate {
    // in case there's a network issue or some other type of failure, we go
    // ahead and reset the preference so that the user will be prompted again
    // to update on future sessions.
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:YES forKey:kPreferenceAskUpdate];
    NSURL *url = [NSURL URLWithString:_pListUrl];
    UIApplication *thisApp = [UIApplication sharedApplication];
    // turn off the badge
    [thisApp setApplicationIconBadgeNumber:0];
    // launch Mobile Safari, which will immediately attempt to install the application
    // from the URL that was specified.
    [thisApp openURL:url];
}

- (void)checkForUpdates {
    NSURL *url = [NSURL URLWithString:_versionUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSString *currentVersion = [self appVersion];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request
    success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON){
        UIApplication *thisApp = [UIApplication sharedApplication];
        // assumes that the server will be responding with a JSON object containing at least:
        // { CurrentVersion: "1.2.3.4" }
        NSString *serverVersion = [JSON valueForKeyPath:@"CurrentVersion"];
        if ([self compareVersion:serverVersion toVersion:currentVersion] <= 0) {
            // make sure that we don't have a badge showing since there are no updates.
            [thisApp setApplicationIconBadgeNumber:0];
            _currentServerVersion = currentVersion;
            NSLog(@"The application is up to date.");
            return;
        }
        // we have determined that there is an update.  We are going to ask the user if they would like to
        // update immediately, but they may choose not to, so we will set a badge here to remind them later
        // that there are pending updates.
        [thisApp setApplicationIconBadgeNumber:1];
        _currentServerVersion = serverVersion;
        
        // if we have previously asked the user if they wanted to update and they refused, then we don't
        // want to continue to bother them about it.
        if (![self shouldAskForUpdate]) {
            NSLog(@"There is a new version, but the user has opted to update manually later.");
            return;
        }
        
        // this action will be performed if the user selects "OK" in the upcoming alert view.  If the
        // user selects "OK" then we will attempt to perform the update.
        RIButtonItem *okButton = [RIButtonItem itemWithLabel:@"OK" action:^{
            [self performUpdate];
        }];
        
        // if the user cancels the update, then we will set a persistent preference value so that it
        // will not ask them on subsequent runs of the application.
        RIButtonItem *cancelButton = [RIButtonItem itemWithLabel:@"Cancel" action:^{
            [self disableAskUpdate];
        }];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Update Available"
                                                        message:@"A new version is available.  Update Now?"
                                               cancelButtonItem:cancelButton
                                               otherButtonItems:okButton, nil];
        [alert show];
    }
    failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        if (error) {
            NSLog(@"Update error: %@", [error localizedDescription]);
        }
        [self setCurrentServerVersion:currentVersion];
    }];
    [operation start];
}

// compares all of the bits in the version identifier starting from the left and 
// returns as soon as it finds a difference.  same = 0, l > r = 1, r > l = -1
- (int)compareVersion:(NSString *)firstVersion toVersion:(NSString *)secondVersion {
    NSMutableArray *fvArray = [self splitVersionString:firstVersion];
    NSMutableArray *svArray = [self splitVersionString:secondVersion];
    
    while ([fvArray count] < [svArray count]) {
        [fvArray addObject:[NSNumber numberWithInt:0]];
    }
    while ([svArray count] < [fvArray count]) {
        [svArray addObject:[NSNumber numberWithInt:0]];
    }
    
    for (int i = 0; i < [fvArray count]; i++) {
        int a = [[fvArray objectAtIndex:i] intValue];
        int b = [[svArray objectAtIndex:i] intValue];
        
        if (a > b) {
            return 1;
        }
        
        if (b > a) {
            return -1;
        }
    }
    return 0;
}

- (NSMutableArray *)splitVersionString:(NSString *)version {
    return [NSMutableArray arrayWithArray:[version componentsSeparatedByString:@"."]];
}
@end
