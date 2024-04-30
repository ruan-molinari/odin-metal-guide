package main

import "core:mem"

Window_Error :: enum {
	None,
	Create_GLFW_Window_Failed,
	Create_Window_Failed,
}

Metal_Error :: enum {
  None,
  Create_Device_Failed,
}

OS_Error :: enum {
	None,
	Read_File_Failed,
}

Error :: union #shared_nil {
  Window_Error,
  OS_Error,
  Metal_Error,
  mem.Allocator_Error,
}
