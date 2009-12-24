//
//  Scheme.m
//  CocoaScheme
//
//  Created by Dmitry Chestnykh on 25.12.09.
//  Copyright 2009 Coding Robots. All rights reserved.
//

#import "Scheme.h"

static Scheme *sharedScheme;

@implementation Scheme

+ (Scheme *)sharedScheme
{
  @synchronized(self) {
    if (sharedScheme == nil)
      sharedScheme = [[Scheme alloc] init];
  }
  return sharedScheme;
}

- (id)init
{
  if (![super init])
    return nil;
  scheme_ = s7_init();
  return self;
}

- (void)finalize
{
  s7_quit(scheme_);
}

- (void)loadFile:(NSString *)filename
{
  s7_load(scheme_, [filename fileSystemRepresentation]);
}

- (void)loadURL:(NSURL *)url
{
  [self loadFile:[url path]];
}

- (void)evalString:(NSString *)string
{
  s7_eval_c_string(scheme_, [string UTF8String]);
}


@end
