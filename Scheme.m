//
//  Scheme.m
//  CocoaScheme
//
//  Created by Dmitry Chestnykh on 25.12.09.
//  Copyright 2009 Coding Robots. All rights reserved.
//

#import "Scheme.h"
#import <ObjC/runtime.h>

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

static s7_pointer objc_extract_selector(s7_scheme *sc, s7_pointer args)
{
  return s7_make_string(sc, [extract_selector_name(sc, args) UTF8String]);
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
    return [NSNumber numberWithDouble:s7_number_to_real(p)];
  if (s7_is_boolean(p))
    return [NSNumber numberWithBool:s7_boolean(sc, p)];
  if (s7_is_string(p))
    return [NSString stringWithUTF8String:s7_string(p)];
  NSLog(@"Unsupported Scheme data type for conversion to Objective-C type");
  return nil;
}

#define setarg(type, value, i, invocation) \
        do { type v = (type)value; [invocation setArgument:&v atIndex:i]; } while(0)

#define get_return_value(type) \
        type _value; [inv getReturnValue:&_value]

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
      case _C_CHAR:
        setarg(char, s7_is_boolean(a) ? s7_boolean(sc, a) : s7_integer(a), i, inv);
        break;
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
        setarg(double, s7_number_to_real(a), i, inv);
        break;
      case _C_FLOAT:
        setarg(float, s7_number_to_real(a), i, inv);
        break;
      case _C_POINTER:
        setarg(void*, s7_object_value(a), i, inv);
        break;
      case _C_STRUCT: {
        const char *fulltype = [sig getArgumentTypeAtIndex:i];
        if (strstr(fulltype, "CGRect") != NULL) {
          NSRect rect = NSMakeRect(s7_number_to_real(s7_list_ref(sc, a, 0)),
                                   s7_number_to_real(s7_list_ref(sc, a, 1)),
                                   s7_number_to_real(s7_list_ref(sc, a, 2)),
                                   s7_number_to_real(s7_list_ref(sc, a, 3)));
          [inv setArgument:&rect atIndex:i];
        } else if (strstr(fulltype, "CGPoint") != NULL) {
          NSPoint point = NSMakePoint(s7_number_to_real(s7_list_ref(sc, a, 0)),
                                    s7_number_to_real(s7_list_ref(sc, a, 1)));
          [inv setArgument:&point atIndex:i];
        } else if (strstr(fulltype, "CGSize") != NULL) {
          NSSize size = NSMakeSize(s7_number_to_real(s7_list_ref(sc, a, 0)),
                                      s7_number_to_real(s7_list_ref(sc, a, 1)));
          [inv setArgument:&size atIndex:i];
        } else if (strstr(fulltype, "NSRange") != NULL) {
          NSRange range = NSMakeRange(s7_integer(s7_list_ref(sc, a, 0)),
                                     s7_integer(s7_list_ref(sc, a, 1)));
          [inv setArgument:&range atIndex:i];
        }
        break;
      }
      case _C_ARRAY: {
        //NSUInteger length = [sig frameLength];
        //buffer = malloc(length);
        //memcpy(buffer, s7_object_value(a), length);
        void *p = s7_c_pointer(a);
        [inv setArgument:p atIndex:i];
        break;
      }
      case _C_SELECTOR: {
        SEL selector = sel_registerName(s7_string(a));
        [inv setArgument:&selector atIndex:i];
        break;
      }
    }
    tmpargs = s7_cdr(tmpargs);
    i++;
  }
  [inv invoke];
  // convert result
  switch ([sig methodReturnType][0]) {
    case _C_ID:
    case _C_CLASS: {
      get_return_value(id);
      if ([_value isKindOfClass:[NSString class]])
        return s7_make_string(sc, [_value UTF8String]);
      else
        return s7_make_object(sc, objc_id_type_tag, _value);
    }
    case _C_CHAR: {
      get_return_value(char);
      if (_value == YES || _value == NO)
        return s7_make_boolean(sc, _value);
      else
        return s7_make_integer(sc, _value);
    }
    case _C_C99_BOOL: {
      get_return_value(_Bool);
      return s7_make_boolean(sc, _value);
    }
    case _C_UNSIGNED_CHAR: {
      get_return_value(unsigned char);
      return s7_make_integer(sc, _value);
    }
    case _C_SHORT: {
      get_return_value(short);
      return s7_make_integer(sc, _value);
    }
    case _C_UNSIGNED_SHORT: {
      get_return_value(unsigned short);
      return s7_make_integer(sc, _value);
    }
    case _C_INT: {
      get_return_value(int);
      return s7_make_integer(sc, _value);
    }
    case _C_UNSIGNED_INT: {
      get_return_value(unsigned int);
      return s7_make_integer(sc, _value);
    }
    case _C_LONG: {
      get_return_value(long);
      return s7_make_integer(sc, _value);
    }
    case _C_UNSIGNED_LONG: {
      get_return_value(unsigned long);
      return s7_make_integer(sc, _value);
    }
    case _C_LONG_LONG: {
      get_return_value(long long);
      return s7_make_integer(sc, _value);
    }
    case _C_UNSIGNED_LONG_LONG: {
      get_return_value(unsigned long long);
      return s7_make_integer(sc, _value);
    }
    case _C_DOUBLE: {
      get_return_value(double);
      return s7_make_real(sc, _value);
    }
    case _C_FLOAT: {
      get_return_value(float);
      return s7_make_real(sc, _value);
    }
    case _C_STRING: {
      NSUInteger len = [[inv methodSignature] methodReturnLength];
      char *buf = malloc(len);
      [inv getReturnValue:&buf];
      s7_pointer p = s7_make_string_with_length(sc, buf, len);
      free(buf);
      return p;
    }
    case _C_STRUCT: {
      const char *fulltype = [sig methodReturnType];
      if (strstr(fulltype, "CGRect") != NULL) {
        NSRect rect;
        [inv getReturnValue:&rect];
        s7_pointer x = s7_make_real(sc, rect.origin.x);
        s7_pointer y = s7_make_real(sc, rect.origin.y);
        s7_pointer w = s7_make_real(sc, rect.size.width);
        s7_pointer h = s7_make_real(sc, rect.size.height);
        return s7_cons(sc, x, s7_cons(sc, y, s7_cons(sc, w, s7_cons(sc, h, s7_nil(sc)))));
      } else if (strstr(fulltype, "CGPoint") != NULL) {
        NSPoint point;
        [inv getReturnValue:&point];
        s7_pointer x = s7_make_real(sc, point.x);
        s7_pointer y = s7_make_real(sc, point.y);
        return s7_cons(sc, x, s7_cons(sc, y, s7_nil(sc)));
      } else if (strstr(fulltype, "CGSize") != NULL) {
        NSSize size;
        [inv getReturnValue:&size];
        s7_pointer w = s7_make_real(sc, size.width);
        s7_pointer h = s7_make_real(sc, size.height);
        return s7_cons(sc, w, s7_cons(sc, h, s7_nil(sc)));
      } else if (strstr(fulltype, "NSRange") != NULL) {
        NSRange range;
        [inv getReturnValue:&range];
        s7_pointer location = s7_make_integer(sc, range.location);
        s7_pointer length = s7_make_integer(sc, range.length);
        return s7_cons(sc, location, s7_cons(sc, length, s7_nil(sc)));
      }
      // else fall-through
    }
    case _C_ARRAY: {
      void *value = malloc([[inv methodSignature] methodReturnLength]);
      [inv getReturnValue:(void *)value];
      return s7_make_c_pointer(sc, value);
      //TODO will s7 free this pointer for us?
    }
    case _C_SELECTOR: {
      SEL selector;
      [inv getReturnValue:&selector];
      return s7_make_string(sc, sel_getName(selector));
    }
    case _C_VOID:
      return s7_nil(sc);
  }
}

static char *print_objc_object(s7_scheme *sc, void *val)
{
  return strdup([[NSString stringWithFormat:@"#<objc:id %@:%@>", [(id)val className], [(id)val description]] UTF8String]);
}

static void free_objc_object(void *obj)
{
  [(id)obj release];
}

static bool equal_objc_id(void *val1, void *val2)
{
  return (bool)[(id)val1 isEqual:(id)val2];
}

/* Creating classes */

static s7_pointer objc_allocate_class_pair(s7_scheme *sc, s7_pointer args)
{
  const char *name = s7_string(s7_car(args));
  Class superclass = s7_pointer_to_id(sc, s7_car(s7_cdr(args)));
  Class klass = objc_allocateClassPair(superclass, name, 0);
  if (klass == Nil)
    return s7_nil(sc);
  else
    return s7_make_object(sc, objc_id_type_tag, klass);
}

static s7_pointer objc_register_class_pair(s7_scheme *sc, s7_pointer args)
{
  Class klass = s7_pointer_to_id(sc, s7_car(args));
  objc_registerClassPair(klass);
  return s7_nil(sc);
}

s7_pointer callSchemeProcedure(id self, SEL _cmd, va_list list)
{
  s7_scheme *sc = sharedScheme->scheme_;
  NSString *selName = NSStringFromSelector(_cmd);
  // Lookup objc:Class:selName in Scheme
  id obj = self;
  if ([selName hasPrefix:@"super_"]) {
    obj = [self superclass];
    selName = [selName stringByReplacingCharactersInRange:NSMakeRange(0, 6 /*super_*/) withString:@""];
  }
  id oldObj = nil;
  s7_pointer proc;
  do {
    NSString *className = [obj className];
    const char *sym = [[NSString stringWithFormat:@"objc:%@:%@", className, selName] UTF8String];
    proc = s7_get_symbol_value(sc, sym);
    if (proc == s7_nil(sc)) {
      oldObj = obj;
      obj = [self superclass];      
    }
  } while (proc == s7_nil(sc) && obj != Nil && oldObj != obj);
  
  if (proc == s7_nil(sc)) {
    NSLog(@"Method [%@ %@] not found", [self className], selName);
    return nil;
  }
  // Convert arguments to Scheme
  Method method = class_getInstanceMethod([self class], _cmd);
  unsigned argNum = method_getNumberOfArguments(method);

  char argType[255];
  s7_pointer args = s7_nil(sc);

  for(int i = 2; i < argNum; i++) {
    method_getArgumentType(method, i, argType, 255);
    switch (argType[0]) {
      case _C_ID:
      case _C_CLASS: {
        id value = va_arg(list, id);
        args = s7_cons(sc, s7_make_object(sc, objc_id_type_tag, value), args);
        break;
      }
      case _C_CHAR:               /* these types are promoted to int */
      case _C_UNSIGNED_CHAR:
      case _C_SHORT:
      case _C_UNSIGNED_SHORT:
      case _C_INT: {
        int c = va_arg(list, int);
        args = s7_cons(sc, s7_make_integer(sc, c), args);
        break;
      }
      case _C_UNSIGNED_INT: {
        unsigned int c = va_arg(list, unsigned int);
        args = s7_cons(sc, s7_make_integer(sc, c), args);
        break;
      }
      case _C_LONG: {
        long c = va_arg(list, long);
        args = s7_cons(sc, s7_make_integer(sc, c), args);
        break;
      }
      case _C_UNSIGNED_LONG: {
        unsigned long c = va_arg(list, unsigned long);
        args = s7_cons(sc, s7_make_integer(sc, c), args);
        break;
      }
      case _C_LONG_LONG: {
        long long c = va_arg(list, long long);
        args = s7_cons(sc, s7_make_integer(sc, c), args);
        break;
      }
      case _C_UNSIGNED_LONG_LONG: {
        unsigned long long c = va_arg(list, unsigned long long);
        args = s7_cons(sc, s7_make_integer(sc, c), args);
        break;
      }
      case _C_FLOAT:        /* promoted to double */
      case _C_DOUBLE: {
        double c = va_arg(list, double);
        args = s7_cons(sc, s7_make_real(sc, c), args);
        break;
      }
      case _C_STRUCT: {
        s7_pointer l = nil;
        if (strstr(argType, "CGRect") != NULL) {
          NSRect rect = va_arg(list, NSRect);
          s7_pointer x = s7_make_real(sc, rect.origin.x);
          s7_pointer y = s7_make_real(sc, rect.origin.y);
          s7_pointer w = s7_make_real(sc, rect.size.width);
          s7_pointer h = s7_make_real(sc, rect.size.height);
          l = s7_cons(sc, x, s7_cons(sc, y, s7_cons(sc, w, s7_cons(sc, h, s7_nil(sc)))));
        } else if (strstr(argType, "CGPoint") != NULL) {
          NSPoint point = va_arg(list, NSPoint);
          s7_pointer x = s7_make_real(sc, point.x);
          s7_pointer y = s7_make_real(sc, point.y);
          l = s7_cons(sc, x, s7_cons(sc, y, s7_nil(sc)));
        } else if (strstr(argType, "CGSize") != NULL) {
          NSSize size = va_arg(list, NSSize);
          s7_pointer w = s7_make_real(sc, size.width);
          s7_pointer h = s7_make_real(sc, size.height);
          l = s7_cons(sc, w, s7_cons(sc, h, s7_nil(sc)));
        } else if (strstr(argType, "NSRange") != NULL) {
          NSRange range = va_arg(list, NSRange);
          s7_pointer location = s7_make_integer(sc, range.location);
          s7_pointer length = s7_make_integer(sc, range.length);
          l = s7_cons(sc, location, s7_cons(sc, length, s7_nil(sc)));
        }
        if (l != nil)
          args = s7_cons(sc, l, args);
        else
          NSLog(@"Unsupported struct %s in arguments", argType);
      }
    }
  }
  // first argument to method is always self
  args = s7_cons(sc, s7_make_object(sc, objc_id_type_tag, self), args);
  return s7_call(sc, proc, args);
}

#define callSchemeAndGetResult() \
  s7_scheme *sc = sharedScheme->scheme_; \
  Method method = class_getInstanceMethod([self class], _cmd); \
  va_list list; \
  va_start(list, _cmd); \
  s7_pointer result = callSchemeProcedure(self, _cmd, list); \
  va_end(list); \


void void_invokeSchemeProcedure(id self, SEL _cmd, ...) 
{
  callSchemeAndGetResult();
}

id id_invokeSchemeProcedure(id self, SEL _cmd, ...) 
{
  callSchemeAndGetResult();
  return s7_pointer_to_id(sc, result);
}

char char_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  if (s7_is_boolean(result))
    return s7_boolean(sc, result);
  else
    return s7_integer(result);
}

unsigned char uchar_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

int int_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

unsigned int uint_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

short short_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

unsigned short ushort_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

long long_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

unsigned long ulong_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

long long longlong_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

unsigned long long ulonglong_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_integer(result);
}

float float_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_number_to_real(result);
}

double double_invokeSchemeProcedure(id self, SEL _cmd, ...)
{
  callSchemeAndGetResult();
  return s7_number_to_real(result);
}

#define addMethodWithIMP(func) \
  s7_make_boolean(sc, class_addMethod(klass, sel_registerName(selName), (IMP)func, types));


static s7_pointer objc_add_method(s7_scheme *sc, s7_pointer args)
{
  Class klass         = s7_pointer_to_id(sc, s7_car(args));
  const char *selName = s7_string(s7_car(s7_cdr(args)));
  const char *types   = s7_string(s7_car(s7_cdr(s7_cdr(args))));
  
  // Create an alias for super-method
  IMP superIMP = class_getMethodImplementation(class_getSuperclass(klass), sel_registerName(selName));
  if (superIMP != NULL) {
    // register super method with a new name
    NSString *superSelName = [NSString stringWithFormat:@"super_%s", selName];
    if (!class_addMethod(klass , NSSelectorFromString(superSelName), superIMP, types))
      NSLog(@"cannot re-register supermethod super_%s", selName);
  }
  
  // which IMP to add
  switch (types[0]) {
    case _C_VOID:
      return addMethodWithIMP(void_invokeSchemeProcedure);
    case _C_ID:
    case _C_CLASS:
      return addMethodWithIMP(id_invokeSchemeProcedure);
    case _C_CHAR:
      return addMethodWithIMP(char_invokeSchemeProcedure);
    case _C_UNSIGNED_CHAR:
      return addMethodWithIMP(uchar_invokeSchemeProcedure);
    case _C_SHORT:
      return addMethodWithIMP(short_invokeSchemeProcedure);
    case _C_UNSIGNED_SHORT:
      return addMethodWithIMP(ushort_invokeSchemeProcedure);
    case _C_INT:
      return addMethodWithIMP(int_invokeSchemeProcedure);
    case _C_UNSIGNED_INT:
      return addMethodWithIMP(uint_invokeSchemeProcedure);
    case _C_LONG:
      return addMethodWithIMP(long_invokeSchemeProcedure);
    case _C_UNSIGNED_LONG:
      return addMethodWithIMP(ulong_invokeSchemeProcedure);
    case _C_LONG_LONG:
      return addMethodWithIMP(longlong_invokeSchemeProcedure);
    case _C_UNSIGNED_LONG_LONG:
      return addMethodWithIMP(ulonglong_invokeSchemeProcedure);
    case _C_FLOAT:
      return addMethodWithIMP(float_invokeSchemeProcedure);
    case _C_DOUBLE:
      return addMethodWithIMP(double_invokeSchemeProcedure);
    default:
      return s7_make_boolean(sc, NO);
  }
}

/* Utility */

static s7_pointer objc_framework(s7_scheme *sc, s7_pointer args)
{
  NSString *libraryPath = [@"/" stringByAppendingPathComponent:[NSString pathWithComponents:[NSArray arrayWithObjects:@"Library", @"Frameworks", nil]]];
  //TODO bundleLibraryPath
  NSString *userLibraryPath = [NSHomeDirectory() stringByAppendingPathComponent:libraryPath];
  NSString *systemLibraryPath = [@"/System" stringByAppendingPathComponent:libraryPath];
  NSArray *paths = [NSArray arrayWithObjects:userLibraryPath, libraryPath, systemLibraryPath, nil];
  NSString *name = [NSString stringWithUTF8String:s7_string(s7_car(args))];
  NSString *filename = [name stringByAppendingPathExtension:@"framework"];

  for (NSString *path in paths) {
    if ([[NSBundle bundleWithPath:[path stringByAppendingPathComponent:filename]] load])
      return s7_make_boolean(sc, YES); // loaded
  }
  // try plain name, maybe it's already specified as a full path (incl. extension)
  if ([[NSBundle bundleWithPath:name] load]) {
    return s7_make_boolean(sc, YES); // loaded
  }
  // error loading
  return s7_make_boolean(sc, NO);
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
  objc_id_type_tag = s7_new_type("objc:id", print_objc_object, free_objc_object, equal_objc_id, NULL, objc_id_apply, NULL);

  s7_define_function(scheme_, "string->objc:class", string_to_objc_class, 1, 0, false,
                     "(string->objc:class str) returns an Objective-C class named str");

  s7_define_function(scheme_, "objc:id?", is_objc_object, 1, 0, false, "(objc:id? obj) returns #t if obj is Objective-C id (object or class)");

  s7_define_function(scheme_, "objc:framework", objc_framework, 1, 0, false, "(objc:framework name) load Objective-C framework");

  s7_define_function(scheme_, "objc:allocate-class-pair", objc_allocate_class_pair, 2, 0, false, "(objc:allocate-class-pair name superclass) allocate Objective-C class pair");

  s7_define_function(scheme_, "objc:register-class-pair", objc_register_class_pair, 1, 0, false, "(objc:register-class-pair class) register previously allocated Objective-C class pair");

  s7_define_function(scheme_, "objc:add-method", objc_add_method, 3, 0, false, "(objc:add-method class methodname types) add method methodname (string) with types (string) to class (objc:id)");

  s7_define_function(scheme_, "objc:extract-selector", objc_extract_selector, 1, 0, true, "(objc:extract-selector ...) return selector name extracted from list");
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
