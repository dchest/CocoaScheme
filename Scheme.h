//
//  Scheme.h
//  CocoaScheme
//
//  Created by Dmitry Chestnykh on 25.12.09.
//  Copyright 2009 Coding Robots. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "s7.h"

@interface Scheme : NSObject {
@public
  s7_scheme *scheme_;
}
@property(readonly, nonatomic) s7_scheme *scheme;
          
+ (Scheme *)sharedScheme;
- (void)loadFile:(NSString *)filename;
- (void)loadURL:(NSURL *)url;
- (void)evalString:(NSString *)string;

@end
