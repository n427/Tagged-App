import SwiftUI
import Combine

// MARK: - KeyboardResponder

// Observes keyboard show/hide notifications and publishes the keyboard height.
// Useful for adjusting view layouts when the keyboard appears.
final class KeyboardResponder: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var keyboardHeight: CGFloat = 0

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)

        let willChange = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)

        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)

        // MARK: - Keyboard Appearing / Frame Changing

        willShow
            .merge(with: willChange)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .sink { [weak self] frame in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = frame.height
                }
            }
            .store(in: &cancellables)

        // MARK: - Keyboard Disappearing

        willHide
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = 0
                }
            }
            .store(in: &cancellables)
    }
}
