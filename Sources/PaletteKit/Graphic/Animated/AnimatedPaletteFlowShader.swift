import Foundation

/// Inline Metal source for the animated palette gradient, compiled at runtime via
/// `device.makeLibrary(source:)` — no `.metal` resource / metallib bundle (matches
/// ``MetalContext`` and ColorfulX). Multi-point inverse-distance blend in LAB.
enum AnimatedPaletteFlowShader {
    /// Maximum number of color points the uniforms carry.
    static let slots = 8

    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut { float4 pos [[position]]; float2 uv; };

    vertex VOut paletteFlowVertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.pos = float4(p * 2.0 - 1.0, 0, 1);
        o.uv = float2(p.x, 1.0 - p.y);
        return o;
    }

    struct FlowUniforms {
        int count;
        float bias;
        float power;
        float pad;
        float2 points[8];
        float4 colors[8];   // xyz = CIE LAB
    };

    static float3 lab2xyz(float3 lab) {
        float y = (lab.x + 16.0) / 116.0;
        float x = lab.y / 500.0 + y;
        float z = y - lab.z / 200.0;
        float3 v = float3(x, y, z);
        float3 v3 = v * v * v;
        float3 xyz = select((v - 16.0 / 116.0) / 7.787, v3, v3 > 0.008856);
        return xyz * float3(95.047, 100.0, 108.883);
    }
    static float3 xyz2rgb(float3 xyz) {
        float3 t = xyz / 100.0;
        float3 c = float3(
            t.x * 3.2406 + t.y * -1.5372 + t.z * -0.4986,
            t.x * -0.9689 + t.y * 1.8758 + t.z * 0.0415,
            t.x * 0.0557 + t.y * -0.2040 + t.z * 1.0570);
        c = select(12.92 * c, 1.055 * pow(c, 1.0 / 2.4) - 0.055, c > 0.0031308);
        return clamp(c, 0.0, 1.0);
    }
    static float3 lab2rgb(float3 lab) { return xyz2rgb(lab2xyz(lab)); }

    fragment float4 paletteFlowFragment(VOut in [[stage_in]], constant FlowUniforms& U [[buffer(0)]]) {
        float2 uv = in.uv;
        float total = 0.0;
        float contrib[8];
        for (int i = 0; i < U.count; i++) {
            float dist = length(uv - U.points[i]);
            float c = 1.0 / (U.bias + pow(dist, U.power));
            contrib[i] = c;
            total += c;
        }
        float3 lab = float3(0.0);
        for (int i = 0; i < U.count; i++) {
            lab += U.colors[i].xyz * (contrib[i] / total);
        }
        return float4(lab2rgb(lab), 1.0);
    }
    """
}
