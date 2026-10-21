# Expect a warning of `class` while ignoring any other diagnostic warnings
expect_ung_warning <- function(expr, class) {
  expect_warning(
    withCallingHandlers(expr, warning = function(w) {
      if (!inherits(w, class)) invokeRestart("muffleWarning")
    }),
    class = class
  )
}
