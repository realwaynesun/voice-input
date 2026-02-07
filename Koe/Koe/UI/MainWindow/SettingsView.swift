import SwiftUI
import Security

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var revealOpenAIKey = false
    @State private var keychainStatus: OSStatus?

    var body: some View {
        @Bindable var state = appState
        Form {
            transcriptionSection(state: $state)
            postProcessingSection(state: $state)
            apiSection(state: $state)
            generalSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshKeychainStatusAndMaybeLoadKey()
        }
    }

    private func transcriptionSection(
        state: Bindable<AppState>
    ) -> some View {
        Section("Transcription") {
            Picker("Backend", selection: state.transcriptionBackend) {
                ForEach(TranscriptionBackend.allCases) { backend in
                    Text(backend.rawValue).tag(backend)
                }
            }

            Picker("Language", selection: state.preferredLanguage) {
                ForEach(TranscriptionLanguage.allCases) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }

            if appState.transcriptionBackend == .local {
                Picker("Model Size", selection: state.modelSize) {
                    ForEach(WhisperModelSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
            }
        }
    }

    private func postProcessingSection(
        state: Bindable<AppState>
    ) -> some View {
        Section("Post-Processing") {
            Picker("Processing", selection: state.postProcessingTier) {
                ForEach(PostProcessingTier.allCases) { tier in
                    Text(tier.rawValue).tag(tier)
                }
            }

            if appState.postProcessingTier == .api {
                Text("Uses GPT-4o-mini to clean up transcriptions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func apiSection(state: Bindable<AppState>) -> some View {
        Section("API Keys") {
            HStack(spacing: 8) {
                Group {
                    if revealOpenAIKey {
                        TextField("OpenAI API Key", text: state.openAIKey)
                    } else {
                        SecureField("OpenAI API Key", text: state.openAIKey)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button(revealOpenAIKey ? "Hide" : "Show") {
                    revealOpenAIKey.toggle()
                }
                .buttonStyle(.bordered)
            }
            .onChange(of: appState.openAIKey) { _, newValue in
                if newValue.isEmpty {
                    let st = KeychainHelper.delete(key: "openai_api_key")
                    if st == errSecSuccess || st == errSecItemNotFound {
                        keychainStatus = errSecItemNotFound
                    } else {
                        keychainStatus = st
                    }
                } else {
                    keychainStatus = KeychainHelper.save(
                        key: "openai_api_key",
                        value: newValue
                    )
                }
            }

            Text(keychainStatusText)
                .font(.caption)
                .foregroundStyle(keychainStatusColor)

            Text("Required for API transcription and AI post-processing")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        Section("General") {
            LabeledContent("Hotkey") {
                KeyboardShortcutBadge(text: "Right Option")
            }
            LabeledContent("Microphone") {
                Text(currentMicName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Engine", value: "WhisperKit")
        }
    }

    private var currentMicName: String {
        "Default Input Device"
    }

    private func refreshKeychainStatusAndMaybeLoadKey() {
        let result = KeychainHelper.loadWithStatus(key: "openai_api_key")
        keychainStatus = result.status

        if appState.openAIKey.isEmpty, let key = result.value {
            appState.openAIKey = key
        }
    }

    private var keychainStatusText: String {
        guard let status = keychainStatus else {
            return "Keychain: unknown"
        }

        switch status {
        case errSecSuccess:
            return "Keychain: saved"
        case errSecItemNotFound:
            return "Keychain: not saved"
        case errSecAuthFailed:
            return "Keychain: access denied (check Keychain Access)"
        case errSecInteractionNotAllowed:
            return "Keychain: interaction not allowed"
        default:
            return "Keychain: error (status=\(status))"
        }
    }

    private var keychainStatusColor: Color {
        guard let status = keychainStatus else {
            return .secondary
        }

        switch status {
        case errSecSuccess:
            return .green
        case errSecItemNotFound:
            return .secondary
        case errSecInteractionNotAllowed:
            return .orange
        default:
            return .red
        }
    }
}
