/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2020 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  compiler.h: library form compiler
 **
 **/
#if !defined(_LIBMU_COMPILER_H_)
#define _LIBMU_COMPILER_H_

#include <cassert>

#include "libmu/env.h"
#include "libmu/type.h"

#include "libmu/types/cons.h"

namespace libmu {
namespace core {

TagPtr Compile(Env*, TagPtr);
bool IsSpecOp(TagPtr);

constexpr auto lexicals(TagPtr lambda) {
  assert(Cons::IsList(lambda));

  return Cons::car(lambda);
}

constexpr auto restsym(TagPtr lambda) {
  assert(Cons::IsList(lambda));

  return Cons::cdr(lambda);
}

} /* namespace core */
} /* namespace libmu */

#endif /* _LIBMU_COMPILER_H_ */
