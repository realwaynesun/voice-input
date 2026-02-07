import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

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
            SecureField("OpenAI API Key", text: state.openAIKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: appState.openAIKey) { _, newValue in
                    if newValue.isEmpty {
                        KeychainHelper.delete(key: "openai_api_key")
                    } else {
                        KeychainHelper.save(key: "openai_api_key", value: newValue)
                    }
                }
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
}
