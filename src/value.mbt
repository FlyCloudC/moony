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
    ArrayView(a) => a.output(logger)
    Func(name~, ..) =>
      match name {
        None => logger.write_string("<func>")
        Some(name) => logger.write_string("<func \{name}>")
      }
    Enum(name, []) => logger.write_string(name)
    Enum(name, a) => logger.write_iter(a.iter(), prefix=name + "(", suffix=")")
    Struct(a) => {
      logger.write_char('{')
      let mut first = true
      for x in a {
        if first {
          first = false
        } else {
          logger.write_string(", ")
        }
        logger..write_string(x.0)..write_string(": ")..write_object(x.1)
      }
      logger.write_char('}')
    }
  }
}

///|
pub impl Show for Value with to_string(self) {
  match self {
    Char(a) => Show::to_string(a)
    Int(a) => Show::to_string(a)
    String(a) => Show::to_string(a)
    Unit
    | True
    | False
    | Double(_)
    | Tuple(_)
    | Array(_)
    | ArrayView(_)
    | Func(_)
    | Enum(_)
    | Struct(_) => { // default impl for Show::to_string
      let logger = StringBuilder::new()
      self.output(logger)
      logger.to_string()
    }
  }
}

///|
pub fn Value::op_get(self : Value, index : Value) -> Value {
  guard index is Int(i)
  match self {
    Array(a) => a[i]
    ArrayView(a) => a[i]
    _ => panic()
  }
}

///|
pub fn Value::op_set(self : Value, index : Value, v : Value) -> Value {
  guard index is Int(i)
  match self {
    Array(a) => a[i] = v
    ArrayView(a) => a[i] = v
    _ => panic()
  }
  Unit
}

///|
pub fn Value::op_as_view(
  self : Value,
  start~ : Value = Int(0),
  end? : Value,
) -> Value {
  guard start is Int(start)
  let end = match end {
    None => None
    Some(Int(i)) => Some(i)
    _ => panic()
  }
  match self {
    Array(a) => ArrayView(a.op_as_view(start~, end?))
    ArrayView(a) => ArrayView(a.op_as_view(start~, end?))
    _ => panic()
  }
}

///|
fn @syntax.Constant::to_value(self : Self, loc : @basic.Location) -> Value {
  match self {
    Bool(bool) => Value::bool(bool)
    Char(s) => Char(s.get_char(0).unwrap())
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
