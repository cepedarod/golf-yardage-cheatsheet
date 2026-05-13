import SwiftUI

struct NumericTextField: View {
    let title: String
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $text)
            .focused($isFocused)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .onChange(of: text) { _, newValue in
                let digitsOnly = newValue.filter(\.isNumber)

                if digitsOnly != newValue {
                    text = digitsOnly
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused {
                        Spacer()
                        Button("Done") {
                            isFocused = false
                        }
                    }
                }
            }
    }
}
