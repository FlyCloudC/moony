///|
pub enum Value {
  Unit
  True
  False
  Char(Char)
  Int(Int)
  Double(Double)
  String(String)
  //
  Tuple(Array[Value])
  Array(Array[Value])
  Func(
    name~ : String?,
    arg_names~ : Array[String],
    body~ : @syntax.Expr,
    saved_env~ : Env
  )
  Enum(String, Array[Value])
}

///|
pub fn Value::bool(bool : Bool) -> Value {
  if bool {
    True
  } else {
    False
  }
}

///|
pub impl Eq for Value with op_equal(self, other) {
  match (self, other) {
    (Unit, _) => true
    (True, True) | (False, False) => true
    (Char(l), Char(r)) => l == r
    (Int(l), Int(r)) => l == r
    (Double(l), Double(r)) => l == r
    (String(l), String(r)) => l == r
    (Tuple(l), Tuple(r)) => l == r
    (Array(l), Array(r)) => l == r
    (Func(_) as l, r) => physical_equal(l, r)
    (Enum(ln, lv), Enum(rn, rv)) => ln == rn && lv == rv
    _ => false
  }
}

///|
pub impl Compare for Value with compare(self, other) {
  match (self, other) {
    (Unit, _) => 0
    (True, False) => 1
    (False, True) => -1
    (True, True) | (False, False) => 0
    (Char(l), Char(r)) => Compare::compare(l, r)
    (Int(l), Int(r)) => Compare::compare(l, r)
    (Double(l), Double(r)) => Compare::compare(l, r)
    (String(l), String(r)) => Compare::compare(l, r)
    (Tuple(l), Tuple(r)) => Compare::compare(l, r)
    (Array(l), Array(r)) => Compare::compare(l, r)
    (Func(_), _) => panic()
    (Enum(ln, lv), Enum(rn, rv)) => Compare::compare((ln, lv), (rn, rv))
    _ => panic()
  }
}

///|
pub impl Add for Value with op_add(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l + r)
    (Double(l), Double(r)) => Double(l + r)
    (String(l), String(r)) => String(l + r)
    (Array(l), Array(r)) => Array(l + r)
    _ => panic()
  }
}

///|
pub impl Sub for Value with op_sub(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l - r)
    (Double(l), Double(r)) => Double(l - r)
    _ => panic()
  }
}

///|
pub impl Mul for Value with op_mul(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l * r)
    (Double(l), Double(r)) => Double(l * r)
    _ => panic()
  }
}

///|
pub impl Div for Value with op_div(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l / r)
    (Double(l), Double(r)) => Double(l / r)
    _ => panic()
  }
}

///|
pub impl Mod for Value with op_mod(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l % r)
    (Double(l), Double(r)) => Double(l % r)
    _ => panic()
  }
}

///|
pub impl BitAnd for Value with land(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l & r)
    _ => panic()
  }
}

///|
pub impl BitOr for Value with lor(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l | r)
    _ => panic()
  }
}

///|
pub impl BitXOr for Value with lxor(self, other) {
  match (self, other) {
    (Int(l), Int(r)) => Int(l ^ r)
    _ => panic()
  }
}

///|
pub impl Shl for Value with op_shl(self, other) {
  match (self, other) {
    (Int(l), r) => Int(l << r)
    _ => panic()
  }
}

///|
pub impl Shr for Value with op_shr(self, other) {
  match (self, other) {
    (Int(l), r) => Int(l >> r)
    _ => panic()
  }
}

///|
pub impl Show for Value with output(self, logger) {
  match self {
    Unit => ().output(logger)
    True => true.output(logger)
    False => false.output(logger)
    Char(a) => a.output(logger)
    Int(a) => a.output(logger)
    Double(a) => a.output(logger)
    String(a) => a.output(logger)
    Tuple(a) => logger.write_iter(a.iter(), prefix="(", suffix=")")
    Array(a) => a.output(logger)
    Func(name~, ..) =>
      match name {
        None => logger.write_string("<func>")
        Some(name) => logger.write_string("<func \{name}")
      }
    Enum(name, a) => logger.write_iter(a.iter(), prefix=name + "(", suffix=")")
  }
}

///|
pub impl Show for Value with to_string(self) {
  match self {
    Unit => ().to_string()
    True => true.to_string()
    False => false.to_string()
    Char(a) => a.to_string()
    Int(a) => a.to_string()
    Double(a) => a.to_string()
    String(a) => a.to_string()
    Tuple(a) => {
      let b = StringBuilder::new()
      (b as &Logger).write_iter(a.iter(), prefix="(", suffix=")")
      b.to_string()
    }
    Array(a) => a.to_string()
    Func(name~, ..) =>
      match name {
        None => "<func>"
        Some(name) => "<func \{name}"
      }
    Enum(name, a) => {
      let b = StringBuilder::new()
      (b as &Logger).write_iter(a.iter(), prefix=name + "(", suffix=")")
      b.to_string()
    }
  }
}

///|
fn Value::from_constant(c : @syntax.Constant, loc : @basic.Location) -> Value {
  match c {
    Bool(bool) => Value::bool(bool)
    Char(s) =>
      Char(
        {
          println(s)
          s.get_char(0).unwrap()
        },
      )
    Int(s) => Int(try! @strconv.parse_int(s))
    Double(s) => Double(try! @strconv.parse_double(s))
    String(s) => String(s)
    Byte(_)
    | Bytes(_)
    | UInt(_)
    | Float(_)
    | Int64(_)
    | UInt64(_)
    | BigInt(_) => not_support(loc)
  }
}
