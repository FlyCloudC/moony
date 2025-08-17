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
fn VM1::run(self : VM1, code : String) -> Value raise {
  let expr = parse_expr(code)
  let env = self.0
  match expr {
    Let(pattern~, expr~, body~, ..) => {
      let val = self.eval(expr, env)
      guard VM1::bind_pattern(pattern, val) is Some(binds)
      self.eval(body, env.extend_inplace(binds))
    }
    LetMut(binder~, expr~, body~, ..) => {
      let val = self.eval(expr, env)
      self.eval(body, env.extend_inplace([(binder.name, val)]))
    }
    LetAnd(loc~, ..) => not_support(loc) // TODO
    LetFn(name~, func~, body~, ..) => {
      let name = name.name
      let new_env = env.extend_inplace([(name, Unit)])
      new_env[name] = VM1::eval_func(func, new_env)
      self.eval(body, new_env)
    }
    LetRec(bindings~, body~, ..) => {
      let empty_bindings = []
      for bind in bindings {
        empty_bindings.push((bind.0.name, Unit))
      }
      let new_env = env.extend_inplace(empty_bindings)
      for bind in bindings {
        new_env[bind.0.name] = VM1::eval_func(bind.1, new_env)
      }
      self.eval(body, new_env)
    }
    _ => self.eval(expr, self.0)
  }
}

///|
test {
  let vm = VM1::new()
  inspect(vm.run("let a = 1"), content="()")
  inspect(vm.run("a"), content="1")
  inspect(vm.run("a + a"), content="2")
  inspect(
    vm.run("fn fact(n : Int) { if n == 0 { 1 } else { n * fact(n - 1) } }"),
    content="()",
  )
  inspect(vm.run("fact(3)"), content="6")
}
