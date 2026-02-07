import SwiftUI

struct DictionaryView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var newTrigger = ""
    @State private var newReplacement = ""

    var body: some View {
        VStack(spacing: 0) {
            addEntryBar
            Divider()
            entryList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addEntryBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.blue)
            TextField("Whisper outputs...", text: $newTrigger)
                .textFieldStyle(.roundedBorder)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            TextField("Replace with...", text: $newReplacement)
                .textFieldStyle(.roundedBorder)
            Button("Add") { addEntry() }
                .disabled(newTrigger.isEmpty || newReplacement.isEmpty)
        }
        .padding(16)
    }

    private var entryList: some View {
        Table(dataStore.sortedDictionaryEntries) {
            TableColumn("Enabled") { entry in
                Toggle("", isOn: toggleBinding(for: entry))
                    .labelsHidden()
            }
            .width(60)

            TableColumn("Trigger") { entry in
                Text(entry.trigger)
                    .font(.body.monospaced())
            }

            TableColumn("Replacement") { entry in
                Text(entry.replacement)
                    .font(.body.monospaced())
            }

            TableColumn("") { entry in
                Button(role: .destructive) {
                    dataStore.deleteDictionaryEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .width(40)
        }
        .overlay {
            if dataStore.dictionaryEntries.isEmpty {
                ContentUnavailableView(
                    "No Dictionary Entries",
                    systemImage: "book",
                    description: Text(
                        "Add custom replacements for recurring"
                        + " transcription mistakes"
                    )
                )
            }
        }
    }

    private func toggleBinding(for entry: DictionaryEntry) -> Binding<Bool> {
        Binding(
            get: { entry.isEnabled },
            set: { newValue in
                var updated = entry
                updated.isEnabled = newValue
                dataStore.updateDictionaryEntry(updated)
            }
        )
    }

    private func addEntry() {
        let entry = DictionaryEntry(
            trigger: newTrigger.trimmingCharacters(in: .whitespaces),
            replacement: newReplacement.trimmingCharacters(in: .whitespaces)
        )
        dataStore.addDictionaryEntry(entry)
        newTrigger = ""
        newReplacement = ""
    }
}
