//
//  UpdateManager.h
//
//  Created by Stephen L. McMahon on 8/4/13.
//

#import <Foundation/Foundation.h>

@interface UpdateManager : NSObject
@property (nonatomic, copy) NSString *pListUrl;
@property (nonatomic, copy) NSString *versionUrl;
@property (nonatomic, copy) NSString *currentServerVersion;

+ (UpdateManager *)sharedManager;
- (void)checkForUpdates;
- (void)performUpdate;
@end
