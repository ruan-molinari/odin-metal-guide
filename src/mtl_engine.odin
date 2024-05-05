package main

import MTL "vendor:darwin/Metal"
import CA  "vendor:darwin/QuartzCore"
import NS  "core:sys/darwin/Foundation"

import GLFW "vendor:glfw"

import "core:fmt"
import "core:os"

import "core:math"

// Window
WINDOW_TITLE :: "Hello Metal"
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

// Engine
NUM_INSTANCES :: 32

Instance_Data :: struct {
  transform: matrix[4, 4]f32,
  color:     [4]f32,
}

MTLEngine :: struct {
  is_initialized:    bool,
  glfw_window:       GLFW.WindowHandle,
  device:            ^MTL.Device, /* GPU */
  native_window:     ^NS.Window, /* Native MacOS Cocoa Window */
  metal_layer:       ^CA.MetalLayer, /* Swapchain */ 
  library:           ^MTL.Library, /* Metal library that interfaces with the GPU */ 
  pso:               ^MTL.RenderPipelineState, /* The state of the command pipeline */
  command_queue:     ^MTL.CommandQueue,
}

@(private)
engine: ^MTLEngine

engine_init :: proc() -> (err: Error) {
  engine = new(MTLEngine) or_return

  if res := engine_init_device(); res != nil {
    fmt.eprintln("Error initializing Metal Device: [%v]", res)
  }

  if res := engine_init_window(); res != nil {
    fmt.eprintln("Error initializing window: [%v]", res)
  }

  /* Builds the shaders */
  if res := engine_build_shaders(); res != nil {
    fmt.eprintfln(
      "Error building shaders: [Code (%v): %s]",
      res->code(),
      res->localizedDescription()->odinString(),
    )
  }

  engine.command_queue = engine.device->newCommandQueue()

  /* Everything went fine */
  engine.is_initialized = true

  return
}

engine_init_device :: proc() -> (err: Error) {
  engine.device = MTL.CreateSystemDefaultDevice()
  if engine.device == nil do return .Create_Device_Failed
  
  defer if err != nil {
    fmt.eprintln("Error initializing Metal Device: [%s]", err)
  }
  return
}

engine_init_window :: proc() -> (err: Error) {
  /* Initialize the library */
  if !bool(GLFW.Init()) {
		fmt.eprintln("GLFW has failed to load.")
		return
	}

  GLFW.WindowHint(GLFW.CLIENT_API, GLFW.NO_API)

  /* Create a windowed mode window and its OpenGL context */
  engine.glfw_window = GLFW.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE, nil, nil)

  if engine.glfw_window == nil {
    GLFW.Terminate()
    return .Create_GLFW_Window_Failed
  } 

  /* Make the window's context current */
  GLFW.MakeContextCurrent(engine.glfw_window)

  engine.native_window = GLFW.GetCocoaWindow(engine.glfw_window)

  engine.metal_layer = CA.MetalLayer_layer()
  engine.metal_layer->setDevice(engine.device)
  engine.metal_layer->setPixelFormat(.BGRA8Unorm)
  engine.metal_layer->setFramebufferOnly(true)
  engine.metal_layer->setFrame(engine.native_window->frame())

  engine.native_window->contentView()->setLayer(engine.metal_layer)
  engine.native_window->setOpaque(true)
  engine.native_window->setBackgroundColor(nil)

  return nil
}

engine_build_shaders :: proc() -> (err: ^NS.Error){
  shader_src, _ := os.read_entire_file_from_filename("shaders/main_shaders.metal")
  shader_src_str := NS.String.alloc()->initWithOdinString(auto_cast shader_src)
  defer shader_src_str->release()

  engine.library = engine.device->newLibraryWithSource(shader_src_str, nil) or_return

  vertex_function   := engine.library->newFunctionWithName(NS.AT("vertex_main"))
  fragment_function := engine.library->newFunctionWithName(NS.AT("fragment_main"))
  defer vertex_function->release()
  defer fragment_function->release()

  desc: ^MTL.RenderPipelineDescriptor = MTL.RenderPipelineDescriptor.alloc()->init()
  defer desc->release()

  desc->setVertexFunction(vertex_function)
  desc->setFragmentFunction(fragment_function)
  desc->colorAttachments()->object(0)->setPixelFormat(.BGRA8Unorm_sRGB)

  engine.pso = engine.device->newRenderPipelineStateWithDescriptor(desc) or_return

  return
}

engine_build_buffers :: proc() -> (vertex_buffer, index_buffer, instance_buffer: ^MTL.Buffer) {
  s :: 0.5

  positions := [][3]f32{
    {-s, -s, +s},
    {+s, -s, +s},
    {+s, +s, +s},
    {-s, +s, +s},
  }
  indices := []u16{
		0, 1, 2,
		2, 3, 0,
	}

  vertex_buffer   = engine.device->newBufferWithSlice(positions[:], {.StorageModeManaged})
  index_buffer    = engine.device->newBufferWithSlice(indices[:],   {.StorageModeManaged})
  instance_buffer = engine.device->newBufferWithLength(
    NUM_INSTANCES*size_of(Instance_Data),
    {.StorageModeManaged},
  )

  return
}

engine_run :: proc() -> (err: Error){
  vertex_buffer, index_buffer, instance_buffer := engine_build_buffers()
  defer vertex_buffer->release()
  defer index_buffer->release()
  defer instance_buffer->release()

  /* Loop until the user closes the window */
  for !GLFW.WindowShouldClose(engine.glfw_window) {

    {
      @static angle: f32
      angle += 0.01
      instance_data := instance_buffer->contentsAsSlice([]Instance_Data)[:NUM_INSTANCES]
      for instance, idx in &instance_data {
        scl :: 0.1

        i := f32(idx) / NUM_INSTANCES
        xoff := (i*2 - 1) + (1.0/NUM_INSTANCES)
        yoff := math.sin((i + angle) * math.TAU)
        instance.transform = matrix[4, 4]f32{
          scl * math.sin(angle),  scl * math.cos(angle), 0, xoff,
          scl * math.cos(angle), -scl * math.sin(angle), 0, yoff,
                              0,                      0, 0,    0,
                              0,                      0, 0,    1,
        }
        instance.color = {i, 1-i, math.sin(math.TAU * i), 1}
      }
      sz := NS.UInteger(len(instance_data)*size_of(instance_data[0]))
      instance_buffer->didModifyRange(NS.Range_Make(0, sz))
    }

    /* Render here */
    drawable := engine.metal_layer->nextDrawable()
    assert(drawable != nil)
    defer drawable->release()

    pass := MTL.RenderPassDescriptor_renderPassDescriptor()
    defer pass->release()

    color_attachment := pass->colorAttachments()->object(0)
    assert(color_attachment != nil)
    color_attachment->setClearColor(MTL.ClearColor{0.25, 0.5, 1.0, 1.0})
    color_attachment->setLoadAction(.Clear)
    color_attachment->setStoreAction(.Store)
    color_attachment->setTexture(drawable->texture())

    command_buffer := engine.command_queue->commandBuffer()
    defer command_buffer->release()

    render_encoder := command_buffer->renderCommandEncoderWithDescriptor(pass)
    defer render_encoder->release()

    render_encoder->setRenderPipelineState(engine.pso)
    render_encoder->setVertexBuffer(vertex_buffer,   0, 0)
    render_encoder->setVertexBuffer(instance_buffer, 0, 1)
    render_encoder->drawIndexedPrimitivesWithInstanceCount(.Triangle, 6, .UInt16, index_buffer, 0, NUM_INSTANCES)

    render_encoder->endEncoding()

    command_buffer->presentDrawable(drawable)
    command_buffer->commit()

    /* Swap front and back buffers */
    GLFW.SwapBuffers(engine.glfw_window)

    /* Poll for and process events */
    GLFW.PollEvents()
  }

  return nil
}

engine_close_window :: proc() {
  GLFW.Terminate()
  GLFW.DestroyWindow(engine.glfw_window)
}

engine_cleanup :: proc() {
  if engine.is_initialized {
    engine_close_window()
    engine.device->release()
    engine.native_window->release()
    engine.metal_layer->release()
    engine.library->release()
    engine.pso->release()
    engine.command_queue->release()
  }

  free(engine)
}
