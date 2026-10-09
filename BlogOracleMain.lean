import LeanRunBlog.Page
import LeanRunBlog.Post
import LeanRunSlides.Deck
import LeanRunBlog.Examples
import LeanRunGate.Helper
import Lean.Data.Json

def main (args : List String) : IO Unit := do
  let [role, input] := args | throw <| IO.userError "usage: lean-run-blog-oracle greet|card|count|twice INPUT"
  let result ← match role with
    | "greet" => pure <| LeanRunBlog.Examples.greet input
    | "pageInlineGreet" => pure <| LeanRunBlog.Page.Inline.greet input
    | "pageInlineCard" => pure <| (LeanRunBlog.Page.Inline.card input).asString
    | "postInlineGreet" => pure <| LeanRunBlog.Post.Inline.greet input
    | "postInlineCard" => pure <| (LeanRunBlog.Post.Inline.card input).asString
    | "slideInlineGreet" => pure <| LeanRunSlides.Deck.Inline.greet input
    | "slideInlineCard" => pure <| (LeanRunSlides.Deck.Inline.card input).asString
    | "card" => pure <| (LeanRunBlog.Examples.card input).asString
    | "count" | "twice" => do
      let some n := input.toNat? | throw <| IO.userError "invalid Nat"
      pure <| toString <| if role == "count" then LeanRunBlog.Examples.count n else LeanRunGate.Helper.twice n
    | _ => throw <| IO.userError "unknown role"
  IO.println (Lean.Json.str result).compress
