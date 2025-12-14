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
    saved_env~ : Env
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
type Env = @enviroment.T[String, Value]

///|
pub struct VM1 {
  global_env : Env
}
