#!/bin/sh
# ci_scripts/ci_post_clone.sh
# Xcode Cloud lo ejecuta nada más clonar el repo, antes de resolver paquetes y
# compilar. Deja listo lo que en el Mac existe y en git no.
#
# 1. `Clarity/Core/Secrets.swift` está en .gitignore. Se crea con las claves de
#    las variables de entorno del workflow (GEMINI_API_KEY, GROQ_API_KEY) o
#    vacías: la IA está deshabilitada y `AIService` trata la cadena vacía como
#    «sin clave». El proyecto usa PBXFileSystemSynchronized, así que el fichero
#    entra en el target por estar en disco.
# 2. Los shaders de la Home necesitan el Metal Toolchain, que desde Xcode 26 es
#    un componente aparte. Si la imagen ya lo trae, no hace nada.
set -eu
cd "$(dirname "$0")/.."

destino="Clarity/Core/Secrets.swift"
if [ -f "$destino" ]; then
  echo "ci_post_clone: $destino ya existe, no se toca"
else
  cat > "$destino" <<SWIFT
// Secrets.swift — generado por ci_scripts/ci_post_clone.sh en Xcode Cloud.
// No se versiona: en el Mac lo escribe el desarrollador a mano.
enum Secrets {
    static let geminiAPIKey = "${GEMINI_API_KEY:-}"
    static let groqAPIKey = "${GROQ_API_KEY:-}"
}
SWIFT
  echo "ci_post_clone: $destino creado"
fi

xcodebuild -downloadComponent MetalToolchain || echo "ci_post_clone: Metal Toolchain no descargado; si el archive falla por Metal, es esto"
