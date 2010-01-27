#import <Foundation/Foundation.h>
#include <readline/readline.h>
#include <readline/history.h>
#import "Scheme.h"

/*
 
  Usage:
    CocoaScheme [filename] [-r]
 
  if no filename, launches REPL. 
  Use -r switch after filename to launch REPL after loading file.

*/

int main (int argc, const char *argv[]) 
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  Scheme *sc = [Scheme sharedScheme];

  if (argc > 1) {
    // run file
    [sc loadFile:[NSString stringWithUTF8String:argv[1]]];
    if (argc <= 2 || strcmp(argv[2], "-r") != 0)
      return 0;
  }
  // mini REPL
  printf("CocoaScheme. Press Ctrl-C to exit.\n");
  // prepare some helpers
  [sc evalString:@"(defmacro class (name)"
                  " `(string->objc:class (symbol->string ',name)))"];
  [sc evalString:@"(define that ())"]; // variable to hold last evaluation result
  [sc evalString:@"(define thatexpr ())"]; // variable to hold last expression
  
  NSMutableString *s = [[NSMutableString alloc] init];
  while (1)
  {
    char *buffer = readline("> ");
    if (buffer == NULL)
      return 0;
    [s appendFormat:@"%s", buffer];
    free(buffer);
    // count parentheses to decide if expression is complete
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
      [sc evalString:[NSString stringWithFormat:@"(let ((_expr %@)) (write _expr) (set! that _expr) (set! thatexpr `%@))", s, s]];
      [s setString:@""];
      printf("\n");
    }
  }
  
  [pool drain];
  return 0;
}
