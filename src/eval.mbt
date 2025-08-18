///|
pub struct VM1 {
  global_env : Env
}

///|
pub fn VM1::new() -> VM1 {
  { global_env: Env::new() }
}

///|
pub suberror Cont {
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
        guard value is Tuple(vals)
        for i, pat in pats {
          guard acc(pat, vals[i]) else { break false }
        } else {
          true
        }
      }
      Constr(constr~, args~, ..) => {
        guard value is Enum(name, vals)
        guard constr.name.name == name else { false }
        guard args is Some(args) else { true }
        for i, pat in args {
          guard acc(pat.pat, vals[i]) else { break false }
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
fn match_(
  cases : @list.List[@syntax.Case],
  val : Value,
  env : Env,
  loc : @basic.Location,
) -> (@syntax.Expr, Env) raise Cont {
  for case in cases {
    if VM1::bind_pattern(case.pattern, val) is Some(binds) {
      let new_env = env.extend(binds)
      if case.guard_ is Some(guard_) && !(eval(guard_, new_env) is True) {
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
fn eval_interp(
  interp : @list.List[@syntax.InterpElem],
  env : Env,
) -> String raise Cont {
  let res = []
  for e in interp {
    let s = match e {
      Literal(repr~, ..) => repr
      Expr(expr~, ..) => eval(expr, env).to_string()
      // TODO
      Source(_) => panic()
    }
    res.push(s)
  }
  res.join("")
}

///|
fn VM1::eval_func(func : @syntax.Func, env : Env) -> Value {
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
fn VM1::eval_unary(op_name : String, val : Value) -> Value {
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
fn VM1::eval_infix(op_name : @string.View, lhs : Value, rhs : Value) -> Value {
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
pub fn eval(expr : @syntax.Expr, env : Env) -> Value raise Cont {
  match expr {
    // Constant
    Unit(_) => Unit
    Constant(c~, loc~) => Value::from_constant(c, loc)

    // Interp
    Interp(elems~, ..) => String(eval_interp(elems, env))
    MultilineString(elems=lines, ..) =>
      lines
      .map_to_array(line => match line {
        String(s) => s
        Interp(i) => eval_interp(i, env)
      })
      .join("\n")
      |> String

    // Construct
    Tuple(exprs~, ..) => Tuple(exprs.map_to_array(expr => eval(expr, env)))
    Array(exprs~, ..) => Array(exprs.map_to_array(expr => eval(expr, env)))
    Function(func~, ..) => VM1::eval_func(func, env)
    Record(loc~, ..) => not_impl_record(loc)
    RecordUpdate(loc~, ..) => not_impl_record(loc)
    ArraySpread(loc~, ..) => not_support(loc)
    Constr(constr~, ..) => Enum(constr.name.name, [])
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
      env[name] = eval(expr, env)
      Unit
    }
    Let(pattern~, expr~, body~, ..) => {
      let val = eval(expr, env)
      guard VM1::bind_pattern(pattern, val) is Some(binds)
      eval(body, env.extend(binds))
    }
    LetMut(binder~, expr~, body~, ..) => {
      let val = eval(expr, env)
      eval(body, env.extend([(binder.name, val)]))
    }
    LetAnd(loc~, ..) => not_support(loc) // TODO
    LetFn(name~, func~, body~, ..) => {
      let name = name.name
      let new_env = env.extend_new()
      new_env.table[name] = VM1::eval_func(func, new_env)
      eval(body, new_env)
    }
    LetRec(bindings~, body~, ..) => {
      let new_env = env.extend_new()
      for bind in bindings {
        new_env.table[bind.0.name] = VM1::eval_func(bind.1, new_env)
      }
      eval(body, new_env)
    }

    // Branch
    If(cond~, ifso~, ifnot~, ..) =>
      if eval(cond, env) is True {
        eval(ifso, env)
      } else if ifnot is Some(ifnot) {
        eval(ifnot, env)
      } else {
        Unit
      }
    Match(expr~, cases~, match_loc~, ..) => {
      let val = eval(expr, env)
      let (body, new_env) = match_(cases, val, env, match_loc)
      eval(body, new_env)
    }

    // Block Control
    Guard(cond~, otherwise~, body~, loc~) =>
      if eval(cond, env) is True {
        eval(body, env)
      } else if otherwise is Some(otherwise) {
        eval(otherwise, env)
      } else {
        VM1::panic(loc, msg="guard fail")
      }
    Defer(expr~, body~, ..) =>
      try eval(body, env) catch {
        Panic(_) as e => raise e
        e => {
          // guard eval(expr, env) is Unit
          eval(expr, env) |> ignore
          raise e
        }
      } noraise {
        _ => eval(expr, env)
      }

    // Call
    Apply(func=Constr(constr~, ..), args~, ..) =>
      args.map_to_array(arg => {
        guard arg.kind is Positional else { not_support(arg.value.loc()) }
        eval(arg.value, env)
      })
      |> Enum(constr.name.name, _)
    Apply(func~, args~, ..) => {
      guard eval(func, env) is Func(arg_names~, saved_env~, body~, ..)
      let new_env = saved_env.extend_new()
      for i, arg in args {
        guard arg.kind is Positional else { not_support(arg.value.loc()) }
        new_env.table[arg_names[i]] = eval(arg.value, env)
      }
      eval(body, new_env)
    }
    DotApply(loc~, ..) => not_support(loc)
    Unary(op~, expr~, ..) => {
      guard op.name is Ident(name~)
      VM1::eval_unary(name, eval(expr, env))
    }
    Infix(op~, lhs~, rhs~, ..) => {
      guard op.name is Ident(name~)
      match name {
        "&&" => if eval(lhs, env) is True { eval(rhs, env) } else { False }
        "||" => if eval(lhs, env) is True { True } else { eval(rhs, env) }
        _ => VM1::eval_infix(name, eval(lhs, env), eval(rhs, env))
      }
    }
    ArrayGet(array~, index~, loc~) => {
      guard eval(array, env) is Array(array)
      guard eval(index, env) is Int(index)
      match array.get(index) {
        None =>
          VM1::panic(loc, msg="out of bound, i=\{index}, len=\{array.length()}")
        Some(v) => v
      }
    }
    ArraySet(array~, index~, value~, loc~) => {
      guard eval(array, env) is Array(array)
      guard eval(index, env) is Int(index)
      let len = array.length()
      guard 0 <= index && index < len else {
        VM1::panic(loc, msg="out of bound, i=\{index}, len=\{len}")
      }
      array[index] = eval(value, env)
      Unit
    }
    ArrayAugmentedSet(op~, array~, index~, value~, loc~) => {
      guard op.name is Ident(name=[.. name, '='])
      guard eval(array, env) is Array(array)
      guard eval(index, env) is Int(index)
      guard array.get(index) is Some(v) else {
        VM1::panic(loc, msg="out of bound, i=\{index}, len=\{array.length()}")
      }
      array[index] = VM1::eval_infix(name, v, eval(value, env))
      Unit
    }
    ArrayGetSlice(loc~, ..) => not_impl(loc)
    Mutate(loc~, ..) => not_impl_record(loc)
    Field(record~, accessor~, loc~) =>
      match accessor {
        Index(tuple_index~, ..) => {
          guard eval(record, env) is Tuple(tuple)
          tuple[tuple_index]
        }
        Label(_) => not_impl_record(loc)
        Newtype(_) => not_support(loc)
      }

    // Compose
    Group(expr~, ..) => eval(expr, env)
    Constraint(expr~, ..) => eval(expr, env)
    Sequence(exprs~, ..) => {
      guard exprs is More(expr, tail~) else { Unit }
      loop (expr, tail) {
        (expr, Empty) => eval(expr, env)
        (expr, More(expr_, tail~)) => {
          // guard eval(expr, env) is Unit
          eval(expr, env) |> ignore
          continue (expr_, tail)
        }
      }
    }

    // Exception
    Raise(err_value~, ..) => raise Raise(eval(err_value, env))
    Try(body~, catch_~, catch_all~, catch_loc~, try_else~, else_loc~, loc~, ..) => {
      guard catch_all else { not_support(loc) }
      try eval(body, env) catch {
        Raise(exc) => {
          let (body, new_env) = match_(catch_, exc, env, catch_loc)
          eval(body, new_env)
        }
        Panic(_) as e => raise e
      } noraise {
        val => {
          guard try_else is Some(try_else) else { val }
          let (body, new_env) = match_(try_else, val, env, else_loc)
          eval(body, new_env)
        }
      }
    }
    TryOperator(body~, kind~, loc~, ..) =>
      match kind {
        Question =>
          Enum("Ok", [eval(body, env)]) catch {
            Raise(exc) => Enum("Err", [exc])
            Panic(_) as e => raise e
          }
        Exclamation =>
          eval(body, env) catch {
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
    StaticAssert(body~, ..) => eval(body, env)
  }
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
      guard VM1::bind_pattern(pattern, val) is Some(binds)
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
      env.define_var(name, VM1::eval_func(func, env))
      self.eval_top(body)
    }
    LetRec(bindings~, body~, ..) => {
      for bind in bindings {
        env.define_var(bind.0.name, VM1::eval_func(bind.1, env))
      }
      self.eval_top(body)
    }
    _ => self.eval(expr)
  }
}
