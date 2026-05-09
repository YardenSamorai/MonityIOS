import SwiftUI
import UIKit

/// Foreground colors for the amount field. Use ``onTintedCard`` on colored gradients; ``onCanvas`` on light/canvas backgrounds.
enum CurrencyTextFieldStyle {
    case onTintedCard
    case onCanvas
}

/// Currency / amount input.
///
/// Wraps a real `UITextField` (instead of SwiftUI's `TextField`) for two reasons that came up in production:
/// 1) SwiftUI's amount-style large rounded `TextField` had a render bug where typed digits stayed invisible
///    until the user pressed delete once. UITextField does not have that quirk.
/// 2) We need a "Done" key on the decimal pad — `decimalPad` has no Return key, so without an explicit toolbar
///    the keyboard never dismisses when the user taps another field type.
struct CurrencyTextField: View {
    let title: LocalizedStringKey
    @Binding var value: String
    var currency: String = "ILS"
    var style: CurrencyTextFieldStyle = .onTintedCard
    var autoFocus: Bool = true

    private var symbolColor: Color {
        switch style {
        case .onTintedCard: return Color.white.opacity(0.9)
        case .onCanvas: return Color.primary.opacity(0.9)
        }
    }

    private var amountUIColor: UIColor {
        switch style {
        case .onTintedCard: return .white
        case .onCanvas: return .label
        }
    }

    private var promptUIColor: UIColor {
        switch style {
        case .onTintedCard: return UIColor.white.withAlphaComponent(0.4)
        case .onCanvas: return UIColor.secondaryLabel.withAlphaComponent(0.55)
        }
    }

    private var tintUIColor: UIColor {
        switch style {
        case .onTintedCard: return .white
        case .onCanvas: return UIColor(AppTheme.accent)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(CurrencyHelper.symbol(for: currency))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(symbolColor)

            AmountUITextField(
                text: $value,
                placeholder: "0",
                textColor: amountUIColor,
                placeholderColor: promptUIColor,
                tintColor: tintUIColor,
                font: .monospacedDigitSystemFont(ofSize: 48, weight: .bold),
                autoFocus: autoFocus
            )
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// UIKit-backed numeric input. Stable rendering, automatic Done button on the keyboard.
private struct AmountUITextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var textColor: UIColor
    var placeholderColor: UIColor
    var tintColor: UIColor
    var font: UIFont
    var autoFocus: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.keyboardType = .decimalPad
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.font = font
        tf.textColor = textColor
        tf.tintColor = tintColor
        tf.textAlignment = .left
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: font,
            ]
        )
        tf.inputAccessoryView = makeKeyboardToolbar(target: context.coordinator)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.text = text

        if autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak tf] in
                tf?.becomeFirstResponder()
            }
        }

        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.textColor != textColor {
            uiView.textColor = textColor
        }
        if uiView.tintColor != tintColor {
            uiView.tintColor = tintColor
        }
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: font,
            ]
        )
    }

    private func makeKeyboardToolbar(target: Coordinator) -> UIToolbar {
        let bar = UIToolbar()
        bar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: target,
            action: #selector(Coordinator.dismissKeyboardTapped)
        )
        bar.items = [flex, done]
        bar.tintColor = UIColor(AppTheme.accent)
        bar.isTranslucent = true
        return bar
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            let raw = sender.text ?? ""
            let cleaned = sanitize(raw)
            if cleaned != raw {
                sender.text = cleaned
            }
            if cleaned != text {
                text = cleaned
            }
        }

        @objc func dismissKeyboardTapped() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        private func sanitize(_ s: String) -> String {
            var result = ""
            var sawSeparator = false
            for ch in s {
                if ch.isNumber {
                    result.append(ch)
                } else if ch == "." || ch == "," {
                    if sawSeparator { continue }
                    sawSeparator = true
                    result.append(".")
                }
            }
            return result
        }
    }
}
