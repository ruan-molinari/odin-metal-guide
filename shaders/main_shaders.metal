#include <metal_stdlib>
using namespace metal;

struct v2f {
  float4 position [[position]];
  half3 color;
};

struct Vertex_data {
  device packed_float3* positions [[id(0)]];
  device packed_float3* colors    [[id(1)]];
};

v2f vertex vertex_main(device const Vertex_data* vertex_data [[buffer(0)]],
                       uint vertex_id [[vertex_id]]) {
  v2f o;
  o.position = float4(vertex_data->positions[vertex_id], 1.0);
  o.color = half3(vertex_data->colors[vertex_id]);
  return o;
}

half4 fragment fragment_main(v2f in [[stage_in]]) {
  return half4(in.color, 1.0);
}
