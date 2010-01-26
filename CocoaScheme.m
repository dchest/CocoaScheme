#import <Foundation/Foundation.h>
#import "Scheme.h"

/*
 
  Usage:
    CocoaScheme [filename]
 
  if no filename, launches REPL

*/

int main (int argc, const char *argv[]) 
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  Scheme *sc = [Scheme sharedScheme];

  if (argc > 1) {
    // run file
    [sc loadFile:[NSString stringWithUTF8String:argv[1]]];
  } else {
    // mini REPL
    printf("CocoaScheme. Press Ctrl-C to exit.");
    // prepare some helpers
    [sc evalString:@"(defmacro class (name)"
                    " `(string->objc:class (symbol->string ',name)))"];
    
    char buffer[512];
    char response[1024];
    while (1)                           /* fire up a REPL */
    {
      fprintf(stdout, "\n> ");        /* prompt for input */
      fgets(buffer, 512, stdin);
      if (feof(stdin))
        return 0;
      if ((buffer[0] != '\n') || 
          (strlen(buffer) > 1))
      {
        sprintf(response, "(write %s)", buffer);
        [sc evalString:[NSString stringWithUTF8String:response]]; /* evaluate input and write the result */
      }
    }
  }
  
  [pool drain];
  return 0;
}
