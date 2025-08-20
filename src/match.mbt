///|
fn bind_pattern(
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
      Record(fields~, ..) => {
        guard value is Struct(vals)
        fields.all(pat => {
          let val = vals.get(pat.label.name).unwrap()
          acc(pat.pattern, val)
        })
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
      Constant(c~, loc~) => c.to_value(loc) == value
      Range(lhs~, rhs~, inclusive~, ..) =>
        (match lhs {
          Constant(c~, loc~) => c.to_value(loc) <= value
          _ => true // lhs is Any
        }) &&
        (match rhs {
          Constant(c~, loc~) =>
            if inclusive {
              value <= c.to_value(loc)
            } else {
              value < c.to_value(loc)
            }
          _ => true // rhs is Any
        })
      Array(loc~, ..) => not_impl(loc)
      Map(loc~, ..) => not_impl(loc)
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
    if bind_pattern(case.pattern, val) is Some(binds) {
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
