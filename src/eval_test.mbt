// test from moonbit-eval

///|
fn VM1::run(self : VM1, code : String) -> Value raise {
  let code = @encoding.encode(UTF8, "fn init {\n\{code}\n}")
  let (impls, diagnostics) : _ = @parser.parse_bytes(code, parser=Handrolled)
  guard impls is More(TopFuncDef(decl_body=DeclBody(expr~, ..), ..), tail=Empty) else {
    fail(diagnostics.fold(init="", (acc, cur) => "\{acc}\n\{cur}"))
  }
  self.eval_top(expr)
}

///|
test "basic" {
  let vm = VM1::new()
  // Int 运算测试
  inspect(vm.run("1"), content="1")
  inspect(vm.run("1+1"), content="2")
  inspect(vm.run("2-1"), content="1")
  inspect(vm.run("\"hello\""), content="hello")
  inspect(vm.run("5 * 3"), content="15")
  inspect(vm.run("10 / 2"), content="5")
  inspect(vm.run("7 % 3"), content="1")
  inspect(vm.run("5 == 5"), content="true")
  inspect(vm.run("5 != 3"), content="true")
  inspect(vm.run("3 < 5"), content="true")
  inspect(vm.run("5 > 3"), content="true")
  inspect(vm.run("3 <= 5"), content="true")
  inspect(vm.run("5 >= 3"), content="true")
}

///|
test "bool" {
  let vm = VM1::new()
  inspect(vm.run("true"), content="true")
  inspect(vm.run("false"), content="false")
  inspect(vm.run("!false"), content="true")
  inspect(vm.run("!true"), content="false")
  inspect(vm.run("true && false"), content="false")
  inspect(vm.run("true || false"), content="true")
}

///|
test "string" {
  let vm = VM1::new()
  inspect(vm.run("\"hello\""), content="hello")
  inspect(vm.run("\"hello\"+\"hello\""), content="hellohello")
}

///|
test "variables" {
  let vm = VM1::new()
  inspect(vm.run("let a = 1"), content="()")
  inspect(vm.run("a"), content="1")
}

///|
test "mutable variables" {
  let vm = VM1::new()
  inspect(vm.run("let mut a = 1"), content="()")
  inspect(vm.run("a = 12"), content="()")
  inspect(vm.run("a"), content="12")
}

///|
test "function" {
  let vm = VM1::new()
  inspect(vm.run("fn double(x: Int) -> Int { x * 2 }"), content="()")
  inspect(vm.run("double(2)"), content="4")
  inspect(vm.run("fn add(a: Int, b: Int) -> Int { a + b }"), content="()")
  inspect(vm.run("add(1, 2)"), content="3")
  // TODO
  // inspect(
  //   vm.run("fn add_named(a~: Int, b~: Int) -> Int { a + b }"),
  //   content="(a~: Int, b~: Int) -> Int",
  // )
  // inspect(vm.run("add_named(a=1, b=2)"), content="3")
  // inspect(
  //   vm.run("fn add_optional(a~: Int, b~: Int=2) -> Int { a + b }"),
  //   content="(a~: Int, b~: Int = 2) -> Int",
  // )
  // inspect(vm.run("add_optional(a=1)"), content="3")
}

///|
test "str" {
  let vm = VM1::new()
  inspect(vm.run("let str1: String = \"haha\""), content="()")
  inspect(vm.run("let str2: String = \"hello\""), content="()")
  inspect(vm.run("str1 + str2"), content="hahahello")
}

///|
test "if" {
  let vm = VM1::new()
  // Test nested if expressions
  inspect(
    vm.run("if 1 > 0 { if 2 > 1 { 3 } else { 4 } } else { 5 }"),
    content="3",
  )

  // Test complex conditions
  inspect(vm.run("if (5 + 3) * 2 > 15 { 1 } else { 2 }"), content="1")

  // Test boolean expressions in conditions
  inspect(vm.run("if true && false || true { 1 } else { 2 }"), content="1")

  // Test if expression with function calls
  inspect(
    vm.run(
      "fn double(x: Int) -> Int { x * 2 }\n if double(5) > 8 { 3 } else { 4 }",
    ),
    content="3",
  )

  // Test if without else
  inspect(vm.run("if 3 < 2 { 1 }"), content="()")
}

// ///|
// test "for" {
//   // test for loop
//   let vm = VM1::new()
//   inspect(vm.run("let mut output = 0"), content="()")
//   inspect(vm.run("for i = 0; i < 10; i = i + 1 { output += i }"), content="()")
//   inspect(vm.run("output"), content="45")
//   let mut output = 0
//   for i = 0; i < 10; i = i + 1 {
//     output += i
//   }
//   inspect(output, content="45")
// }

// ///|
// test "while" {
//   let vm = VM1::new()
//   inspect(vm.run("let mut i = 0"), content="()")
//   inspect(vm.run("let mut sum = 0"), content="()")
//   inspect(vm.run("while i < 5 { sum += i; i += 1 }"), content="()")
//   inspect(vm.run("sum"), content="10")
//   inspect(vm.run("i"), content="5")

//   // 测试 while 循环不会执行的情况
//   let vm2 = VM1::new()
//   inspect(vm2.run("let mut count = 0"), content="()")
//   inspect(vm2.run("while false { count += 1 }"), content="()")
//   inspect(vm2.run("count"), content="0")
// }

///|
test "lambda" {
  let vm = VM1::new()
  // 测试基本的 lambda 函数
  inspect(vm.run("let f = x => x * 2"), content="()")
  inspect(vm.run("f(3)"), content="6")
  // 测试 lambda 函数作为表达式
  inspect(vm.run("let g = y => y + 1"), content="()")
  inspect(vm.run("g(5)"), content="6")

  // 测试 lambda 函数调用
  inspect(vm.run("let h = z => z * z"), content="()")
  inspect(vm.run("h(4)"), content="16")
}

///|
test "lambda_simple" {
  let vm = VM1::new()
  // 测试简单的 lambda 表达式
  inspect(vm.run("let f = x => x"), content="()")
  inspect(vm.run("f(5)"), content="5")
}

// TODO
// ///|
// test "extern" {
//   let vm = VM1::new()
//   vm.interpreter.add_extern_fn("println", params => {
//     if params is [{ value: String(s), .. }, ..] {
//       println(s)
//     }
//     Unit
//   })
//   inspect(vm.run("println(\"println from external function\")"), content="()")
// }

///|
test "fib" {
  let vm = VM1::new()
  inspect(
    vm.run(
      (
        #|fn fib(n : Int) -> Int {
        #|  if n <= 1 {
        #|    1
        #|  } else {
        #|    fib(n - 1) + fib(n - 2)
        #|  }
        #|}
      ),
    ),
    content="()",
  )
  inspect(vm.run("fib(10)"), content="89")
}

///|
test "fn simple" {
  let vm = VM1::new()
  inspect(vm.run("fn a() { 1 }"), content="()")
  inspect(vm.run("a()"), content="1")
}

///|
test "fn add" {
  let vm = VM1::new()
  inspect(vm.run("fn add(a: Int, b: Int) -> Int { a + b }"), content="()")
  inspect(vm.run("add(1,2)"), content="3")
}

///|
test "struct" {
  let vm = VM1::new()
  inspect(
    vm.run(
      (
        #|fn sum(self: S) -> Int {
        #|  self.a + self.b
        #|}
      ),
    ),
    content="()",
  )
  inspect(vm.run("let s = { a: 23, b: 32 }"), content="()")
  inspect(vm.run("sum(s)"), content="55")
}

///|
test "match" {
  let vm = VM1::new()
  // 基本常量匹配
  inspect(vm.run("let s = 10"), content="()")
  inspect(vm.run("match s { 10 => 100 }"), content="100")

  // 变量模式匹配
  inspect(vm.run("match 42 { x => x * 2 }"), content="84")

  // 通配符模式匹配
  inspect(vm.run("match 123 { _ => 999 }"), content="999")

  // Or模式匹配
  inspect(vm.run("match 5 { 1 | 5 | 10 => 100 }"), content="100")
  inspect(vm.run("match 3 { 1 | 5 | 10 => 100; _ => 200 }"), content="200")

  // 测试简单变量绑定
  inspect(vm.run("match 42 { x => x }"), content="42")

  // Tuple模式匹配 - 简化测试
  inspect(vm.run("match (1, 2) { (a, b) => a }"), content="1")
  inspect(vm.run("match (1, 2) { (a, b) => b }"), content="2")
  inspect(vm.run("match (1, 2) { (a, b) => a + b }"), content="3")

  // TODO
  // // Array模式匹配
  // inspect(vm.run("match [1, 2, 3] { [a, b, c] => a }"), content="1")
  // inspect(vm.run("match [1, 2, 3] { [a, b, c] => a + b + c }"), content="6")
  // inspect(vm.run("match [5, 10] { [x, y] => x * y }"), content="50")

  // Record模式匹配
  inspect(vm.run("match { x: 10, y: 20 } { { x, y } => x + y }"), content="30")
  inspect(
    vm.run("match { name: \"Alice\", age: 25 } { { name, .. } => name }"),
    content="Alice",
  )
  inspect(
    vm.run("match { name: \"Alice\", age: 25 } { { age, .. } => age }"),
    content="25",
  )
  // 嵌套模式匹配
  inspect(vm.run("match (1, (2, 3)) { (a, (b, c)) => a + b + c }"), content="6")

  // 多个case的匹配
  inspect(vm.run("match 2 { 1 => 10; 2 => 20; _ => 30 }"), content="20")
  inspect(vm.run("match 5 { 1 => 10; 2 => 20; _ => 30 }"), content="30")
}

///|
test "match range" {
  let vm = VM1::new()
  inspect(
    vm.run(
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
    ),
    content="()",
  )
  inspect(vm.run("sign(10)"), content="1")
  inspect(vm.run("sign(-10)"), content="-1")
  inspect(vm.run("sign(0)"), content="0")
  inspect(vm.run("classify_char('a')"), content="lowercase")
  inspect(vm.run("classify_char('A')"), content="uppercase")
  inspect(vm.run("classify_char('0')"), content="digit")
  inspect(vm.run("classify_char('!')"), content="other")
}

// // TODO

// ///|
// test "match constructor" {
//   let vm = VM1::new()
//   // 测试常量构造函数匹配
//   inspect(
//     vm.run(
//       (
//         #|const Zero = 0
//         #|const One = 1
//         #|const Two = 2
//         #|fn test_constr(x : Int) -> String {
//         #|  match x {
//         #|    Zero => "zero"
//         #|    One => "one" 
//         #|    Two => "two"
//         #|    _ => "other"
//         #|  }
//         #|}
//       ),
//       top=true,
//     ),
//     content="()",
//   )
//   inspect(vm.run("test_constr(0)"), content="zero")
//   inspect(vm.run("test_constr(1)"), content="one")
//   inspect(vm.run("test_constr(2)"), content="two")
//   inspect(vm.run("test_constr(5)"), content="other")
// }

///|
test "mutate" {
  let vm = VM1::new()
  inspect(vm.run("let p = { x: 1, y: 2 }"), content="()")
  inspect(vm.run("p.x"), content="1")
  inspect(vm.run("p.y"), content="2")
  inspect(vm.run("p.x = 3"), content="()")
  inspect(vm.run("p.y = 4"), content="()")
  inspect(vm.run("p.x"), content="3")
  inspect(vm.run("p.y"), content="4")
  inspect(vm.run("p"), content="{x: 3, y: 4}")
}

///|
test "tuple" {
  let vm = VM1::new()
  inspect(vm.run("let t = (1, 2)"), content="()")
  inspect(vm.run("t.0"), content="1")
  inspect(vm.run("t.1"), content="2")
  inspect(vm.run("t"), content="(1, 2)")
  inspect(vm.run("let (a, b) = t"), content="()")
  inspect(vm.run("a"), content="1")
  inspect(vm.run("b"), content="2")
  inspect(vm.run("let (a, b, c) = (1, 2, 3)"), content="()")
  inspect(vm.run("a"), content="1")
  inspect(vm.run("b"), content="2")
  inspect(vm.run("c"), content="3")
  inspect(vm.run("let a = 1"), content="()")
  inspect(vm.run("let a = (a, a)"), content="()")
  inspect(vm.run("let a = (a, a)"), content="()")
  inspect(vm.run("a"), content="((1, 1), (1, 1))")
}

///|
test "array" {
  let vm = VM1::new()
  inspect(vm.run("let a = [1, 2, 3]"), content="()")
  inspect(vm.run("let b = a"), content="()")
  inspect(vm.run("a"), content="[1, 2, 3]")
  inspect(vm.run("a[0]"), content="1")
  inspect(vm.run("a[1] = 4"), content="()")
  inspect(vm.run("a"), content="[1, 4, 3]")
  inspect(vm.run("b"), content="[1, 4, 3]")
}

///|
test "ref" {
  let vm = VM1::new()
  inspect(
    vm.run(
      (
        #|let a = { value: 1 }
        #|let b = a
        #|b.value = 2
      ),
    ),
    content="()",
  )
  inspect(vm.run("a"), content="{value: 2}")
  inspect(vm.run("a.value"), content="2")
}

///|
test "enum" {
  let vm = VM1::new()
  ignore(vm.run("let a = Some(8)"))
  inspect(vm.run("match a { Some(x) => x \n None => 0 }"), content="8")
  ignore(vm.run("let b = None"))
  inspect(vm.run("match b { Some(x) => x \n None => 0 }"), content="0")
}
