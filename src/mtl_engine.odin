package main

import MTL "vendor:darwin/Metal"
import NS "core:sys/darwin/Foundation"
import CA "vendor:darwin/QuartzCore"

import GLFW "vendor:glfw"

import "core:fmt"

WINDOW_TITLE :: "Hello Metal"
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

MTLEngine :: struct {
  is_initialized: bool,
  glfw_window:  GLFW.WindowHandle,
  device: ^MTL.Device,
  native_window: ^NS.Window,
  metal_layer: ^CA.MetalLayer, // swapchain
  library: ^MTL.Library,
  pso: ^MTL.RenderPipelineState,
  command_queue: ^MTL.CommandQueue,
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
  engine_build_shaders()
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
  shader_src := `
  #include <metal_stdlib>
	using namespace metal;

	struct v2f {
		float4 position [[position]];
		half3 color;
	};

	v2f vertex vertex_main(uint vertex_id                        [[vertex_id]],
	                       device const packed_float3* positions [[buffer(0)]],
	                       device const packed_float3* colors    [[buffer(1)]]) {
		v2f o;
		o.position = float4(positions[vertex_id], 1.0);
		o.color = half3(colors[vertex_id]);
		return o;
	}

	half4 fragment fragment_main(v2f in [[stage_in]]) {
		return half4(in.color, 1.0);
	}
  `
  shader_src_str := NS.String.alloc()->initWithOdinString(shader_src)
  defer shader_src_str->release()

  engine.library = engine.device->newLibraryWithSource(shader_src_str, nil) or_return

  vertex_function := engine.library->newFunctionWithName(NS.AT("vertex_main"))
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

engine_build_buffers :: proc() -> (vertex_positions_buffer, vertex_colors_buffer: ^MTL.Buffer) {
  NUM_VERTICES :: 3

  positions := [NUM_VERTICES][3]f32{
    { -0.8,  0.8, 0.0 },
    {  0.0, -0.8, 0.0 },
    { +0.8,  0.8, 0.0 },
  }

  colors := [NUM_VERTICES][3]f32{
    { 1.0, 0.3, 0.2 },
    { 0.8, 1.0, 0.0 },
    { 0.8, 0.0, 1.0 },
  }

  vertex_positions_buffer = engine.device->newBufferWithSlice(positions[:], {.StorageModeManaged})
  vertex_colors_buffer    = engine.device->newBufferWithSlice(colors[:],    {.StorageModeManaged})

  return
}

engine_run :: proc() -> (err: Error){
  vertex_positions_buffer, vertex_colors_buffer := engine_build_buffers()

  /* Loop until the user closes the window */
  for !GLFW.WindowShouldClose(engine.glfw_window) {

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
    render_encoder->setVertexBuffer(vertex_positions_buffer, 0, 0)
    render_encoder->setVertexBuffer(vertex_colors_buffer,    0, 1)
    render_encoder->drawPrimitives(.Triangle, 0, 3)

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
