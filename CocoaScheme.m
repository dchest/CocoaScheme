#import <Foundation/Foundation.h>
#import "Scheme.h"

int main (int argc, const char *argv[]) 
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

  NSString *path = [[NSString stringWithUTF8String:argv[0]] stringByDeletingLastPathComponent];
  
  Scheme *sc = [Scheme sharedScheme];
  [sc loadFile:[[[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"test.scm"]];
  
  [pool drain];
  return 0;
}
