#include <metal_stdlib>
using namespace metal;

// Builds a 5-bit-per-channel 3D histogram (32,768 bins) over a flat RGB
// pixel buffer. Each pixel is packed as three consecutive UInt8 values.
//
// One threadgroup processes one slab of pixels. Bins are atomically
// accumulated into a single global histogram so subsequent median-cut
// passes (on CPU) can read a contiguous Uint32 array.
kernel void mmcq_build_histogram(
    device const uchar *pixels [[buffer(0)]],
    device atomic_uint *histogram [[buffer(1)]],
    constant uint &pixelCount [[buffer(2)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid >= pixelCount) { return; }
    const uint offset = tid * 3u;
    const uint r = uint(pixels[offset]) >> 3u;
    const uint g = uint(pixels[offset + 1u]) >> 3u;
    const uint b = uint(pixels[offset + 2u]) >> 3u;
    const uint index = (r << 10u) + (g << 5u) + b;
    atomic_fetch_add_explicit(&histogram[index], 1u, memory_order_relaxed);
}
