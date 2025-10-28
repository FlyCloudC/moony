# FlyCloudC/moony

Moony 是一个基于 AST 的 MoonBit 子集解释器。AST 由 [moonbitlang/parser](https://github.com/moonbitlang/parser) 提供。

Moony is an AST-based interpreter for a subset of MoonBit. The AST is provided by [moonbitlang/parser](https://github.com/moonbitlang/parser).

## Usage

```moonbit
test "example" {
  let code =
    #|fn init {
    #|  fn fact(n) {
    #|    match n {
    #|      0 => 1
    #|      n => fact(n - 1) * n
    #|    }
    #|  }
    #|  fact(3)
    #|}
  let init_func = @parser.parse_string(code).0.unsafe_head()
  guard init_func is TopFuncDef(decl_body=DeclBody(expr~, ..), ..)
  let vm = VM1::new()
  inspect(vm.eval_top(expr), content="6")
}
```

Some examples can be found in [`src/eval_test.mbt`](src/eval_test.mbt).

Calls to the `not_support` function in the code indicate an unsupported feature.
