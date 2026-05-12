import SwiftUI

struct NumericTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .onChange(of: text) { _, newValue in
                let digitsOnly = newValue.filter(\.isNumber)

                if digitsOnly != newValue {
                    text = digitsOnly
                }
            }
    }
}
