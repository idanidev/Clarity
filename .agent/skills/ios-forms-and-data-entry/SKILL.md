---
name: ios-forms-and-data-entry
description: Master iOS data entry patterns, forms, and list-based editing to create frictionless user input experiences.
---

# iOS Forms and Data Entry

Master iOS data entry patterns using SwiftUI's Form, List, and modern text input APIs to create frictionless, native-feeling user input experiences.

## When to Use This Skill

- Designing settings screens or preferences
- Building data entry forms (like adding an expense or creating a category)
- Implementing inline editing in lists
- Handling complex user input (colors, dates, pickers)
- Managing keyboard interactions and focus state
- Validating user input gracefully

## Core Concepts

### 1. The Power of `Form`

SwiftUI's `Form` automatically adapts its appearance based on the platform and context. On iOS, it provides the standard grouped list appearance with proper section headers, footers, and spacing.

```swift
Form {
    Section {
        TextField("Name", text: $name)
        Toggle("Notifications", isOn: $alertsEnabled)
    } header: {
        Text("Profile")
    } footer: {
        Text("Your name will be visible to other users.")
    }
}
```

### 2. Ergonomic Data Entry

**Avoid custom pickers when native ones exist:**

```swift
// GOOD: Native ColorPicker
ColorPicker("Category Color", selection: $categoryColor, supportsOpacity: false)

// GOOD: Native DatePicker
DatePicker("Transaction Date", selection: $date, displayedComponents: .date)
```

**If you must build a custom picker, use horizontal scrolling for compact visual selection:**

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 12) {
        ForEach(colors, id: \.self) { color in
            Circle()
                .fill(color)
                .frame(width: 44, height: 44) // 44pt minimum hit target!
                .overlay {
                    if selected == color {
                        Image(systemName: "checkmark")
                    }
                }
                .onTapGesture { selected = color }
        }
    }
    .padding(.horizontal)
}
```

### 3. Inline List Editing

Instead of navigating to a new screen or opening a sheet just to add a simple string (like a subcategory or a tag), permit inline editing at the bottom of a list.

```swift
Section("Tags") {
    ForEach($tags) { $tag in
        TextField("Tag name", text: $tag.name)
    }
    .onDelete(perform: deleteTags)

    // Inline Add Row
    HStack {
        Image(systemName: "plus.circle.fill")
            .foregroundColor(.green)
        TextField("New tag...", text: $newTagText)
            .onSubmit {
                guard !newTagText.isEmpty else { return }
                tags.append(Tag(name: newTagText))
                newTagText = "" // Ready for the next one
            }
    }
}
```

### 4. Graceful Validation

Never scream at the user with bright red boxes while they are typing.

**Best Practices for Validation:**

1. Disable the "Save" button until requirements are met.
2. Provide gentle, inline text explanations below the field.
3. Prevent invalid characters from being typed entirely (using `onChange`).

```swift
TextField("Username", text: $username)
    .onChange(of: username) { oldValue, newValue in
        // Strip invalid characters silently
        let validChars = newValue.filter { $0.isLetter || $0.isNumber }
        if username != validChars {
            username = validChars
        }
    }
```

### 5. Keyboard and Focus Management

Use FocusState to guide the user automatically to the next logical step.

```swift
@FocusState private var focusedField: Field?

enum Field {
    case amount, notes
}

TextField("Amount", value: $amount, format: .currency(code: "USD"))
    .keyboardType(.decimalPad)
    .focused($focusedField, equals: .amount)
    .onSubmit { focusedField = .notes }

TextField("Notes", text: $notes)
    .focused($focusedField, equals: .notes)
```

## Anti-Patterns (What to Avoid)

- **Avoiding 44x44pt Hit Targets:** Never make tappable buttons smaller than 44x44pt (Apple HIG).
- **Custom Modals for Simple Inputs:** Don't present a full `.sheet` just to ask for a single text string.
- **Redundant Actions:** Don't put "Save" buttons on every row of a list. Let edits auto-save or provide one global "Save" at the top trailing edge of the navigation bar.
- **Burying Primary Actions:** Don't hide the "Add Item" button at the bottom of a 100-item list or nested deeply. Use the Toolbar or the top of the section.
