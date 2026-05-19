import SwiftUI

struct NumericTextField: View {
    let title: String
    @Binding var text: String
    var maxDigits: Int?
    var dismissesKeyboardAtMaxDigits = false
    var textAlignment: TextAlignment = .trailing

    @FocusState private var isFocused: Bool
    @State private var showsDoneButton = false

    var body: some View {
        TextField(title, text: $text)
            .focused($isFocused)
            .keyboardType(.numberPad)
            .multilineTextAlignment(textAlignment)
            .simultaneousGesture(TapGesture().onEnded {
                showsDoneButton = true
            })
            .onChange(of: text) { _, newValue in
                let digitsOnly = newValue.filter(\.isNumber)
                let sanitizedText = maxDigits.map { String(digitsOnly.prefix($0)) } ?? String(digitsOnly)

                if sanitizedText != newValue {
                    text = sanitizedText
                }

                if dismissesKeyboardAtMaxDigits, let maxDigits, sanitizedText.count == maxDigits {
                    isFocused = false
                    showsDoneButton = false
                }
            }
            .onChange(of: isFocused) { _, newValue in
                showsDoneButton = newValue
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if showsDoneButton {
                        Spacer()
                        Button("Done") {
                            isFocused = false
                            showsDoneButton = false
                        }
                    }
                }
            }
    }
}
