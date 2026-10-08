import SwiftUI

struct UndoToast: Identifiable {
  let id = UUID()
  let message: String
  let undo: () -> Void
}

/// Bottom toast with an Undo button; disappears after a few seconds.
struct UndoToastView: View {
  let toast: UndoToast
  let onDismiss: () -> Void

  var body: some View {
    HStack {
      Text(toast.message)
        .lineLimit(1)
      Spacer()
      Button("Undo") {
        toast.undo()
        onDismiss()
      }
      .fontWeight(.semibold)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(.regularMaterial, in: .capsule)
    .shadow(radius: 8, y: 2)
    .task(id: toast.id) {
      try? await Task.sleep(for: .seconds(6))
      if !Task.isCancelled { onDismiss() }
    }
  }
}
