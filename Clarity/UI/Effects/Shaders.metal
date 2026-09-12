// Shaders.metal
// Dos efectos de diez líneas que SwiftUI aplica directo a la vista (#65).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// Onda de agua desde el punto tocado. Desplaza cada píxel radialmente con
/// un seno amortiguado que tarda en llegar según la distancia al origen.
[[ stitchable ]] float2 onda(float2 position, float2 origen, float tiempo,
                             float amplitud, float frecuencia, float decaimiento, float velocidad) {
    float distancia = length(position - origen);
    float t = max(0.0, tiempo - distancia / velocidad);
    float desplazamiento = amplitud * sin(frecuencia * t) * exp(-decaimiento * t);
    float2 n = distancia > 0.0 ? normalize(position - origen) : float2(0.0);
    return position + desplazamiento * n;
}

/// Banda de brillo que cruza la vista de izquierda a derecha una sola vez.
[[ stitchable ]] half4 destello(float2 position, half4 color, float2 tamano, float progreso) {
    float x = (position.x + position.y * 0.35) / (tamano.x + tamano.y * 0.35);
    float centro = progreso * 1.4 - 0.2;
    float banda = exp(-pow((x - centro) / 0.06, 2.0));
    return color + half4(half3(banda * 0.35), 0.0) * color.a;
}
