///|
pub fn VM1::new() -> VM1 {
  { global_env: Env::new() }
}

///|
pub fn VM1::eval(self : VM1, expr : @syntax.Expr) -> Value raise Cont {
  eval(expr, self.global_env)
}

///|
pub fn VM1::eval_top(self : VM1, expr : @syntax.Expr) -> Value raise Cont {
  let env = self.global_env
  match expr {
    Let(pattern~, expr~, body~, ..) => {
      let val = eval(expr, env)
      guard bind_pattern(pattern, val) is Some(binds)
      for bind in binds {
        env.define_var(bind.0, bind.1)
      }
      self.eval_top(body)
    }
    LetMut(binder~, expr~, body~, ..) => {
      env.define_var(binder.name, eval(expr, env))
      self.eval_top(body)
    }
    LetAnd(loc~, ..) => not_support(loc) // TODO
    LetFn(name~, func~, body~, ..) => {
      let name = name.name
      env.define_var(name, eval_func(func, env))
      self.eval_top(body)
    }
    LetRec(bindings~, body~, ..) => {
      for bind in bindings {
        env.define_var(bind.0.name, eval_func(bind.1, env))
      }
      self.eval_top(body)
    }
    _ => self.eval(expr)
  }
}
