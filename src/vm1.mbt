///|
pub struct VM1(Env)

///|
pub fn VM1::new() -> VM1 {
  VM1(Env::new())
}

///|
suberror Cont {
  Raise(Value)
  Panic(@basic.Location, msg~ : String)
} derive(Show)

///|
fn VM1::bind_pattern(
  pattern : @syntax.Pattern,
  value : Value,
) -> Array[(String, Value)]? raise Cont {
  let binds = []
  fn acc(pat : @syntax.Pattern, value : Value) -> Bool raise Cont {
    match pat {
      Var(binder) => {
        binds.push((binder.name, value))
        true
      }
      Alias(pat~, alias_~, ..) => {
        binds.push((alias_.name, value))
        acc(pat, value)
      }
      Tuple(pats~, ..) => {
        guard value is Tuple(vals) else { false }
        for i, pat in pats {
          guard acc(pat, vals[i]) else { break false }
        } else {
          true
        }
      }
      Any(_) => true
      Or(pat1~, pat2~, ..) => {
        let len_before = binds.length()
        acc(pat1, value) ||
        {
          binds.resize_down(len_before)
          acc(pat2, value)
        }
      }
      Constraint(pat~, ..) => acc(pat, value)
      Constant(c~, loc~) => Value::from_constant(c, loc) == value
      Record(loc~, ..) => not_impl_record(loc)
      Array(loc~, ..) => not_impl(loc)
      Constr(loc~, ..) => not_impl(loc)
      Map(loc~, ..) => not_impl(loc)
      Range(loc~, ..) => not_support(loc)
    }
  }

  if acc(pattern, value) {
    Some(binds)
  } else {
    None
  }
}

///|
fn VM1::match_(
  self : VM1,
  cases : @list.List[@syntax.Case],
  val : Value,
  env : Env,
  loc : @basic.Location,
) -> (@syntax.Expr, Env) raise Cont {
  for case in cases {
    if VM1::bind_pattern(case.pattern, val) is Some(binds) {
      let new_env = env.extend(binds)
      if case.guard_ is Some(guard_) && !(self.eval(guard_, new_env) is True) {
        continue
      } else {
        break (case.body, new_env)
      }
    }
  } else {
    VM1::panic(loc, msg="match fail")
  }
}

///|
fn VM1::eval_interp(
  self : VM1,
  interp : @list.List[@syntax.InterpElem],
  env : Env,
) -> String raise Cont {
  let res = []
  for e in interp {
    let s = match e {
      Literal(repr~, ..) => repr
      Expr(expr~, ..) => self.eval(expr, env).to_string()
      // TODO
      Source(_) => panic()
    }
    res.push(s)
  }
  res.join("")
}

///|
pub fn VM1::eval_func(func : @syntax.Func, env : Env) -> Value {
  match func {
    Lambda(parameters~, body~, is_async=false, ..) =>
      Func(
        name=None,
        arg_names=parameters.map_to_array(p => {
          guard p is Positional(binder~, ..) else { not_support(p.loc()) }
          binder.name
        }),
        body~,
        saved_env=env,
      )
    Lambda(is_async=true, loc~, ..) | Match(loc~, ..) => not_support(loc)
  }
}

///|
pub fn VM1::eval_unary(op_name : String, val : Value) -> Value {
  match op_name {
    "-" =>
      match val {
        Int(a) => Int(-a)
        Double(a) => Double(-a)
        _ => panic()
      }
    "!" =>
      match val {
        True => False
        False => True
        _ => panic()
      }
    _ => panic()
  }
}

///|
fn VM1::eval_infix(op_name : String, lhs : Value, rhs : Value) -> Value {
  match op_name {
    // cmp
    "==" => Value::bool(lhs == rhs)
    "!=" => Value::bool(lhs != rhs)
    "<" => Value::bool(lhs < rhs)
    ">" => Value::bool(lhs > rhs)
    "<=" => Value::bool(lhs <= rhs)
    ">=" => Value::bool(lhs >= rhs)
    // arith
    "+" => lhs + rhs
    "-" => lhs - rhs
    "*" => lhs * rhs
    "/" => lhs / rhs
    "%" => lhs % rhs
    // bit
    "&" => lhs & rhs
    "|" => lhs | rhs
    "^" => lhs ^ rhs
    ">>" if rhs is Int(rhs) => lhs >> rhs
    "<<" if rhs is Int(rhs) => lhs << rhs
    _ => panic()
  }
}

///|
pub fn VM1::eval(
  self : VM1,
  expr : @syntax.Expr,
  env : Env,
) -> Value raise Cont {
  match expr {
    // Constant
    Unit(_) => Unit
    Constant(c~, loc~) => Value::from_constant(c, loc)

    // Interp
    Interp(elems~, ..) => String(self.eval_interp(elems, env))
    MultilineString(elems=lines, ..) =>
      lines
      .map_to_array(line => match line {
        String(s) => s
        Interp(i) => self.eval_interp(i, env)
      })
      .join("\n")
      |> String

    // Construct
    Tuple(exprs~, ..) => Tuple(exprs.map_to_array(expr => self.eval(expr, env)))
    Array(exprs~, ..) => Array(exprs.map_to_array(expr => self.eval(expr, env)))
    Function(func~, ..) => VM1::eval_func(func, env)
    Record(loc~, ..) => not_impl_record(loc)
    RecordUpdate(loc~, ..) => not_impl_record(loc)
    ArraySpread(loc~, ..) => not_support(loc)
    Constr(loc~, ..) => not_support(loc)
    Map(loc~, ..) => not_support(loc)
    As(loc~, ..) => not_support(loc)

    // Bind
    Ident(id~, ..) => {
      guard id.name is Ident(name~)
      env[name]
    }
    Assign(var_~, expr~, augmented_by~, loc~) => {
      guard augmented_by is None else { not_support(loc) }
      guard var_.name is Ident(name~) else { not_support(loc) }
      env[name] = self.eval(expr, env)
      Unit
    }
    Let(pattern~, expr~, body~, ..) => {
      let val = self.eval(expr, env)
      guard VM1::bind_pattern(pattern, val) is Some(binds)
      self.eval(body, env.extend(binds))
    }
    LetMut(binder~, expr~, body~, ..) => {
      let val = self.eval(expr, env)
      self.eval(body, env.extend([(binder.name, val)]))
    }
    LetAnd(loc~, ..) => not_support(loc) // TODO
    LetFn(name~, func~, body~, ..) => {
      let name = name.name
      let new_env = env.extend_new()
      new_env.table[name] = VM1::eval_func(func, new_env)
      self.eval(body, new_env)
    }
    LetRec(bindings~, body~, ..) => {
      let new_env = env.extend_new()
      for bind in bindings {
        new_env.table[bind.0.name] = VM1::eval_func(bind.1, new_env)
      }
      self.eval(body, new_env)
    }

    // Branch
    If(cond~, ifso~, ifnot~, ..) =>
      if self.eval(cond, env) is True {
        self.eval(ifso, env)
      } else if ifnot is Some(ifnot) {
        self.eval(ifnot, env)
      } else {
        Unit
      }
    Match(expr~, cases~, match_loc~, ..) => {
      let val = self.eval(expr, env)
      let (body, new_env) = self.match_(cases, val, env, match_loc)
      self.eval(body, new_env)
    }

    // Block Control
    Guard(cond~, otherwise~, body~, loc~) =>
      if self.eval(cond, env) is True {
        self.eval(body, env)
      } else if otherwise is Some(otherwise) {
        self.eval(otherwise, env)
      } else {
        VM1::panic(loc, msg="guard fail")
      }
    Defer(expr~, body~, ..) =>
      try self.eval(body, env) catch {
        Panic(_) as e => raise e
        e => {
          // guard self.eval(expr, env) is Unit
          self.eval(expr, env) |> ignore
          raise e
        }
      } noraise {
        _ => self.eval(expr, env)
      }

    // Call
    Apply(func~, args~, ..) => {
      guard self.eval(func, env) is Func(arg_names~, saved_env~, body~, ..)
      let new_env = saved_env.extend_new()
      for i, arg in args {
        guard arg.kind is Positional else { not_support(arg.value.loc()) }
        new_env.table[arg_names[i]] = self.eval(arg.value, env)
      }
      self.eval(body, new_env)
    }
    DotApply(loc~, ..) => not_support(loc)
    Unary(op~, expr~, ..) => {
      guard op.name is Ident(name~)
      VM1::eval_unary(name, self.eval(expr, env))
    }
    Infix(op~, lhs~, rhs~, ..) => {
      guard op.name is Ident(name~)
      match name {
        "&&" =>
          if self.eval(lhs, env) is True {
            self.eval(rhs, env)
          } else {
            False
          }
        "||" =>
          if self.eval(lhs, env) is True {
            True
          } else {
            self.eval(rhs, env)
          }
        _ => VM1::eval_infix(name, self.eval(lhs, env), self.eval(rhs, env))
      }
    }
    ArrayGet(array~, index~, loc~) => {
      guard self.eval(array, env) is Array(array)
      guard self.eval(index, env) is Int(index)
      match array.get(index) {
        None =>
          VM1::panic(loc, msg="out of bound, i=\{index}, len=\{array.length()}")
        Some(v) => v
      }
    }
    ArraySet(array~, index~, value~, loc~) => {
      guard self.eval(array, env) is Array(array)
      guard self.eval(index, env) is Int(index)
      let len = array.length()
      guard 0 <= index && index < len else {
        VM1::panic(loc, msg="out of bound, i=\{index}, len=\{array.length()}")
      }
      array[index] = self.eval(value, env)
      Unit
    }
    ArrayGetSlice(loc~, ..) => not_impl(loc)
    ArrayAugmentedSet(loc~, ..) => not_impl(loc)
    Mutate(loc~, ..) => not_impl_record(loc)
    Field(record~, accessor~, loc~) =>
      match accessor {
        Index(tuple_index~, ..) => {
          guard self.eval(record, env) is Tuple(tuple)
          tuple[tuple_index]
        }
        Label(_) => not_impl_record(loc)
        Newtype(_) => not_support(loc)
      }

    // Compose
    Group(expr~, ..) => self.eval(expr, env)
    Constraint(expr~, ..) => self.eval(expr, env)
    Sequence(exprs~, ..) => {
      guard exprs is More(expr, tail~) else { Unit }
      loop (expr, tail) {
        (expr, Empty) => self.eval(expr, env)
        (expr, More(expr_, tail~)) => {
          // guard self.eval(expr, env) is Unit
          self.eval(expr, env) |> ignore
          continue (expr_, tail)
        }
      }
    }

    // Exception
    Raise(err_value~, ..) => raise Raise(self.eval(err_value, env))
    Try(body~, catch_~, catch_all~, catch_loc~, try_else~, else_loc~, loc~, ..) => {
      guard catch_all else { not_support(loc) }
      try self.eval(body, env) catch {
        Raise(exc) => {
          let (body, new_env) = self.match_(catch_, exc, env, catch_loc)
          self.eval(body, new_env)
        }
        Panic(_) as e => raise e
      } noraise {
        val => {
          guard try_else is Some(try_else) else { val }
          let (body, new_env) = self.match_(try_else, val, env, else_loc)
          self.eval(body, new_env)
        }
      }
    }
    TryOperator(body~, kind~, loc~, ..) =>
      match kind {
        Question =>
          Constr("Ok", [self.eval(body, env)]) catch {
            Raise(exc) => Constr("Err", [exc])
            Panic(_) as e => raise e
          }
        Exclamation =>
          self.eval(body, env) catch {
            Raise(_) => VM1::panic(loc)
            Panic(_) as e => raise e
          }
      }

    // Loop
    // use recursion instead
    ForEach(loc~, ..) => not_support(loc)
    For(loc~, ..) => not_support(loc)
    Loop(loc~, ..) => not_support(loc)
    While(loc~, ..) => not_support(loc)

    // Control
    Continue(loc~, ..) => not_support(loc)
    Break(loc~, ..) => not_support(loc)
    Return(loc~, ..) => not_support(loc)

    // Top Define
    Method(loc~, ..) => not_support(loc)

    // Other
    Pipe(loc~, ..) => not_support(loc)
    Is(loc~, ..) => not_support(loc)
    Hole(loc~, ..) => not_support(loc)
    StaticAssert(body~, ..) => self.eval(body, env)
  }
}
