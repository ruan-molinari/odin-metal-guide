package main

import "core:mem"

import "vendor:glfw"

Error :: union #shared_nil {
  mem.Allocator_Error,
}
