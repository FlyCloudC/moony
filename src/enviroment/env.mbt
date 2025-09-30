///|
struct T[K, V] {
  parent : T[K, V]?
  table : @hashmap.HashMap[K, V]
}

///|
pub fn[K, V] T::new() -> T[K, V] {
  { parent: None, table: @hashmap.new() }
}

///|
pub fn[K : Eq + Hash, V] T::extend(
  self : T[K, V],
  binds : Array[(K, V)],
) -> T[K, V] {
  { parent: Some(self), table: @hashmap.from_array(binds) }
}

///|
pub fn[K, V] T::extend_new(self : T[K, V]) -> T[K, V] {
  { parent: Some(self), table: @hashmap.new() }
}

///|
pub fn[K : Eq + Hash, V] T::get(self : T[K, V], name : K) -> V? {
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
pub fn[K : Eq + Hash, V] T::at(self : T[K, V], name : K) -> V {
  match self.table.get(name) {
    Some(v) => v
    None => self.parent.unwrap()[name]
  }
}

///|
#alias("_[_]=_")
pub fn[K : Eq + Hash, V] T::set(self : T[K, V], name : K, value : V) -> Unit {
  if self.table.contains(name) {
    self.table[name] = value
  } else {
    self.parent.unwrap()[name] = value
  }
}

///|
pub fn[K : Eq + Hash, V] T::define_var(
  self : T[K, V],
  name : K,
  value : V,
) -> Unit {
  self.table[name] = value
}
