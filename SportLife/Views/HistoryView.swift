import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: [SortDescriptor(\Workout.day, order: .reverse),
                SortDescriptor(\Workout.externalID, order: .reverse)])
  private var workouts: [Workout]

  @State private var path: [Route] = []
  @State private var isImporting = false
  @State private var exportDocument: TransferDocument?
  @State private var message: Message?

  var body: some View {
    NavigationStack(path: $path) {
      Group {
        if workouts.isEmpty {
          ContentUnavailableView {
            Label("No workouts yet", systemImage: "dumbbell")
          } description: {
            Text("Start a workout, or import a Sport Life JSON file to bring in your history.")
          } actions: {
            Button("Start workout") { start(repeating: nil) }
              .buttonStyle(.borderedProminent)
            Button("Import…") { isImporting = true }
          }
        } else {
          list
        }
      }
      .navigationTitle("History")
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .detail(let workout):
          WorkoutDetailView(workout: workout) { start(repeating: workout) }
        case .editor(let workout):
          WorkoutEditorView(workout: workout)
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(liveWorkout == nil ? "Start workout" : "Continue workout",
                 systemImage: liveWorkout == nil ? "plus" : "figure.strengthtraining.traditional") {
            start(repeating: nil)
          }
        }
        ToolbarItem(placement: .secondaryAction) {
          Button("Import…", systemImage: "square.and.arrow.down") { isImporting = true }
        }
        ToolbarItem(placement: .secondaryAction) {
          Button("Export…", systemImage: "square.and.arrow.up", action: export)
            .disabled(workouts.isEmpty)
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
      if let liveWorkout {
        Section("In progress") {
          NavigationLink(value: Route.editor(liveWorkout)) {
            WorkoutRow(workout: liveWorkout)
          }
        }
      }
      ForEach(monthSections, id: \.month) { section in
        Section(section.title) {
          ForEach(section.workouts) { workout in
            NavigationLink(value: Route.detail(workout)) {
              WorkoutRow(workout: workout)
            }
          }
        }
      }
    }
  }

  private var monthSections: [(month: String, title: String, workouts: [Workout])] {
    Dictionary(grouping: workouts.filter { !$0.isLive }) { Day.monthKey($0.day) }
      .sorted { $0.key > $1.key }
      .map { month, workouts in
        let title = Day.date(from: workouts[0].day)?
          .formatted(.dateTime.month(.wide).year()) ?? month
        return (month, title, workouts)
      }
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

  private var liveWorkout: Workout? {
    workouts.first(where: \.isLive)
  }

  /// Opens the live workout, or starts a new one (repeating `template` if given).
  /// Only one workout is live at a time.
  private func start(repeating template: Workout?) {
    if let liveWorkout {
      if template != nil {
        message = Message(title: String(localized: "A workout is in progress"),
                          text: String(localized: "Finish or discard it before starting another one."))
      }
      path = [.editor(liveWorkout)]
      return
    }
    let workout = WorkoutPlanner(context: context).startWorkout(repeating: template)
    path = [.editor(workout)]
  }

  private func export() {
    do {
      exportDocument = TransferDocument(data: try Exporter(context: context).exportData())
    } catch {
      message = Message(title: "Export failed", text: error.localizedDescription)
    }
  }
}

enum Route: Hashable {
  case detail(Workout)
  case editor(Workout)
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
