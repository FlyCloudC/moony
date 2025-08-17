///|
pub struct Env {
  parent : Env?
  table : @hashmap.T[String, Value]
}

///|
pub fn Env::new() -> Env {
  { parent: None, table: @hashmap.new() }
}

///|
pub fn Env::extend(self : Env, binds : Array[(String, Value)]) -> Env {
  { parent: Some(self), table: @hashmap.from_array(binds) }
}

///|
pub fn Env::get(self : Env, name : String) -> Value? {
  match self.table.get(name) {
    Some(v) => Some(v)
    None =>
      match self.parent {
        Some(parent) => parent.get(name)
        None => None
      }
  }
}

///|
pub fn Env::op_get(self : Env, name : String) -> Value {
  match self.table.get(name) {
    Some(v) => v
    None => self.parent.unwrap()[name]
  }
}

///|
pub fn Env::op_set(self : Env, name : String, value : Value) -> Unit {
  if self.table.contains(name) {
    self.table[name] = value
  } else {
    self.parent.unwrap()[name] = value
  }
}

///|
pub fn Env::define_var(self : Env, name : String, value : Value) -> Unit {
  self.table[name] = value
}
