//
//  Scheme.m
//  CocoaScheme
//
//  Created by Dmitry Chestnykh on 25.12.09.
//  Copyright 2009 Coding Robots. All rights reserved.
//

#import "Scheme.h"

// C types
// We don't use @encode because it gives a char *, but we need a single char for 'switch'
#define _C_BITFIELD 'b'
#define _C_C99_BOOL 'B'
#define _C_CHAR 'c'
#define _C_UNSIGNED_CHAR 'C'
#define _C_DOUBLE 'd'
#define _C_FLOAT 'f'
#define _C_INT 'i'
#define _C_UNSIGNED_INT 'I'
#define _C_LONG 'l'
#define _C_UNSIGNED_LONG 'L'
#define _C_LONG_LONG 'q'
#define _C_UNSIGNED_LONG_LONG 'Q'
#define _C_SHORT 's'
#define _C_UNSIGNED_SHORT 'S'
#define _C_VOID 'v'
#define _C_UNKNOWN '?'

#define _C_ID '@'
#define _C_CLASS '#'
#define _C_POINTER '^'
#define _C_STRING '*'

#define _C_UNION '('
#define _C_UNION_END ')'
#define _C_ARRAY '['
#define _C_ARRAY_END ']'
#define _C_STRUCT '{'
#define _C_STRUCT_END '}'
#define _C_SELECTOR ':'

#define _C_IN 'n'
#define _C_INOUT 'N'
#define _C_OUT 'o'
#define _C_BYCOPY 'O'
#define _C_CONST 'r'
#define _C_BYREF 'R'
#define _C_ONEWAY 'V'



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

/* ObjC class and object */

static int objc_id_type_tag = 0;

static s7_pointer string_to_objc_class(s7_scheme *sc, s7_pointer args)
{
  if (args == s7_nil(sc))
    return s7_nil(sc);

  NSString *className = [NSString stringWithUTF8String:s7_string(s7_car(args))];
  Class klass = NSClassFromString(className);

  return s7_make_object(sc, objc_id_type_tag, (void *)klass);
}


static s7_pointer make_objc_object(s7_scheme *sc, s7_pointer args)
{
  if (args == s7_nil(sc))
    return s7_nil(sc);

  Class klass = (Class)s7_object_value(s7_car(args));

  return s7_make_object(sc, objc_id_type_tag, (void *)[klass alloc]);
}

static s7_pointer is_objc_object(s7_scheme *sc, s7_pointer args)
{
  return(s7_make_boolean(sc, s7_is_object(s7_car(args))
                         && s7_object_type(s7_car(args)) == objc_id_type_tag));
}

NSString *extract_selector_name(s7_scheme *sc, s7_pointer args)
{
  NSMutableString *selectorName = [[NSMutableString alloc] init];
  s7_pointer arg = args;
  // extract only odd arguments
  while (arg != s7_nil(sc)) {
    NSString *selectorPart = [NSString stringWithUTF8String:s7_symbol_name(s7_car(arg))];
    [selectorName appendString:[selectorPart sc_stringByConvertingDashes]];
    arg = s7_cdr(arg);
    if (arg == s7_nil(sc))
        break;
    arg = s7_cdr(arg);
  }
  return [selectorName autorelease];
}

static id s7_pointer_to_id(s7_scheme *sc, s7_pointer p)
{
  if (s7_nil(sc) == p)
    return [NSNull null];
  if (s7_is_object(p) && s7_object_type(p) == objc_id_type_tag)
    return s7_object_value(p);
  if (s7_is_integer(p))
    return [NSNumber numberWithLongLong:s7_integer(p)];
  if (s7_is_real(p))
    return [NSNumber numberWithDouble:s7_real(p)];
  if (s7_is_boolean(p))
    return [NSNumber numberWithBool:s7_boolean(sc, p)];
  if (s7_is_string(p))
    return [NSString stringWithUTF8String:s7_string(p)];
  NSLog(@"Unsupported Scheme data type for conversion to Objective-C type");
  return nil;
}

#define setarg(type, value, i, invocation) \
        do { type v = (type)value; [invocation setArgument:&v atIndex:i]; } while(0)

static s7_pointer objc_id_apply(s7_scheme *sc, s7_pointer obj, s7_pointer args)
{
  id object = s7_object_value(obj);
  NSString *selectorName = extract_selector_name(sc, args);
  if ([selectorName length] == 0) {
    // return self
    return obj;
  }
  SEL selector = NSSelectorFromString(selectorName);
  NSMethodSignature *sig = [object methodSignatureForSelector:selector];
  if (!sig) {
    NSLog(@"No signature for method: %@", selectorName);
    return s7_nil(sc);
  }
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
  [inv setTarget:object];
  [inv setSelector:selector];
  int i = 2;
  s7_pointer tmpargs = args;
  //void *buffer = NULL; // for array and struct - declared here to free it after invocation
  // extract only even arguments
  while (tmpargs != s7_nil(sc) && (tmpargs = s7_cdr(tmpargs)) != s7_nil(sc)) {
    s7_pointer a = s7_car(tmpargs);
    char argtype = [sig getArgumentTypeAtIndex:i][0];
    switch (argtype) {
      case _C_ID:
      case _C_CLASS: {
        id argument = s7_pointer_to_id(sc, a);
        [inv setArgument:&argument atIndex:i];
        break;
      }
      case _C_CHAR: {
        if (s7_is_boolean(a))
          setarg(char, s7_boolean(sc, a), i, inv);
        else
          setarg(char, s7_integer(a), i, inv);
        break;
      }
      case _C_UNSIGNED_CHAR:
        setarg(unsigned char, s7_integer(a), i, inv);
        break;
      case _C_C99_BOOL:
        setarg(_Bool, s7_boolean(sc, a), i, inv);
        break;
      case _C_SHORT:
        setarg(short, s7_integer(a), i, inv);
        break;
      case _C_UNSIGNED_SHORT:
        setarg(unsigned short, s7_integer(a), i, inv);
        break;
      case _C_INT:
        setarg(int, s7_integer(a), i, inv);
        break;
      case _C_UNSIGNED_INT:
        setarg(unsigned int, s7_integer(a), i, inv);
        break;
      case _C_LONG:
        setarg(long, s7_integer(a), i, inv);
        break;
      case _C_UNSIGNED_LONG:
        setarg(unsigned long, s7_integer(a), i, inv);
        break;
      case _C_LONG_LONG:
        setarg(long long, s7_integer(a), i, inv);
        break;
      case _C_UNSIGNED_LONG_LONG:
        setarg(unsigned long long, s7_integer(a), i, inv);
        break;
      case _C_DOUBLE:
        setarg(double, s7_real(a), i, inv);
        break;
      case _C_FLOAT:
        setarg(float, s7_real(a), i, inv);
        break;
      case _C_POINTER:
        setarg(void*, s7_object_value(a), i, inv);
        break;
      case _C_ARRAY:
      case _C_STRUCT:
      case _C_SELECTOR: {
        //NSUInteger length = [sig frameLength];
        //buffer = malloc(length);
        //memcpy(buffer, s7_object_value(a), length);
        void *p = s7_object_value(a);
        [inv setArgument:p atIndex:i];
        break;        
      }
    }
    tmpargs = s7_cdr(tmpargs);
    i++;
  }
  [inv invoke];
  id result = nil;
  [inv getReturnValue:&result];
  return s7_make_object(sc, objc_id_type_tag, result);
}

static char *print_objc_object(s7_scheme *sc, void *val)
{
  return strdup([[NSString stringWithFormat:@"#<objc:object {%@} %@>", [(id)val className], [(id)val description]] UTF8String]);
}

static void free_objc_object(void *obj)
{
  [(id)obj release];
}

static bool equal_objc_id(void *val1, void *val2)
{
  return (bool)[(id)val1 isEqual:(id)val2];
}


/* Utility */

static s7_pointer string_to_objc_string(s7_scheme *sc, s7_pointer args)
{
  return s7_make_object(sc, objc_id_type_tag, [NSString stringWithUTF8String:s7_string(s7_car(args))]);
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
  objc_id_type_tag = s7_new_type("objc:object", print_objc_object, free_objc_object, equal_objc_id, NULL, objc_id_apply, NULL);

  s7_define_function(scheme_, "string->objc:class", string_to_objc_class, 1, 0, false,
                     "(make-objc:class \"NSObject\") returns an Objective-C Class");

  s7_define_function(scheme_, "alloc-objc:object", make_objc_object, 1, 0, false, "(make-objc:object class) allocs and returns an Objective-C object");

  s7_define_function(scheme_, "objc:id?", is_objc_object, 1, 0, false, "(objc:id? value) returns #t if its argument is an Objective-C id (object or class)");

  s7_define_function(scheme_, "string->objc:string", string_to_objc_string, 1, 0, false, "(string->objc:string \"string\") convert Scheme string to Objective-C NSString");

  s7_define_function(scheme_, "objc:string->string", objc_string_to_string, 1, 0, false, "(objc:string->string objc:object-NSString) convert Objective-C NSString to Scheme string");
}

- (void)finalize
{
  s7_quit(scheme_);
  [super finalize];
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
