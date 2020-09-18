version = "0.1.0"
author = "Dawid Kotliński"
description = "A new awesome nimble package"
license = "MIT"
srcDir = "src"
binDir = "bin"
bin = @["frontend.js", "resetDb", "backend"]

requires "nim 1.2.6", "bcrypt 0.2.1"