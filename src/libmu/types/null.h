/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2021 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  null.h: null class
 **
 **/
#if !defined(LIBMU_TYPES_NULL_H_)
#define LIBMU_TYPES_NULL_H_

#include <cassert>
#include <functional>
#include <map>
#include <vector>

#include "libmu/env.h"
#include "libmu/type.h"

namespace libmu {
namespace core {

/** * address class type **/
class Null : public Type {
 public: /* Tag */


  static auto ViewOf(Env* env, Tag addr) {
    assert(IsType(addr));

    auto view = std::vector<Tag>{
        Symbol::Keyword("address"),
        addr,
        Fixnum(ToUint64(addr)).tag_,
    };

    return Vector(env, view).tag_;
  }

 public: /* object model */
  static constexpr bool IsType(Tag ptr) { return TagOf(ptr) == TAG::ADDRESS; }
  SYS_CLASS SysClass() { return SYS_CLASS::NULL; }
  Tag Evict(Env*) { return tag_; }

  explicit Null() : Type() { tag_ = NIL; }

}; /* class Null */

} /* namespace core */
} /* namespace libmu */

#endif /* LIBMU_TYPES_ADDRESS_H_ */
