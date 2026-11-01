import SwiftUI
import SwiftData

struct CustomRoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let routine: CustomStretchRoutine?
    @State private var name: String
    @State private var tint: HabitColor
    @State private var steps: [StretchStep]
    @State private var showPicker = false
    @State private var confirmDelete = false

    init(routine: CustomStretchRoutine?, initialName: String = "", initialSteps: [StretchStep] = []) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? initialName)
        _tint = State(initialValue: routine?.tint ?? .orange)
        _steps = State(initialValue: routine?.steps ?? initialSteps)
    }

    private var totalSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Nom (ex. Après le footing)", text: $name)
                    HStack(spacing: 10) {
                        ForEach(HabitColor.allCases) { item in
                            Button { tint = item } label: {
                                Circle().fill(item.color).frame(width: 26, height: 26)
                                    .overlay {
                                        if item == tint {
                                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    ForEach($steps) { $step in
                        if let move = StretchLibrary.move(step.moveID) {
                            Stepper(value: $step.seconds, in: 10...180, step: 5) {
                                HStack(spacing: 10) {
                                    StretchArtwork(symbol: move.symbol, tint: move.zones.first?.tint ?? tint, size: 32)
                                    VStack(alignment: .leading) {
                                        Text(move.name).font(.subheadline.weight(.semibold))
                                        Text("\(step.seconds) s\(move.bilateral ? " · 2 côtés" : "")")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { steps.remove(atOffsets: $0) }
                    Button("Ajouter des mouvements", systemImage: "plus.circle.fill") { showPicker = true }
                } header: {
                    HStack {
                        Text("Mouvements · \(Fmt.duration(TimeInterval(totalSeconds)))")
                        Spacer()
                        if steps.count > 1 { EditButton().font(.caption) }
                    }
                } footer: {
                    Text("Glisse pour supprimer, « Modifier » pour réordonner.")
                }

                if routine != nil {
                    Section {
                        Button("Supprimer la routine", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(routine == nil ? "Nouvelle routine" : "Modifier la routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || steps.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                MovePickerView { ids in
                    steps.append(contentsOf: ids.map { StretchStep(moveID: $0, seconds: 30) })
                }
            }
            .confirmationDialog("Supprimer cette routine ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let routine { context.delete(routine) }
                    try? context.save()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let routine {
            routine.name = trimmed
            routine.tint = tint
            routine.steps = steps
        } else {
            context.insert(CustomStretchRoutine(name: trimmed, tint: tint, steps: steps))
        }
        try? context.save()
        dismiss()
    }
}

/// Sélection de mouvements dans la bibliothèque.
struct MovePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: ([String]) -> Void
    @State private var selection: [String] = []
    @State private var zone: StretchZone?
    @State private var search = ""

    private var moves: [StretchMove] {
        StretchLibrary.moves.filter { move in
            (zone == nil || move.zones.contains(zone!))
                && (search.isEmpty || move.name.localizedCaseInsensitiveContains(search)
                    || move.englishName.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("Tout", selected: zone == nil) { zone = nil }
                            ForEach(StretchZone.allCases) { item in
                                chip(item.label, selected: zone == item) { zone = item }
                            }
                        }
                    }
                }
                ForEach(moves) { move in
                    Button {
                        if let index = selection.firstIndex(of: move.id) { selection.remove(at: index) }
                        else { selection.append(move.id) }
                    } label: {
                        HStack(spacing: 12) {
                            StretchArtwork(symbol: move.symbol, tint: move.zones.first?.tint ?? .orange, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(move.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(move.instruction).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: selection.contains(move.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection.contains(move.id) ? .orange : .secondary)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Rechercher un mouvement")
            .navigationTitle("Mouvements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter (\(selection.count))") {
                        onAdd(selection)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.orange : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
