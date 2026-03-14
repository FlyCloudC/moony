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
  ArrayView(ArrayView[Value])
  Func(
    name~ : String?,
    arg_names~ : Array[String],
    body~ : @syntax.Expr,
    saved_env~ : Env[String, Value]
  )
  Enum(String, Array[Value])
  Struct(Map[String, Value])
}

///|
pub suberror Cont {
  Raise(Value)
  Panic(@basic.Location, msg~ : String)
} derive(Show)

///|
using @enviroment {type Env}

///|
pub struct VM1 {
  global_env : Env[String, Value]
}
