///|
fn @syntax.Parameter::loc(self : @syntax.Parameter) -> @basic.Location {
  match self {
    Optional(binder~, ..)
    | Labelled(binder~, ..)
    | Positional(binder~, ..)
    | QuestionOptional(binder~, ..) => binder.loc
    DiscardPositional(loc~, ..) => loc
  }
}

///|
fn[A] VM1::panic(loc : @basic.Location, msg~ : String = "") -> A raise Cont {
  raise Panic(loc, msg~)
}

///|
#callsite(autofill(source))
pub fn[A] not_support(
  loc : @basic.Location,
  source~ : SourceLoc,
) -> A raise Cont {
  VM1::panic(loc, msg="not support at (\{source})")
}

///|
fnalias not_support as not_support_record

///|
fnalias not_support as not_support_control
