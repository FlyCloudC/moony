///|
let vm : VM1 = VM1::new()

///|
#callsite(autofill(args_loc, loc))
fn run(
  code : String,
  content? : String = "",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Unit raise {
  let (impls, diagnostics) : _ = @parser.parse_string(
    "fn init {\n\{code}\n}",
    parser=Handrolled,
  )
  guard impls is More(TopFuncDef(decl_body=DeclBody(expr~, ..), ..), tail=Empty) else {
    fail(diagnostics.iter().map(_.to_string()).join("\n"))
  }
  inspect(vm.eval_top(expr), loc~, args_loc~, content~)
}

///|
test "value int" {
  run("1", content="1")
  run("1 + 1", content="2")
  run("2 - 1", content="1")
  run("5 * 3", content="15")
  run("10 / 2", content="5")
  run("7 % 3", content="1")
  run("5 == 5", content="true")
  run("5 != 3", content="true")
  run("3 < 5", content="true")
  run("5 > 3", content="true")
  run("3 <= 5", content="true")
  run("5 >= 3", content="true")
}

///|
test "value bool" {
  run("true", content="true")
  run("false", content="false")
  run("!false", content="true")
  run("!true", content="false")
  run("true && false", content="false")
  run("true || false", content="true")
}

///|
test "value string" {
  run("\"hello\"", content="hello")
  run("\"hello\"+\"hello\"", content="hellohello")
}

///|
test "let" {
  run("let a = 1", content="()")
  run("a", content="1")
}

///|
test "let mut" {
  run("let mut a = 1", content="()")
  run("let b = a", content="()")
  run("b", content="1")
  run("a = 2", content="()")
  run("a", content="2")
  run("b", content="1")
}

///|
test "value tuple" {
  run("(1, 2)", content="(1, 2)")
  run("(1, 2).0", content="1")
  run("(1, 2).1", content="2")
  run("let a = (1, 2)", content="()")
  run("(a, a)", content="((1, 2), (1, 2))")
}

///|
test "value struct" {
  run("let a = { x: 1, y: 2 }", content="()")
  run("a", content="{x: 1, y: 2}")
  run("let b = a", content="()")
  run("a.x = 3", content="()")
  run("a", content="{x: 3, y: 2}")
  run("b", content="{x: 3, y: 2}")
}

///|
test "value enum" {
  run("Some(1)", content="Some(1)")
  run("None", content="None")
}

///|
test "value array" {
  run("let a = [1, 2]", content="()")
  run("a[0]", content="1")
  run("a", content="[1, 2]")
  run("a[0] -= 2", content="()")
  run("a", content="[-1, 2]")
  run("let b = a", content="()")
  run("a[0] = 2", content="()")
  run("a", content="[2, 2]")
  run("b", content="[2, 2]")
}

///|
test "value arrayview" {
  run("let a = [1, 2, 3]", content="()")
  run("let b = a[1:]", content="()")
  run("b", content="[2, 3]")
  run("b[0]", content="2")
  run("b[1] = 0", content="()")
  run("a[1] = -1", content="()")
  run("a", content="[1, -1, 0]")
  run("b", content="[-1, 0]")
}

///|
test "lambda" {
  run("(x => x * 2)(3)", content="6")
  run("((x, y) => x + y)(1, 2)", content="3")
}

///|
test "fn" {
  run("fn a() { 1 }", content="()")
  run("a()", content="1")
  run("fn double(x: Int) -> Int { x * 2 }", content="()")
  run("double(2)", content="4")
  run("fn add(a: Int, b: Int) -> Int { a + b }", content="()")
  run("add(1, 2)", content="3")
  run("a()", content="1")
}

///|
test "fn rec" {
  run(
    (
      #|fn fib(n : Int) -> Int {
      #|  if n <= 1 {
      #|    1
      #|  } else {
      #|    fib(n - 1) + fib(n - 2)
      #|  }
      #|}
    ),
    content="()",
  )
  run("fib(5)", content="8")
}

///|
test "if" {
  run("if 3 < 2 { 1 } else { 2 }", content="2")
  run("if 3 < 2 { 1 }", content="()")
  run("if false { 1 } else if false { 2 } else { 3 }", content="3")
}

///|
test "match constant" {
  run("match 10 { 10 => 100 }", content="100")
}

///|
test "match var" {
  run("match 42 { x => x * 2 }", content="84")
}

///|
test "match any" {
  run("match 123 { _ => 999 }", content="999")
}

///|
test "match or" {
  run("match 5 { 1 | 5 | 10 => 100 }", content="100")
  run("match 3 { 1 | 5 | 10 => 100; _ => 200 }", content="200")
}

///|
test "match tuple" {
  run("match (1, 2) { (a, b) => a }", content="1")
  run("match (1, 2) { (a, b) => b }", content="2")
  run("match (1, 2) { (a, b) => a + b }", content="3")
  run("match (1, (2, 3)) { (a, (b, c)) => a + b + c }", content="6")
}

///|
test "match array" {
  run("match [1, 2, 3] { [a, b, _] => a }", content="1")
  run("match [1, 2, 3] { [a, ..] => a }", content="1")
  run(
    "match [1, 2, 3, 4, 5] { [a, b, .. c, d, e] => (a, b, c, d, e) }",
    content="(1, 2, [3], 4, 5)",
  )
  let m = x => (
    $|match \{x} {
    #|  [] => 0
    #|  [_] => 1
    #|  [_, ..] => 2
    $|}
  )
  run(m("[]"), content="0")
  run(m("[1]"), content="1")
  run(m("[1, 2]"), content="2")
}

///|
test "match struct" {
  run("match { x: 10, y: 20 } { { x, y } => x + y }", content="30")
  run("let alice = { name: \"Alice\", age: 25 }", content="()")
  run("match alice { { name, .. } => name }", content="Alice")
  run("match alice { { age, .. } => age }", content="25")
}

///|
test "match enum" {
  run("match Some(8) { Some(x) => x \n None => 0 }", content="8")
  run("match None { Some(x) => x \n None => 0 }", content="0")
}

///|
test "match more case" {
  run("match 2 { 1 => 10; 2 => 20; _ => 30 }", content="20")
  run("match 5 { 1 => 10; 2 => 20; _ => 30 }", content="30")
}

///|
test "match range" {
  run(
    (
      #|fn sign(x : Int) -> Int {
      #|  match x {
      #|    _..<0 => -1
      #|    0 => 0
      #|    1..<_ => 1
      #|  }
      #|}
      #|
      #|fn classify_char(c : Char) -> String {
      #|  match c {
      #|    'a'..='z' => "lowercase"
      #|    'A'..='Z' => "uppercase"
      #|    '0'..='9' => "digit"
      #|    _ => "other"
      #|  }
      #|}
    ),
    content="()",
  )
  run("sign(10)", content="1")
  run("sign(-10)", content="-1")
  run("sign(0)", content="0")
  run("classify_char('a')", content="lowercase")
  run("classify_char('A')", content="uppercase")
  run("classify_char('0')", content="digit")
  run("classify_char('!')", content="other")
}

///|
test "defer" {
  run("let mut x = 0", content="()")
  run(
    (
      #|{
      #|  defer { x = 1 }
      #|  x
      #|}
    ),
    content="0",
  )
  run("x", content="1")
}
