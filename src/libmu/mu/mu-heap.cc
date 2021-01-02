/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2021 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  mu-heap.cc: mu heap functions
 **
 **/
#include <cassert>
#include <numeric>

#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include "libmu/platform/platform.h"

#include "libmu/print.h"
#include "libmu/type.h"

#include "libmu/heap/heap.h"
#include "libmu/types/exception.h"

namespace libmu {
namespace mu {

using Exception = core::Exception;
using Fixnum = core::Fixnum;
using Frame = core::Env::Frame;
using Type = core::Type;

/** * (gc bool) => fixnum **/
void Gc(Frame* fp) {
  auto arg = fp->argv[0];

  switch (arg) {
    case Type::NIL:
    case Type::T:
      break;
    default:
      Exception::Raise(fp->env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                       "is not boolean (gc)", arg);
  }

  fp->value = core::Fixnum(fp->env->Gc(fp->env)).tag_;
}

/** * mu function (heap-info type) => vector **/
void HeapInfo(Frame* fp) {
  auto type = fp->argv[0];

  if (!core::Symbol::IsKeyword(type) || !Type::IsClassSymbol(type))
    Exception::Raise(fp->env, Exception::EXCEPT_CLASS::TYPE_ERROR,
                     "is not a system class keyword (heap-info)", type);

  std::function<Type::Tag(Type::SYS_CLASS, int)> type_vec =
      [fp](Type::SYS_CLASS sys_class, int size) {
        return core::Vector(
                   fp->env,
                   std::vector<Type::Tag>{
                       Fixnum(-1).tag_, /* figure out per object size */
                       Fixnum(size).tag_,
                       Fixnum(fp->env->heap_->nalloc_->at(
                                  static_cast<int>(sys_class)))
                           .tag_,
                       Fixnum(fp->env->heap_->nfree_->at(
                                  static_cast<int>(sys_class)))
                           .tag_})
            .tag_;
      };

  /** * immediates return :nil */
  auto sys_class = Type::MapSymbolClass(type);
  switch (sys_class) {
    case Type::SYS_CLASS::BYTE:
    case Type::SYS_CLASS::CHAR:
    case Type::SYS_CLASS::FIXNUM:
    case Type::SYS_CLASS::FLOAT:
      fp->value = Type::NIL;
      break;
    case Type::SYS_CLASS::T:
      fp->value =
          core::Vector(
              fp->env,
              std::vector<Type::Tag>{
                  Fixnum(fp->env->heap_->size()).tag_,
                  Fixnum(fp->env->heap_->alloc()).tag_,
                  Fixnum(std::accumulate(fp->env->heap_->nalloc_->begin(),
                                         fp->env->heap_->nalloc_->end(), 0))
                      .tag_,
                  Fixnum(std::accumulate(fp->env->heap_->nfree_->begin(),
                                         fp->env->heap_->nfree_->end(), 0))
                      .tag_})
              .tag_;
      break;
    default:
      fp->value = type_vec(sys_class, fp->env->heap_->room(sys_class));
      break;
  }
}

} /* namespace mu */
} /* namespace libmu */
