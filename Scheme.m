//
//  Scheme.m
//  CocoaScheme
//
//  Created by Dmitry Chestnykh on 25.12.09.
//  Copyright 2009 Coding Robots. All rights reserved.
//

#import "Scheme.h"

@interface NSString (SchemeAdditions)
- (NSString *)sc_stringByConvertingDashes;
@end
@implementation NSString (SchemeAdditions)

- (NSString *)sc_stringByConvertingDashes
{
  NSMutableString *result = [[NSMutableString alloc] init];
  int i = 0;
  for (NSString *part in [self componentsSeparatedByString:@"-"]) {
    if (i++ > 0)
      [result appendString:[part capitalizedString]];
    else
      [result appendString:part];
  }
  return [result autorelease];
}

@end


@interface Scheme ()
- (void)initializeTypes;
@end

static Scheme *sharedScheme;

/* ObjC class */

static int objc_class_type_tag = 0;

static char *print_objc_class(s7_scheme *sc, void *val)
{
  return strdup([[NSString stringWithFormat:@"#<objc:class %@>", [(Class)val description]] UTF8String]);
}

static bool equal_objc_class(void *val1, void *val2)
{
  return (bool)((Class)val1 == (Class)val2);
}

static s7_pointer make_objc_class(s7_scheme *sc, s7_pointer args)
{
  if (args == s7_nil(sc))
    return s7_nil(sc);
  
  NSString *className = [NSString stringWithUTF8String:s7_string(s7_car(args))];
  Class klass = NSClassFromString(className);
  
  return s7_make_object(sc, objc_class_type_tag, (void *)klass);
}

static s7_pointer is_objc_class(s7_scheme *sc, s7_pointer args)
{
  return s7_make_boolean(sc, s7_is_object(s7_car(args)) && s7_object_type(s7_car(args)) == objc_class_type_tag);
}

/* ObjC object */

static int objc_object_type_tag = 0;

static char *print_objc_object(s7_scheme *sc, void *val)
{
  return strdup([[NSString stringWithFormat:@"#<objc:object {%@} %@>", [(id)val className], [(id)val description]] UTF8String]);
}

static void free_objc_object(void *obj)
{
  [(id)obj release];
}

static bool equal_objc_object(void *val1, void *val2)
{
  return (bool)[(id)val1 isEqual:(id)val2];
}

static s7_pointer make_objc_object(s7_scheme *sc, s7_pointer args)
{
  if (args == s7_nil(sc))
    return s7_nil(sc);
  
  Class klass = (Class)s7_object_value(s7_car(args));
  
  return s7_make_object(sc, objc_object_type_tag, (void *)[klass alloc]);
}

static s7_pointer is_objc_object(s7_scheme *sc, s7_pointer args)
{
  return(s7_make_boolean(sc, s7_is_object(s7_car(args)) && s7_object_type(s7_car(args)) == objc_object_type_tag));
}

NSString *parse_method_call(s7_scheme *sc, s7_pointer args, NSArray **outArgs)
{
  NSMutableString *selectorName = [[NSMutableString alloc] init];
  NSMutableArray *arguments = [[NSMutableArray alloc] init];
  
  s7_pointer arg = args;
  BOOL odd = YES;
  while (arg != s7_nil(sc)) {
    if (odd) {
      // parsing selector name
      NSString *selectorPart = [NSString stringWithUTF8String:s7_symbol_name(s7_car(arg))];
      [selectorName appendString:[selectorPart sc_stringByConvertingDashes]];
    } else {
      // parsing argument
      [arguments addObject:(id)s7_object_value(s7_car(arg))];
    }
    arg = s7_cdr(arg);
    odd = !odd;
  }
  *outArgs = arguments;
  return selectorName;
}

static s7_pointer objc_object_apply(s7_scheme *sc, s7_pointer obj, s7_pointer args)
{
  id object = s7_object_value(obj);
//  NSString *message = [NSString stringWithUTF8String:s7_string(s7_car(args))];
//  SEL selector = NSSelectorFromString(message);
//  id argObject = nil;
//  if (s7_cdr(args) != s7_nil(sc)) {
//    argObject = s7_object_value(s7_car(s7_cdr(args)));
//  }
  NSArray *arguments = nil;
  NSString *selectorName = parse_method_call(sc, args, &arguments);
  SEL selector = NSSelectorFromString(selectorName);
  
  NSMethodSignature *sig = [object methodSignatureForSelector:selector];
  if (!sig) {
    NSLog(@"No signature for method: %@", selectorName);
    return s7_nil(sc);
  }
  
//  NSLog(@"Object: %@", object);
//  NSLog(@"Method: %@", selectorName);
//  NSLog(@"Args: %@", arguments);
  
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
  [inv setTarget:object];
  [inv setSelector:selector];
  int i = 2;
  for (id argument in arguments) {
    [inv setArgument:&argument atIndex:i];
    i++;
  }
  [inv retainArguments];
  [inv invoke];
  id result = nil;
  [inv getReturnValue:&result];

  return s7_make_object(sc, objc_object_type_tag, result);
}

/* Utility */

static s7_pointer string_to_objc_string(s7_scheme *sc, s7_pointer args)
{
  return s7_make_object(sc, objc_object_type_tag, [NSString stringWithUTF8String:s7_string(s7_car(args))]);  
}

static s7_pointer objc_string_to_string(s7_scheme *sc, s7_pointer args)
{
  return s7_make_string(sc, [(NSString *)s7_object_value(s7_car(args)) UTF8String]);
}

@implementation Scheme
@synthesize scheme=scheme_;

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
  [self initializeTypes];
  return self;
}

- (void)initializeTypes
{
  objc_class_type_tag = s7_new_type("objc:class", print_objc_class, NULL, equal_objc_class, NULL, objc_object_apply, NULL);
  s7_define_function(scheme_, "string->objc:class", make_objc_class, 1, 0, false, "(make-objc:class \"NSObject\") returns an Objective-C Class");
  s7_define_function(scheme_, "objc:class?", is_objc_class, 1, 0, false, "(objc:class? anything) returns #t if its argument is an Objective-C Class");

  objc_object_type_tag = s7_new_type("objc:object", print_objc_object, free_objc_object, equal_objc_object, NULL, objc_object_apply, NULL);
  s7_define_function(scheme_, "alloc-objc:object", make_objc_object, 1, 0, false, "(make-objc:object class) allocs and returns an Objective-C object");
  s7_define_function(scheme_, "objc:class?", is_objc_class, 1, 0, false, "(objc:class? anything) returns #t if its argument is an Objective-C Class");

  s7_define_function(scheme_, "string->objc:string", string_to_objc_string, 1, 0, false, "(string->objc:string \"string\") convert Scheme string to Objective-C NSString");

  s7_define_function(scheme_, "objc:string->string", objc_string_to_string, 1, 0, false, "(objc:string->string objc:object-NSString) convert Objective-C NSString to Scheme string");
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
