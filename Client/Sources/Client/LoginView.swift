import SwiftUI
import Common

@MainActor struct LoginView: View {
    @State private var viewModel = LoginViewModel()

    var body: some View {
        VStack {
            Text("Yelpepperoni 🍕")
                .bold()
                .font(.title)

            TextField("Username", text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            if case .error(let error) = viewModel.phase {
                Text("Error: \(error)")
            }

            HStack {
                Button("Sign Up") {
                    viewModel.signUp()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

                Button("Log In") {
                    viewModel.logIn()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .padding()
    }
}

@MainActor @Observable final class LoginViewModel {
    enum Phase {
        case ready, loading, error(Error)
    }

    var username = ""
    var password = ""
    var phase: Phase = .ready

    var isLoading: Bool {
        if case .loading = phase { true } else { false }
    }

    func logIn() {
        doAuth { [self] in
            try await APIClient.shared.login(username: username, password: password)
        }
    }

    func signUp() {
        doAuth { [self] in
            try await APIClient.shared.createAccount(username: username, password: password)
        }
    }

    private func doAuth(_ perform: @escaping () async throws -> ClientToken) {
        Task {
            phase = .loading
            let token: ClientToken
            do {
                token = try await perform()
            } catch {
                phase = .error(error)
                password = ""
                return
            }
            AuthManager.shared.token = token.value
            phase = .ready
            password = ""
        }
    }
}

#Preview {
    LoginView()
}
