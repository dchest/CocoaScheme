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
    printf("CocoaScheme. Press Ctrl-C to exit.\n");
    // prepare some helpers
    [sc evalString:@"(defmacro class (name)"
                    " `(string->objc:class (symbol->string ',name)))"];
    [sc evalString:@"(define that ())"];
    
    char buffer[512];
    NSMutableString *s = [[NSMutableString alloc] init];
    while (1)                           /* fire up a REPL */
    {
      fprintf(stdout, "> ");        /* prompt for input */
      fgets(buffer, 512, stdin);
      if (feof(stdin))
        return 0;
      [s appendFormat:@"%s", buffer];
      // count parentheses
      int parentheses = 0;
      for (int i = 0; i < [s length]; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '(')
          parentheses++;
        else if (c == ')')
          parentheses--;
      }
      if (parentheses > 0) {
        printf(">");
        continue;
      }
      
      if ([s length] > 0 && [s characterAtIndex:0] != '\n') {
        [sc evalString:[NSString stringWithFormat:@"(begin (set! that %@) (write that))", s]];
        [s setString:@""];
        printf("\n");
      }
    }
  }
  
  [pool drain];
  return 0;
}
