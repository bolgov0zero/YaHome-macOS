import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var tokenVisible = false
    @State private var copied = false
    @State private var autostartEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Настройки").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            VStack(spacing: 0) {
                // API Token section
                settingsSection("API Токен") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Токен используется для доступа к Yandex Smart Home API.")
                            .font(.caption).foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            if tokenVisible {
                                Text(state.token ?? "—")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text(maskedToken)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))

                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { tokenVisible.toggle() }
                            } label: {
                                Label(tokenVisible ? "Скрыть" : "Показать",
                                      systemImage: tokenVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered).controlSize(.small)

                            Button {
                                if let t = state.token {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(t, forType: .string)
                                    withAnimation { copied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation { copied = false }
                                    }
                                }
                            } label: {
                                Label(copied ? "Скопировано" : "Копировать",
                                      systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered).controlSize(.small)

                            Spacer()

                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { state.logout() }
                            } label: {
                                Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                            .tint(.red)
                        }
                    }
                }

                Divider().padding(.horizontal, 20)

                // Autostart section
                settingsSection("Автозапуск") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Запускать при входе в систему")
                                .font(.system(size: 13))
                            Text("Приложение будет автоматически запускаться и отображаться в панели меню.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $autostartEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: autostartEnabled) { newValue in
                                setAutostart(newValue)
                            }
                    }
                }

                Divider().padding(.horizontal, 20)

                // About section
                settingsSection("О приложении") {
                    HStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("YaHome").font(.system(size: 14, weight: .semibold))
                            Text("Управление Яндекс Умным домом").font(.caption).foregroundStyle(.secondary)
                            Text("macOS · Swift + SwiftUI").font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.bottom, 10)
        }
        .frame(width: 480)
        .onAppear { autostartEnabled = isAutostartEnabled() }
    }

    // MARK: - Helpers
    private var maskedToken: String {
        guard let t = state.token, t.count > 8 else { return "••••••••" }
        return String(t.prefix(4)) + String(repeating: "•", count: min(t.count - 8, 20)) + String(t.suffix(4))
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            content()
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    // MARK: - Autostart via SMAppService
    private func isAutostartEnabled() -> Bool {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setAutostart(_ enable: Bool) {
        if #available(macOS 13, *) {
            do {
                if enable { try SMAppService.mainApp.register() }
                else      { try SMAppService.mainApp.unregister() }
            } catch {
                print("Autostart error:", error)
            }
        }
    }
}
