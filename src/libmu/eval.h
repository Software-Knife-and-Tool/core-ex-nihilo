/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2021 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  eval.h: eval/apply
 **
 **/
#if !defined(LIBMU_EVAL_H_)
#define LIBMU_EVAL_H_

#include <cassert>
#include <cinttypes>
#include <functional>
#include <map>
#include <string>
#include <utility>
#include <vector>

#include "libmu/env.h"
#include "libmu/type.h"

namespace libmu {
namespace core {

using Tag = Type::Tag;

Type& Apply(Env*, Type&, Type&);
Tag Eval(Env*, Tag);

} /* namespace core */
} /* namespace libmu */

#endif /* LIBMU_EVAL_H_ */
