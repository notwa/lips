local path = string.gsub(..., "%.init$", "").."."
return require(path.."lips.init")
