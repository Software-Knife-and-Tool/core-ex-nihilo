/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2020 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  compile.cc: library form compiler
 **
 **/
#include "libmu/compiler.h"

#include <cassert>
#include <functional>
#include <map>
#include <utility>

#include "libmu/env.h"
#include "libmu/print.h"
#include "libmu/type.h"

#include "libmu/types/cons.h"
#include "libmu/types/exception.h"
#include "libmu/types/function.h"
#include "libmu/types/macro.h"
#include "libmu/types/namespace.h"
#include "libmu/types/string.h"
#include "libmu/types/symbol.h"

namespace libmu {
namespace core {
namespace {

/** * is this symbol in the lexical environment? **/
auto LexicalEnv(Env* env, TagPtr sym) {
  assert(Symbol::IsType(sym) || Symbol::IsKeyword(sym));

  auto notfound = std::pair<TagPtr, size_t>{Type::NIL, 0};

  if (Symbol::IsKeyword(sym)) return notfound;

  std::vector<TagPtr>::reverse_iterator it;
  for (it = env->lexenv_.rbegin(); it != env->lexenv_.rend(); ++it) {
    assert(Function::IsType(*it));

    auto lexicals = core::lexicals(Cons::car(Function::form(*it)));
    assert(Cons::IsList(lexicals));

    for (size_t i = 0; i < Cons::Length(env, lexicals); ++i) {
      if (Type::Eq(sym, Cons::Nth(lexicals, i)))
        return std::pair<TagPtr, size_t>{*it, i};
    }
  }

  return notfound;
}

/** * compile a list of forms **/
auto List(Env* env, TagPtr list) {
  std::vector<TagPtr> vlist;
  Cons::cons_iter<TagPtr> iter(list);

  for (auto it = iter.begin(); it != iter.end(); it = ++iter)
    vlist.push_back(Compile(env, it->car));

  return Cons::List(env, vlist);
}

/** * compile lambda definition **/
auto Lambda(Env* env, TagPtr form) {
  assert(Cons::IsList(form));

  std::function<TagPtr(Env*, TagPtr)> parse_lambda = [](Env* env,
                                                        TagPtr lambda) {
    std::vector<TagPtr> lexicals;

    auto restsym = Type::NIL;
    auto has_rest = false;

    std::function<void(Env*, TagPtr)> parse =
        [&lexicals, lambda, &restsym, &has_rest](Env* env, TagPtr symbol) {
          if (!Symbol::IsType(symbol))
            Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                             "non-symbol in lambda list (parse-lambda)",
                             lambda);

          if (Type::Eq(Symbol::Keyword("rest"), symbol)) {
            if (has_rest)
              Exception::Raise(env, Exception::EXCEPT_CLASS::PARSE_ERROR,
                               "multiple rest clauses (parse-lambda)", lambda);
            has_rest = true;
            return;
          }

          if (Symbol::IsKeyword(symbol))
            Exception::Raise(
                env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                "keyword cannot be used as a lexical variable (parse-lambda)",
                lambda);

          auto el = std::find_if(
              lexicals.begin(), lexicals.end(), [restsym, symbol](TagPtr sym) {
                return Type::Eq(symbol, sym) || Type::Eq(symbol, restsym);
              });

          if (el != lexicals.end())
            Exception::Raise(env, Exception::EXCEPT_CLASS::PARSE_ERROR,
                             "duplicate symbol in lambda list (parse-lambda)",
                             lambda);

          if (has_rest) restsym = symbol;

          lexicals.push_back(symbol);
        };

    Cons::cons_iter<TagPtr> iter(lambda);
    for (auto it = iter.begin(); it != iter.end(); it = ++iter)
      parse(env, it->car);

    if (has_rest && Type::Null(restsym))
      Exception::Raise(env, Exception::EXCEPT_CLASS::PARSE_ERROR,
                       "early end of lambda list (parse-lambda)", lambda);

    if (lexicals.size() != (Cons::Length(env, lambda) - has_rest))
      Exception::Raise(env, Exception::EXCEPT_CLASS::PARSE_ERROR,
                       ":rest should terminate lambda list (parse-lambda)",
                       lambda);

    /* think: return pair */
    // return std::pair<TagPtr, size_t>{Type::NIL, 0};

    /** * ((lexicals...) . restsym) */
    return Cons(Cons::List(env, lexicals), restsym)
        .Evict(env, "lambda:parse-lambda");
  };

  auto lambda = parse_lambda(env, Cons::car(form));

  auto fn = Function(env, Type::NIL, std::vector<Frame*>{}, lambda,
                     Cons(lambda, Type::NIL).tag_)
                .Evict(env, "compiler::compile-lambda");

  if (Function::arity(fn)) env->lexenv_.push_back(fn);

  Function::form(fn, Cons(lambda, List(env, Cons::cdr(form)))
                         .Evict(env, "compiler::compile-lambda"));

  if (Function::arity(fn)) env->lexenv_.pop_back();

  return fn;
}

/** * (:defsym symbol form) **/
auto DefSymbol(Env* env, TagPtr form) {
  if (Cons::Length(env, form) != 3)
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     ":defsym: argument count(2)", form);

  auto args = Cons::cdr(form);
  auto sym = Cons::Nth(args, 0);
  auto expr = Cons::Nth(args, 1);

  if (!Symbol::IsType(sym))
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     "is not a symbol (:defsym)", sym);

  if (Symbol::IsKeyword(sym))
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     "can't bind keywords (:defsym)", sym);

  if (Symbol::IsBound(sym))
    Exception::Raise(env, Exception::EXCEPT_CLASS::CELL_ERROR,
                     "symbol previously bound (:defsym)", sym);

  auto value = Eval(env, Compile(env, expr));
  (void)Symbol::Bind(sym, value);

  if (Function::IsType(value)) Function::name(value, sym);

  return Cons::List(env, std::vector<TagPtr>{Symbol::Keyword("quote"), sym});
}

/** * (:lambda list . body) **/
auto DefLambda(Env* env, TagPtr form) {
  if (Cons::Length(env, form) == 1)
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     ":lambda: argument count(1*)", form);

  auto args = Cons::cdr(form);
  auto lambda = Cons::Nth(args, 0);

  if (!Cons::IsList(lambda))
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR, ":lambda",
                     lambda);

  assert(!Type::Eq(Cons::car(lambda), Symbol::Keyword("quote")));

  return Lambda(env, args);
}

/** * (:macro list . body) **/
auto DefMacro(Env* env, TagPtr form) {
  if (Cons::Length(env, form) == 1)
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     ":macro: argument count(1*)", form);

  auto args = Cons::cdr(form);
  auto lambda = Cons::Nth(args, 0);

  if (!Cons::IsList(lambda))
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR, ":macro",
                     lambda);

  assert(!Type::Eq(Cons::car(lambda), Symbol::Keyword("quote")));

  return Macro(Lambda(env, args)).Evict(env, "macro");
}

/** * (:letq symbol expr) **/
auto Letq(Env* env, TagPtr form) {
  if (Cons::Length(env, form) != 3)
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     ":letq: argument count(2)", form);

  auto args = Cons::cdr(form);
  auto sym = Cons::Nth(args, 0);
  auto expr = Cons::Nth(args, 1);

  if (!Symbol::IsType(sym))
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR, ":letq", sym);

  auto lsym = Compile(env, sym);

  if (!Cons::IsList(lsym))
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR, ":letq", lsym);

  auto letq = Namespace::FindInInterns(env, env->mu_, String(env, "letq").tag_);
  assert(!Type::Null(letq));

  return Cons::List(
      env, std::vector<TagPtr>{letq, Cons::Nth(lsym, 1), Cons::Nth(lsym, 2),
                               Compile(env, expr)});
}

/** * (:quote object) **/
auto Quote(Env* env, TagPtr form) {
  if (Cons::Length(env, form) != 2)
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     ":quote: argument count(1)", form);

  return form;
}

/** * (:t object object) **/
auto T(Env* env, TagPtr form) {
  if (Cons::Length(env, form) != 3)
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     ":t: argument count(1)", form);

  return form;
}

/** * (:nil object object) **/
TagPtr Nil(Env* env, TagPtr form) {
  if (Cons::Length(env, form) != 3)
    Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     ":nil: argument count(1)", form);

  return form;
}

/** * map keyword to handler **/
static const std::map<TagPtr, std::function<TagPtr(Env*, TagPtr)>> kSpecMap{
    {Symbol::Keyword("defsym"), DefSymbol},
    {Symbol::Keyword("lambda"), DefLambda},
    {Symbol::Keyword("letq"), Letq},
    {Symbol::Keyword("macro"), DefMacro},
    {Symbol::Keyword("quote"), Quote},
    {Symbol::Keyword("t"), T},
    {Symbol::Keyword("nil"), Nil}};

} /* anonymous namespace */

/** * special operator predicate **/
bool IsSpecOp(TagPtr symbol) {
  return Symbol::IsKeyword(symbol) && (kSpecMap.count(symbol) != 0);
}

/** * compile form **/
TagPtr Compile(Env* env, TagPtr form) {
  TagPtr rval;

  switch (Type::TypeOf(form)) {
    case SYS_CLASS::CONS: { /* funcall/macro call/special call */
      auto fn = Cons::car(form);

      switch (Type::TypeOf(fn)) {
        case SYS_CLASS::CONS: /* fn is list form */
          rval = List(env, form);
          break;
        case SYS_CLASS::SYMBOL: { /* funcall/macro call/special call */
          TagPtr lfn;

          std::tie(lfn, std::ignore) = LexicalEnv(env, fn);
          if (Function::IsType(lfn))
            rval = List(env, form);
          else if (Function::IsType(Macro::MacroFunction(env, fn)))
            rval = Compile(env, Macro::MacroExpand(env, form));
          else if (IsSpecOp(fn))
            rval = kSpecMap.at(fn)(env, form);
          else
            rval = List(env, form);

          break;
        }
        case SYS_CLASS::FUNCTION: /* function */
          rval = List(env, form);
          break;
        default:
          Exception::Raise(env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                           "compile: function type", fn);
          break;
      }
      break;
    }
    case SYS_CLASS::SYMBOL: {
      TagPtr fn;
      size_t offset;

      std::tie<TagPtr, size_t>(fn, offset) = LexicalEnv(env, form);

      rval =
          Function::IsType(fn)
              ? Compile(
                    env,
                    Cons::List(
                        env,
                        std::vector<TagPtr>{
                            Namespace::FindInInterns(
                                env, env->mu_, String(env, "frame-ref").tag_),
                            Function::frame_id(fn), Fixnum(offset).tag_}))
              : form;
      break;
    }
    default: /* constant */
      rval = form;
      break;
  }

  return rval;
}

} /* namespace core */
} /* namespace libmu */
