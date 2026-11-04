import Consumer.Blog
import Consumer.BlogResources
import VersoLeanRun.Blog.Publish
import Presenter
open Verso Genre Blog
def main (args : List String) : IO UInt32 := do
  let [destination] := args | throw <| IO.userError "Expected output directory"
  VersoLeanRun.Blog.blogMain Theme.default (.page `Consumer.Blog (%doc Consumer.Blog) #[])
    Consumer.blogResources destination (presenters := #[Consumer.presenter])
