package main

import "core:fmt"

import "vendor:darwin/Metal"
import "vendor:glfw"

WINDOW_TITLE :: "Hello Metal"
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

MTLEngine :: struct {
  is_initialized: bool,
  metal_device: ^Metal.Device,
  glfw_window:  glfw.WindowHandle,
}

@(private)
_ctx: ^MTLEngine

engine_init :: proc() -> (err: Error) {
  _ctx = new(MTLEngine) or_return

  /* Initialize the library */
  if !bool(glfw.Init()) {
		fmt.eprintln("GLFW has failed to load.")
		return
	}

  /* Create a windowed mode window and its OpenGL context */
  _ctx.glfw_window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE, nil, nil)

  if _ctx.glfw_window == nil {
    glfw.Terminate()
    panic("Error creating glfw window")
  } 

  /* Make the window's context current */
  glfw.MakeContextCurrent(_ctx.glfw_window)

  /* Everything went fine */
  _ctx.is_initialized = true

  return nil
}

engine_run :: proc() -> (err: Error){
  /* Loop until the user closes the window */
  for !glfw.WindowShouldClose(_ctx.glfw_window) {

    /* Render here */

    /* Swap front and back buffers */
    glfw.SwapBuffers(_ctx.glfw_window)

    /* Poll for and process events */
    glfw.PollEvents()

  }

  return nil
}

engine_close_window :: proc() {
  glfw.Terminate()
  glfw.DestroyWindow(_ctx.glfw_window)
}

engine_cleanup :: proc() {

  if _ctx.is_initialized {
    engine_close_window()
  }

  free(_ctx)
}
