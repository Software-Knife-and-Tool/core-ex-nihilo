/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2021 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  read.h: libmu reader
 **
 **/
#if !defined(LIBMU_READ_H_)
#define LIBMU_READ_H_

#include <cassert>
#include <map>
#include <utility>
#include <vector>

#include "libmu/env.h"
#include "libmu/readtable.h"
#include "libmu/type.h"

#include "libmu/types/char.h"

namespace libmu {
namespace core {

Tag Read(Env*, Tag);
Tag ReadForm(Env*, Tag);
bool ReadWSUntilEof(Env*, Tag);

} /* namespace core */
} /* namespace libmu */

#endif /* LIBMU_READ_H_ */
