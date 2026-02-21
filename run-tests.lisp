(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:test-system :fol-compiler)
(sb-ext:exit :code 0)
