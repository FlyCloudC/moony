///|
fn[A, B] @list.List::map_to_array(
  self : Self[A],
  f : (A) -> B raise?,
) -> Array[B] raise? {
  let res = []
  self.each(x => res.push(f(x)))
  res
}

///|
fn[A] Array::resize_down(self : Array[A], new_len : Int) -> Unit {
  while self.length() > new_len {
    self.unsafe_pop() |> ignore
  }
}

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
fn[A] VM1::panic(loc : @basic.Location, msg? : String = "") -> A raise Cont {
  raise Panic(loc, msg~)
}

///|
#callsite(autofill(source))
fn[A] not_support(loc? : @basic.Location, source~ : SourceLoc) -> A {
  let msg = match loc {
    None => "not support at\n  \{source}\n"
    Some(loc) => "not support at\n  \{source}\n \{loc}\n"
  }
  println(msg)
  panic()
}
