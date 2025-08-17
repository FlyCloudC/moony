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
fn[A] VM1::panic(loc : @basic.Location, msg~ : String = "") -> A raise Cont {
  raise Panic(loc, msg~)
}

///|
#callsite(autofill(source))
fn[A] not_support(loc : @basic.Location, source~ : SourceLoc) -> A {
  println("not support at (\{source}) (\{loc})")
  panic()
}

///|
#callsite(autofill(source))
fn[A] not_impl(loc : @basic.Location, source~ : SourceLoc) -> A {
  println("not impl at (\{source}) (\{loc})")
  panic()
}

///|
fnalias not_impl as not_impl_record

///|
fn parse_expr(code : String) -> @syntax.Expr raise {
  let buf = @buffer.new()
  @encoding.encode_to("fn init {\n\{code}\n}", buf, encoding=UTF8)
  let (impls, diagnostics) = @parser.parse_bytes(
    buf.to_bytes(),
    parser=Handrolled,
  )
  guard impls is More(TopFuncDef(decl_body=DeclBody(expr~, ..), ..), tail=Empty) else {
    fail(diagnostics.fold(init="", (acc, cur) => "\{acc}\n\{cur}"))
  }
  expr
}

///|
pub fn VM1::run(self : VM1, code : String) -> Value raise Cont {
  let expr = try! parse_expr(code)
  let env = self.0
  match expr {
    Let(pattern~, expr~, body~, ..) => {
      let val = self.eval(expr, env)
      guard VM1::bind_pattern(pattern, val) is Some([bind])
      env.table[bind.0] = val
      self.eval(body, env)
    }
    LetMut(binder~, expr~, body~, ..) => {
      env.table[binder.name] = self.eval(expr, env)
      self.eval(body, env)
    }
    LetAnd(loc~, ..) => not_support(loc) // TODO
    LetFn(name~, func~, body~, ..) => {
      let name = name.name
      env.table[name] = VM1::eval_func(func, env)
      self.eval(body, env)
    }
    LetRec(bindings~, body~, ..) => {
      for bind in bindings {
        env.table[bind.0.name] = VM1::eval_func(bind.1, env)
      }
      self.eval(body, env)
    }
    _ => self.eval(expr, self.0)
  }
}
