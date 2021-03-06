## Setup built-in HTTP daemon
## Always show the HTML help on the same port
local({
  port <- sum(c(1e4, 100) * as.double(R.version[c("major", "minor")]))
  options(help.ports = port+0:9)
})

## Try to start HTML help server
try(tools::startDynamicHelp(), silent = TRUE)

options(help_type = "html")

