/********
 **
 **  SPDX-License-Identifier: MIT
 **
 **  Copyright (c) 2017-2021 James M. Putnam <putnamjm.design@gmail.com>
 **
 **/

/********
 **
 **  char.h: library characters
 **
 **/
#if !defined(LIBMU_TYPES_CHAR_H_)
#define LIBMU_TYPES_CHAR_H_

#include <cassert>

#include "libmu/type.h"

namespace libmu {
namespace core {

using Tag = core::Type::Tag;

/** * character type class **/
class Char : public Type {
 public: /* tag */
  static constexpr bool IsType(Tag ptr) {
    return IsImmediate(ptr) && (ImmediateClass(ptr) == IMMEDIATE_CLASS::CHAR);
  }

  static constexpr uint8_t Uint8Of(Tag ptr) {
    assert(Char::IsType(ptr));

    return static_cast<uint8_t>(ImmediateData(ptr));
  }

  static float VSpecOf(Tag ch) { return Uint8Of(ch); }
  static void Print(Env*, Tag, Tag, bool);
  static Tag Read(Env*, Tag);
  static Tag ViewOf(Env*, Tag);

 public: /* type object model */
  auto SysClass() -> SYS_CLASS { return SYS_CLASS::CHAR; }
  auto Evict(Env*) -> Tag { return tag_; }

  explicit Char(uint8_t ch) : Type() {
    tag_ = MakeImmediate(ch, 0, IMMEDIATE_CLASS::CHAR);
  }

}; /* class Char */

} /* namespace core */
} /* namespace libmu */

#endif /* LIBMU_TYPES_CHAR_H_ */
