---
paths:
  - "Clarity/Features/AIAdvisor/**/*.swift"
  - "Clarity/Features/Voice/**/*.swift"
---

# Reglas AI Service — Clarity

## Proveedores disponibles
- **Gemini**: configurado en código, modelo gemini-2.0-flash-lite
- **Groq**: API key en UserDefaults, modelos llama3/mixtral

## PromptBuilder
- Construye contexto financiero token-efficient para la IA
- Siempre incluir: gastos del mes, presupuesto, categoría top, tendencia
- Máximo ~500 tokens de contexto financiero para no saturar el modelo
- Los prompts de sistema están en `PromptBuilder.swift` — editar ahí, no inline

## Voice / SmartTransactionParser
- El parser extrae: importe, descripción, categoría, fecha del texto hablado
- `UserLearningManager` aprende preferencias del usuario (categorías frecuentes)
- Nunca añadir la palabra "añade" o "añadir" al nombre del gasto parseado
- Limpiar siempre los verbos de comando del texto reconocido
- Si el importe no se detecta → mostrar confirmación al usuario antes de guardar

## Siri / App Intents
- Los Intents están en `Clarity/App/Widget/`
- Siempre validar que el importe sea > 0 antes de crear el gasto
