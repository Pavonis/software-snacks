import SwiftUI

struct NoteEntryView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var noteProcessor: NoteProcessor

    @State private var noteText = ""
    @State private var pendingNote: Note?
    @State private var showingExtractionPreview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Text input area
                TextEditor(text: $noteText)
                    .font(.body)
                    .padding()
                    .overlay(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("Write a note about someone...\n\nExample: \"Had coffee with Sarah today. She mentioned she's starting a new job at Google next month. Her new number is 555-0123.\"")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                                .allowsHitTesting(false)
                        }
                    }

                Divider()

                // Action bar
                HStack {
                    if noteProcessor.isProcessing {
                        ProgressView()
                            .padding(.horizontal)
                        Text("Processing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if !noteProcessor.isAvailable {
                        Label("Apple Intelligence unavailable", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Button {
                        Task {
                            await processNote()
                        }
                    } label: {
                        Label("Process", systemImage: "sparkles")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(canProcess ? .blue : .gray.opacity(0.3))
                            .foregroundStyle(canProcess ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                    .disabled(!canProcess)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("New Note")
            .sheet(isPresented: $showingExtractionPreview) {
                if let note = pendingNote {
                    ExtractionPreviewView(note: note) {
                        // On save
                        noteText = ""
                        pendingNote = nil
                    }
                }
            }
        }
    }

    private var canProcess: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !noteProcessor.isProcessing
            && noteProcessor.isAvailable
    }

    private func processNote() async {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            let extraction = try await noteProcessor.process(noteText: text)
            var note = Note(text: text)
            note.extraction = extraction
            pendingNote = note
            showingExtractionPreview = true
        } catch {
            print("Failed to process note: \(error)")
        }
    }
}

#Preview {
    NoteEntryView()
        .environmentObject(ContactsManager())
        .environmentObject(NoteProcessor())
}
