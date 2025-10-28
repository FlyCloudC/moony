///|
fn eval_interp(
  interp : @list.List[@syntax.InterpElem],
  env : Env,
) -> String raise Cont {
  interp
  .map_to_array(e => match e {
    Literal(repr~, ..) => repr
    Expr(expr~, ..) => eval(expr, env).to_string()
    // TODO
    Source(_) => panic()
  })
  .join("")
}

///|
fn eval_func(func : @syntax.Func, env : Env) -> Value {
  match func {
    Lambda(parameters~, body~, is_async=false, ..) =>
      Func(
        name=None,
        arg_names=parameters.map_to_array(p => {
          guard p is Positional(binder~, ..) else { not_support(loc=p.loc()) }
          binder.name
        }),
        body~,
        saved_env=env,
      )
    Lambda(is_async=true, loc~, ..) | Match(loc~, ..) => not_support(loc~)
  }
}

///|
fn eval_unary(op_name : String, val : Value) -> Value {
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
fn eval_infix(op_name : StringView, lhs : Value, rhs : Value) -> Value {
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
    Constant(c~, loc~) => c.to_value(loc)

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
    Function(func~, ..) => eval_func(func, env)
    Record(fields~, ..) =>
      fields.map(x => (x.label.name, eval(x.expr, env))).iter()
      |> Map::from_iter
      |> Struct
    RecordUpdate(fields~, record~, ..) => {
      guard eval(record, env) is Struct(record)
      let val = record.copy()
      fields.each(x => val[x.label.name] = eval(x.expr, env))
      Struct(val)
    }
    ArraySpread(loc~, ..) => not_support(loc~)
    Constr(constr~, ..) => Enum(constr.name.name, [])
    Map(loc~, ..) => not_support(loc~)
    As(loc~, ..) => not_support(loc~)

    // Bind
    Ident(id~, ..) => {
      guard id.name is Ident(name~)
      env[name]
    }
    Assign(var_~, expr~, augmented_by~, loc~) => {
      guard augmented_by is None else { not_support(loc~) }
      guard var_.name is Ident(name~) else { not_support(loc~) }
      env[name] = eval(expr, env)
      Unit
    }
    Let(pattern~, expr~, body~, ..) => {
      let val = eval(expr, env)
      guard bind_pattern(pattern, val) is Some(binds)
      eval(body, env.extend(binds))
    }
    LetMut(binder~, expr~, body~, ..) => {
      let val = eval(expr, env)
      eval(body, env.extend([(binder.name, val)]))
    }
    LetAnd(bindings~, body~, ..) => {
      let new_env = env.extend_new()
      for bind in bindings {
        new_env.define_var(bind.0.name, eval_func(bind.2, new_env))
      }
      eval(body, new_env)
    }
    LetFn(name~, func~, body~, ..) => {
      let name = name.name
      let new_env = env.extend_new()
      new_env.define_var(name, eval_func(func, new_env))
      eval(body, new_env)
    }
    LetRec(bindings~, body~, ..) => {
      let new_env = env.extend_new()
      for bind in bindings {
        new_env.define_var(bind.0.name, eval_func(bind.1, new_env))
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
        val => {
          eval(expr, env) |> ignore
          val
        }
      }

    // Call
    Apply(func=Constr(constr~, ..), args~, ..) =>
      args.map_to_array(arg => {
        guard arg.kind is Positional else { not_support(loc=arg.value.loc()) }
        eval(arg.value, env)
      })
      |> Enum(constr.name.name, _)
    Apply(func~, args~, ..) => {
      guard eval(func, env) is Func(arg_names~, saved_env~, body~, ..)
      let new_env = saved_env.extend_new()
      for i, arg in args {
        guard arg.kind is Positional else { not_support(loc=arg.value.loc()) }
        new_env.define_var(arg_names[i], eval(arg.value, env))
      }
      eval(body, new_env)
    }
    DotApply(loc~, ..) => not_support(loc~)
    Method(loc~, ..) => not_support(loc~)
    Unary(op~, expr~, ..) => {
      guard op.name is Ident(name~)
      eval_unary(name, eval(expr, env))
    }
    Infix(op~, lhs~, rhs~, ..) => {
      guard op.name is Ident(name~)
      match name {
        "&&" => if eval(lhs, env) is True { eval(rhs, env) } else { False }
        "||" => if eval(lhs, env) is True { True } else { eval(rhs, env) }
        _ => eval_infix(name, eval(lhs, env), eval(rhs, env))
      }
    }
    ArrayGet(array~, index~, ..) => eval(array, env)[eval(index, env)]
    ArraySet(array~, index~, value~, ..) =>
      eval(array, env)[eval(index, env)] = eval(value, env)
    ArrayAugmentedSet(op~, array~, index~, value~, ..) => {
      guard op.name is Ident(name~)
      let array = eval(array, env)
      let index = eval(index, env)
      array[index] = eval_infix(name, array[index], eval(value, env))
    }
    ArrayGetSlice(array~, start_index~, end_index~, ..) =>
      eval(array, env).sub(
        start?=match start_index {
          Some(s) => Some(eval(s, env))
          None => None
        },
        end?=match end_index {
          Some(s) => Some(eval(s, env))
          None => None
        },
      )
    Mutate(record~, accessor~, field~, augmented_by~, loc~) => {
      guard augmented_by is None else { not_support(loc~) }
      guard accessor is Label(label)
      guard eval(record, env) is Struct(val)
      val[label.name] = eval(field, env)
      Unit
    }
    Field(record~, accessor~, loc~) =>
      match accessor {
        Index(tuple_index~, ..) => {
          guard eval(record, env) is Tuple(tuple)
          tuple[tuple_index]
        }
        Label(label) => {
          guard eval(record, env) is Struct(record)
          record[label.name]
        }
        Newtype(_) => not_support(loc~)
      }

    // Compose
    Group(expr~, ..) => eval(expr, env)
    Constraint(expr~, ..) => eval(expr, env)
    Sequence(exprs~, last_expr~, ..) => {
      exprs.each(expr => eval(expr, env) |> ignore)
      eval(last_expr, env)
    }

    // Exception
    Raise(err_value~, ..) => raise Raise(eval(err_value, env))
    Try(body~, catch_~, catch_all~, catch_loc~, try_else~, else_loc~, loc~, ..) => {
      guard catch_all else { not_support(loc~) }
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
    ForEach(loc~, ..) => not_support(loc~)
    For(loc~, ..) => not_support(loc~)
    Loop(loc~, ..) => not_support(loc~)
    While(loc~, ..) => not_support(loc~)

    // Control
    Continue(loc~, ..) => not_support(loc~)
    Break(loc~, ..) => not_support(loc~)
    Return(loc~, ..) => not_support(loc~)

    // Other
    Pipe(loc~, ..) => not_support(loc~)
    Is(loc~, ..) => not_support(loc~)
    Hole(loc~, ..) => not_support(loc~)
    StaticAssert(body~, ..) => eval(body, env)
  }
}
