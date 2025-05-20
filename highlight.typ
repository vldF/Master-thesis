#let enable-highlighting(body) = {
  show figure.where(kind: raw): it => [
    #show raw.where(lang: "DSL"): it_r => [
      #show regex("\b(object|func|var|return|if|else|intrinsic|new|true|false|package|import|)\b") : keyword => text(fill:  rgb("#ec4e36"), keyword)
      #show regex("\".+\"") : keyword => text(fill: rgb("#067D17"), keyword)
      #show regex("/\*.+\*/") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #show regex("//.+") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #it_r
    ]

    #show raw.where(lang: "csharp"): it_r => [
      #show regex("\".+\"") : keyword => text(fill: rgb("#067D17"), keyword)
      #show regex("/\*.+\*/") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #show regex("//.+") : keyword => text(fill: rgb("#6d6d6d"), keyword)
      #show regex("\b(object|private|internal|case|switch|default|break|for|continue|throw|nameof|foreach|in|public|override|void|string|int|double|float|null|var|return|if|else|^\"new|true|false)\b") : keyword => text(fill: rgb("#ec4e36"), keyword)
      #it_r
    ]

  #it
  ]

  body
}