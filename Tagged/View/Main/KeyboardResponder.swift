import SwiftUI
import Combine

final class KeyboardResponder: ObservableObject {
    
    @Published var keyboardHeight: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)

        let willChange = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)

        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)

        willShow
            .merge(with: willChange)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .sink { [weak self] frame in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = frame.height
                }
            }
            .store(in: &cancellables)


        willHide
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = 0
                }
            }
            .store(in: &cancellables)
    }
}
