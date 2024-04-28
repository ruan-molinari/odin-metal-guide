package main

import "core:fmt"

main :: proc() {

  err := engine_init()
  if err != nil {
    fmt.eprintln("Error initializing application: [%v]", err)
  }
  defer engine_cleanup()

  engine_run()

}
