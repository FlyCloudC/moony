///|
using @hashmap {type HashMap}

///|
struct Env[K, V] {
  parent : Env[K, V]?
  table : HashMap[K, V]
}

///|
pub fn[K, V] Env::new() -> Env[K, V] {
  { parent: None, table: HashMap::new() }
}

///|
pub fn[K : Eq + Hash, V] Env::extend(
  self : Env[K, V],
  binds : Array[(K, V)],
) -> Env[K, V] {
  { parent: Some(self), table: HashMap::from_array(binds) }
}

///|
pub fn[K, V] Env::extend_new(self : Env[K, V]) -> Env[K, V] {
  { parent: Some(self), table: HashMap::new() }
}

///|
pub fn[K : Eq + Hash, V] Env::get(self : Env[K, V], name : K) -> V? {
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
#alias("_[_]")
pub fn[K : Eq + Hash, V] Env::at(self : Env[K, V], name : K) -> V {
  match self.table.get(name) {
    Some(v) => v
    None => self.parent.unwrap()[name]
  }
}

///|
#alias("_[_]=_")
pub fn[K : Eq + Hash, V] Env::set(
  self : Env[K, V],
  name : K,
  value : V,
) -> Unit {
  if self.table.contains(name) {
    self.table[name] = value
  } else {
    self.parent.unwrap()[name] = value
  }
}

///|
pub fn[K : Eq + Hash, V] Env::define_var(
  self : Env[K, V],
  name : K,
  value : V,
) -> Unit {
  self.table[name] = value
}
