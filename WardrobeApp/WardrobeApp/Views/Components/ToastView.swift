import SwiftUI

struct ToastMessage: Equatable {
    let icon: String
    let text: String
    let style: ToastStyle

    enum ToastStyle {
        case success, info, warning
    }

    static func success(_ text: String) -> ToastMessage {
        ToastMessage(icon: "checkmark.circle.fill", text: text, style: .success)
    }

    static func info(_ text: String) -> ToastMessage {
        ToastMessage(icon: "info.circle.fill", text: text, style: .info)
    }

    static func warning(_ text: String) -> ToastMessage {
        ToastMessage(icon: "exclamationmark.triangle.fill", text: text, style: .warning)
    }
}

struct ToastOverlay: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                HStack(spacing: DS.spacingSM) {
                    Image(systemName: toast.icon)
                        .foregroundStyle(iconColor(toast.style))

                    Text(toast.text)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingMD)
                .background {
                    Capsule()
                        .fill(.ultraThickMaterial)
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
                }
                .padding(.top, DS.spacingSM)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            self.toast = nil
                        }
                    }
                }
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast)
    }

    private func iconColor(_ style: ToastMessage.ToastStyle) -> Color {
        switch style {
        case .success: return .green
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlay(toast: message))
    }
}
