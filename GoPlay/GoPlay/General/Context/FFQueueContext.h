//
//  FFQueueContext.h
//  GoPlay
//
//  Created by dKingbin on 2018/12/27.
//  Copyright © 2018 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>

void runSync(void (^block)(void));
void runAsync(void (^block)(void));
void runSyncOnMainQueue(void (^block)(void));

@interface FFQueueContext : NSObject
+(instancetype)shareInstance;
-(dispatch_queue_t)sharedContextQueue;
@end
