import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Workout.day, order: .reverse),
                  SortDescriptor(\Workout.externalID, order: .reverse)])
    private var workouts: [Workout]

    @State private var isImporting = false
    @State private var exportDocument: TransferDocument?
    @State private var message: Message?

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView {
                        Label("No workouts yet", systemImage: "dumbbell")
                    } description: {
                        Text("Import a Sport Life JSON file to bring in your history.")
                    } actions: {
                        Button("Import…") { isImporting = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                Menu {
                    Button("Import…", systemImage: "square.and.arrow.down") { isImporting = true }
                    Button("Export…", systemImage: "square.and.arrow.up", action: export)
                        .disabled(workouts.isEmpty)
                } label: {
                    Label("Data", systemImage: "ellipsis")
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                importFile(result)
            }
            .fileExporter(
                isPresented: Binding(get: { exportDocument != nil },
                                     set: { if !$0 { exportDocument = nil } }),
                document: exportDocument,
                contentType: .json,
                defaultFilename: Exporter.defaultFilename()
            ) { result in
                if case .failure(let error) = result {
                    message = Message(title: "Export failed", text: error.localizedDescription)
                }
            }
            .alert(item: $message) { message in
                Alert(title: Text(message.title), message: Text(message.text))
            }
        }
    }

    private var list: some View {
        List {
            ForEach(monthSections, id: \.month) { section in
                Section(section.title) {
                    ForEach(section.workouts) { workout in
                        NavigationLink(value: workout) {
                            WorkoutRow(workout: workout)
                        }
                    }
                }
            }
        }
    }

    private var monthSections: [(month: String, title: String, workouts: [Workout])] {
        var sections: [(month: String, title: String, workouts: [Workout])] = []
        for workout in workouts {
            let month = Day.monthKey(workout.day)
            if sections.last?.month == month {
                sections[sections.count - 1].workouts.append(workout)
            } else {
                let title = Day.date(from: workout.day)?
                    .formatted(.dateTime.month(.wide).year()) ?? month
                sections.append((month, title, [workout]))
            }
        }
        return sections
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let summary = try Importer(context: context).importData(Data(contentsOf: url))
            message = Message(
                title: "Import finished",
                text: """
                Workouts: \(summary.workoutsAdded) new, \(summary.workoutsReplaced) replaced.
                Exercises: \(summary.exercisesAdded) new, \(summary.exercisesUpdated) updated.
                """)
        } catch {
            message = Message(title: "Import failed", text: error.localizedDescription)
        }
    }

    private func export() {
        do {
            exportDocument = TransferDocument(data: try Exporter(context: context).exportData())
        } catch {
            message = Message(title: "Export failed", text: error.localizedDescription)
        }
    }
}

private struct Message: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.label ?? dateTitle)
                    .font(.headline)
                if workout.label != nil {
                    Text(dateTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(exerciseNames)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var dateTitle: String {
        Day.date(from: workout.day)?
            .formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            ?? workout.day
    }

    private var exerciseNames: String {
        workout.orderedEntries
            .map { $0.exercise?.name ?? $0.originalName ?? "?" }
            .joined(separator: " · ")
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
}
