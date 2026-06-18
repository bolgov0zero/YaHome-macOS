import SwiftUI

struct AuthView: View {
    @EnvironmentObject var state: AppState
    @State private var tokenInput = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "house.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("YaHome")
                .font(.largeTitle.bold())

            Text("Введите токен Яндекс ID для подключения к умному дому")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                Text("OAuth токен").font(.caption).foregroundStyle(.secondary)
                SecureField("y0_AgAAAA...", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
            }

            if let err = state.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await state.authenticate(token: tokenInput.trimmingCharacters(in: .whitespaces)) }
            } label: {
                HStack {
                    if state.isLoading {
                        ProgressView().controlSize(.small)
                    }
                    Text("Войти")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(tokenInput.isEmpty || state.isLoading)
            .keyboardShortcut(.return)

            Link("Получить токен на Яндексе",
                 destination: URL(string: "https://oauth.yandex.ru/authorize?response_type=token&client_id=c473ca268cd749d3a8371351a8f2bcbd")!)
                .font(.caption)
        }
        .padding(40)
        .frame(width: 400)
        .onAppear { focused = true }
    }
}
