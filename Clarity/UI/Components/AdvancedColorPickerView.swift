//
//  AdvancedColor human.swift
//  Clarity
//
//  Professional color picker with Grid, Spectrum, and Sliders tabs
//

import SwiftUI

struct AdvancedColorPickerView: View {
    @Binding var selectedColor: String
    @State private var selectedTab: ColorPickerTab = .grid
    @Environment(\.dismiss) private var dismiss

    private enum ColorPickerTab: String, CaseIterable {
        case grid = "Cuadrícula"
        case spectrum = "Espectro"
        case sliders = "Reguladores"

        var icon: String {
            switch self {
            case .grid: return "square.grid.3x3.fill"
            case .spectrum: return "paintpalette.fill"
            case .sliders: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)

                Text("Colores")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            // Tab Selector
            HStack(spacing: 0) {
                ForEach(ColorPickerTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                        HapticManager.shared.selection()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab ? Color.secondary.opacity(0.2) : Color.clear
                        )
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .padding(.horizontal)

            // Content
            TabView(selection: $selectedTab) {
                GridColorPicker(selectedColor: $selectedColor)
                    .tag(ColorPickerTab.grid)

                SpectrumColorPicker(selectedColor: $selectedColor)
                    .tag(ColorPickerTab.spectrum)

                SlidersColorPicker(selectedColor: $selectedColor)
                    .tag(ColorPickerTab.sliders)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Selected Color Preview
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: selectedColor))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                Button {
                    // Add current color to custom colors
                    HapticManager.shared.impact(.medium)
                    dismiss()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Grid Color Picker

struct GridColorPicker: View {
    @Binding var selectedColor: String

    // Full spectrum color grid (grayscale + full rainbow)
    private let colorGrid: [[String]] = [
        // Grayscale row
        [
            "#FFFFFF", "#F5F5F5", "#E8E8E8", "#D3D3D3", "#BBBBBB", "#A0A0A0", "#888888", "#707070",
            "#505050", "#2F2F2F", "#000000",
        ],
        // Dark saturated colors
        [
            "#1E3A5F", "#003D7A", "#002D5C", "#5B0080", "#6B003B", "#8B0000", "#7A3E00", "#6B4F00",
            "#4A5F00", "#00472E",
        ],
        // Medium saturated colors
        [
            "#2E5F8F", "#0066CC", "#0052A3", "#8A2BE2", "#C71585", "#DC143C", "#D2691E", "#DAA520",
            "#8FBC8F", "#2E8B57",
        ],
        // Bright saturated colors
        [
            "#4A90E2", "#1E90FF", "#00BFFF", "#9370DB", "#FF1493", "#FF0000", "#FF8C00", "#FFD700",
            "#ADFF2F", "#00FF7F",
        ],
        // Pastel colors
        [
            "#ADD8E6", "#87CEEB", "#87CEFA", "#DDA0DD", "#FFB6C1", "#FFA07A", "#FFD39B", "#FFEC8B",
            "#D4EE9F", "#98FB98",
        ],
        // Very light pastels
        [
            "#E6F3FF", "#D4E6F1", "#D6EAF8", "#E8DAEF", "#FADBD8", "#F5CBA7", "#FCF3CF", "#FDEBD0",
            "#E9F7EF", "#D5F4E6",
        ],
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(colorGrid, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { colorHex in
                            Button {
                                selectedColor = colorHex
                                HapticManager.shared.selection()
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: colorHex))
                                    .frame(height: 34)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(
                                                selectedColor == colorHex
                                                    ? Color.blue : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Spectrum Color Picker

struct SpectrumColorPicker: View {
    @Binding var selectedColor: String
    @State private var hue: Double = 0.5
    @State private var saturation: Double = 1.0
    @State private var brightness: Double = 1.0

    var body: some View {
        VStack(spacing: 24) {
            // 2D Saturation-Brightness picker
            GeometryReader { geometry in
                ZStack {
                    // Background gradient (saturation & brightness)
                    LinearGradient(
                        colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(12)

                    // Selection indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 2))
                        .position(
                            x: saturation * geometry.size.width,
                            y: (1 - brightness) * geometry.size.height
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            saturation = min(max(value.location.x / geometry.size.width, 0), 1)
                            brightness = 1 - min(max(value.location.y / geometry.size.height, 0), 1)
                            updateColor()
                        }
                )
            }
            .frame(height: 280)

            // Hue slider
            VStack(spacing: 8) {
                Text("Tono")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Rainbow gradient
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hue: 0, saturation: 1, brightness: 1),
                                Color(hue: 0.17, saturation: 1, brightness: 1),
                                Color(hue: 0.33, saturation: 1, brightness: 1),
                                Color(hue: 0.5, saturation: 1, brightness: 1),
                                Color(hue: 0.67, saturation: 1, brightness: 1),
                                Color(hue: 0.83, saturation: 1, brightness: 1),
                                Color(hue: 1.0, saturation: 1, brightness: 1),
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 28)
                        .cornerRadius(14)

                        // Thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.2), lineWidth: 2))
                            .offset(x: hue * (geometry.size.width - 28))
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                hue = min(max(value.location.x / geometry.size.width, 0), 1)
                                updateColor()
                            }
                    )
                }
                .frame(height: 28)
            }
        }
        .padding()
        .onAppear {
            // Initialize from current selectedColor
            let initColor = Color(hex: selectedColor)
            let uiColor1 = UIColor(initColor)
            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uiColor1.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            hue = Double(h)
            saturation = Double(s)
            brightness = Double(b)
        }
        .onChange(of: selectedColor) { _, newColor in
            let color = Color(hex: newColor)
            let uiColor2 = UIColor(color)
            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uiColor2.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            hue = Double(h)
            saturation = Double(s)
            brightness = Double(b)
        }
    }

    private func updateColor() {
        let color = Color(hue: hue, saturation: saturation, brightness: brightness)
        selectedColor = color.toHex() ?? selectedColor
        HapticManager.shared.selection()
    }
}

// MARK: - Sliders Color Picker

struct SlidersColorPicker: View {
    @Binding var selectedColor: String
    @State private var red: Double = 0.5
    @State private var green: Double = 0.5
    @State private var blue: Double = 0.5

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Red Slider
            ColorSliderView(
                value: $red,
                color: .red,
                label: "Rojo",
                colorValue: Int(red * 255)
            )
            .onChange(of: red) { _, _ in updateColor() }

            // Green Slider
            ColorSliderView(
                value: $green,
                color: .green,
                label: "Verde",
                colorValue: Int(green * 255)
            )
            .onChange(of: green) { _, _ in updateColor() }

            // Blue Slider
            ColorSliderView(
                value: $blue,
                color: .blue,
                label: "Azul",
                colorValue: Int(blue * 255)
            )
            .onChange(of: blue) { _, _ in updateColor() }

            // Hex input
            HStack {
                Text("Hex:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(selectedColor.uppercased())
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .onAppear {
            let initColor = Color(hex: selectedColor)
            let uiColor3 = UIColor(initColor)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b2: CGFloat = 0
            var a: CGFloat = 0
            uiColor3.getRed(&r, green: &g, blue: &b2, alpha: &a)
            red = Double(r)
            green = Double(g)
            blue = Double(b2)
        }
        .onChange(of: selectedColor) { _, newColor in
            let color = Color(hex: newColor)
            let uiColor4 = UIColor(color)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b2: CGFloat = 0
            var a: CGFloat = 0
            uiColor4.getRed(&r, green: &g, blue: &b2, alpha: &a)
            red = Double(r)
            green = Double(g)
            blue = Double(b2)
        }
    }

    private func updateColor() {
        selectedColor = Color(red: red, green: green, blue: blue).toHex() ?? selectedColor
        HapticManager.shared.selection()
    }
}

// MARK: - Color Slider Component

struct ColorSliderView: View {
    @Binding var value: Double
    let color: Color
    let label: String
    let colorValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(colorValue)")
                    .font(.system(.body, design: .monospaced))
            }

            Slider(value: $value, in: 0...1)
                .tint(color)
        }
    }
}

// MARK: - Color Extension

extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    @Previewable @State var color = "#007AFF"
    return AdvancedColorPickerView(selectedColor: $color)
        .frame(height: 600)
}
