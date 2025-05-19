#let enable-highlighting(body) = {
  show figure.where(kind: raw): it => [
    #show raw.where(lang: "DSL"): it_r => [
      #show regex("\b(object|func|var|return|if|else|intrinsic|new|true|false|package|import|)\b") : keyword => text(fill: rgb("#ff553b"), keyword)
      #show regex("\".+\"") : keyword => text(fill: rgb("#067D17"), keyword)
      #show regex("/\*.+\*/") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #show regex("//.+") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #it_r
    ]

    #show raw.where(lang: "csharp"): it_r => [
      #show regex("\b(object|func|var|return|if|else|intrinsic|new|true|false|package|import|)\b") : keyword => text(fill: rgb("#ff553b"), keyword)
      #show regex("\".+\"") : keyword => text(fill: rgb("#067D17"), keyword)
      #show regex("/\*.+\*/") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #show regex("//.+") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #it_r
    ]

  #it
  ]

  body
}