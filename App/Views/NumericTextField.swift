import SwiftUI

struct NumericTextField: View {
    let title: String
    @Binding var text: String

    @FocusState private var isFocused: Bool
    @State private var showsDoneButton = false

    var body: some View {
        TextField(title, text: $text)
            .focused($isFocused)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .simultaneousGesture(TapGesture().onEnded {
                showsDoneButton = true
            })
            .onChange(of: text) { _, newValue in
                let digitsOnly = newValue.filter(\.isNumber)

                if digitsOnly != newValue {
                    text = digitsOnly
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
