/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2020 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  function.h: library functions
 **
 **/
#if !defined(_LIBMU_TYPES_FUNCTION_H_)
#define _LIBMU_TYPES_FUNCTION_H_

#include <cassert>
#include <functional>
#include <memory>
#include <sstream>
#include <vector>

#include "libmu/compiler.h"
#include "libmu/env.h"
#include "libmu/eval.h"
#include "libmu/print.h"
#include "libmu/type.h"

#include "libmu/types/address.h"
#include "libmu/types/cons.h"

namespace libmu {

class Env;
using Frame = Env::Frame;

/** * function type class **/
class Function : public Type {
 private:
  typedef struct {
    int arity;       /* arity checking */
    TagPtr name;     /* debugging */
    TagPtr core;     /* as an address */
    TagPtr form;     /* as a lambda */
    TagPtr env;      /* closures */
    std::vector<Frame*> context;
    TagPtr frame_id; /* lexical reference */
  } Layout;

  Layout function_;

 public: /* TagPtr */
  static constexpr bool IsType(TagPtr ptr) {
    return TagOf(ptr) == TAG::FUNCTION;
  }

  /* accessors */
  static int arity(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->arity;
  }
  
  static std::vector<Frame*> context(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->context;
  }
  
  static size_t ncontext(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->context.size();
  }
  
  static std::vector<Frame*> context(TagPtr fn,
                                     std::vector<Frame*> ctx) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->context = ctx;
  }
  
  static TagPtr env(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->env;
  }
  
  static TagPtr env(TagPtr fn, TagPtr env) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->env = env;
  }

  static TagPtr form(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->form;
  }

  static TagPtr form(TagPtr fn, TagPtr form) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->form = form;
  }
  
  static TagPtr core(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->core;
  }
  
  static TagPtr frame_id(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->frame_id;
  }
  
  static TagPtr name(TagPtr fn) {
    assert(IsType(fn));

    return Untag<Layout>(fn)->name;
  }

  static TagPtr name(TagPtr fn, TagPtr symbol) {
    assert(IsType(fn));
    assert(Symbol::IsType(symbol));

    return Untag<Layout>(fn)->name = symbol;
  }

  static void CheckArity(Env*, TagPtr, const std::vector<TagPtr>&);
  static TagPtr Funcall(Env*, TagPtr, const std::vector<TagPtr>&);
  static void GcMark(Env*, TagPtr);
  static TagPtr ViewOf(Env*, TagPtr);

  static void CallFrame(Env::Frame* fp) {
    /* think: inline this? */
    static Env::FrameFn lambda = [](Env::Frame* fp) {
      fp->value = NIL;
      auto body = Cons::cdr(Function::form(fp->func));
      if (!Null(body))
        Cons::MapC(fp->env,
                   [fp](Env* env, TagPtr form) {
                     fp->value = Eval(env, form);
                   },
                   body);
    };

    if (Null(core(fp->func))) {
      lambda(fp);
    } else {
      Untag<Env::TagPtrFn>(core(fp->func))->fn(fp);
    }
  }

  static void PrintFunction(Env* env, TagPtr fn, TagPtr str, bool) {
    assert(IsType(fn));
    assert(Stream::IsType(str));

    auto stream = Stream::StreamDesignator(env, str);

    auto type = String::StdStringOf(
                   Symbol::name(Type::MapClassSymbol(Type::TypeOf(fn))));

    auto name = String::StdStringOf(Symbol::name(Function::name(fn)));
    
    std::stringstream hexs;

    hexs << std::hex << Type::to_underlying(fn);
    PrintStdString(env, "#<:" + type + " 0x" + hexs.str() + ";" + name + ">", stream, false);
  }

 public: /* object model */
  TagPtr Evict(Env* env, const char* src) {
    auto fp = env->heap_alloc<Layout>(sizeof(Layout), SYS_CLASS::FUNCTION, src);

    *fp = function_;
    tag_ = Entag(fp, TAG::FUNCTION);

    return tag_;
  }

  /* core functions */
  explicit Function(Env* env, TagPtr name, const Env::TagPtrFn* core)
    : Type() {
    assert(Symbol::IsType(name));
    
    function_.arity = core.nreqs;
    function_.context = std::vector<Frame*>{};
    function_.core = Address(static_cast<void*>(const_cast<Env::TagPtrFn*>(core))).tag_;
    function_.env = NIL;
    function_.form = NIL;
    function_.frame_id = Fixnum(env->frame_id_).tag_;
    function_.name = name;
    
    env->frame_id_++;

    tag_ = Entag(reinterpret_cast<void*>(&function_), TAG::FUNCTION);
  }
  
  /* closures */
  /* think: needs name? */
  explicit Function(Env* env, TagPtr name, std::vector<Frame*> context, TagPtr form, int arity)
    : Type() {
    assert(Cons::IsList(form));

    auto lambda = Compiler::ParseLambda(env, Cons::car(form));
    size_t nreqs = Cons::Length(env, Compiler::lexicals(lambda)) -
                   (Null(Compiler::restsym(lambda)) ? 0 : 1);

    function_.arity = arity;
    function_.context = context;
    function_.core = NIL;
    function_.env = Cons::List(env, env->lexenv_);
    function_.form = Cons(lambda, Cons::cdr(form)).tag_;
    function_.frame_id = Fixnum(env->frame_id_).tag_;
    function_.name = NIL;

    env->frame_id_++;

    tag_ = Entag(reinterpret_cast<void*>(&function_), TAG::FUNCTION);
  }

}; /* class Function */

} /* namespace libmu */

#endif /* _LIBMU_TYPES_FUNCTION_H_ */
