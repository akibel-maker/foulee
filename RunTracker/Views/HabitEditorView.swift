import SwiftUI
import SwiftData

struct HabitEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allHabits: [Habit]

    let habit: Habit?

    @State private var name: String
    @State private var emoji: String
    @State private var color: HabitColor
    @State private var kind: HabitKind
    @State private var target: Double
    @State private var unit: String
    @State private var schedule: HabitSchedule
    @State private var weekdaysMask: Int
    @State private var timesPerWeek: Int
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var autoSource: HabitAutoSource
    @State private var isArchived: Bool
    @State private var confirmDelete = false

    private static let emojis = ["✅", "💧", "🧘", "📖", "🤸", "👟", "💪", "🥗", "🍎", "🚫", "🌙", "😴",
                                 "📵", "✍️", "🎸", "🧠", "🙏", "☀️", "🦷", "💊", "🧹", "💰", "🇬🇧", "❤️"]
    private static let dayLetters = ["L", "M", "M", "J", "V", "S", "D"]

    init(habit: Habit?) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _emoji = State(initialValue: habit?.emoji ?? "✅")
        _color = State(initialValue: habit?.habitColor ?? .orange)
        _kind = State(initialValue: habit?.kind ?? .check)
        _target = State(initialValue: habit?.target ?? 1)
        _unit = State(initialValue: habit?.unit ?? "")
        _schedule = State(initialValue: habit?.schedule ?? .daily)
        _weekdaysMask = State(initialValue: habit?.weekdaysMask ?? 0b111_1111)
        _timesPerWeek = State(initialValue: habit?.timesPerWeek ?? 3)
        _reminderEnabled = State(initialValue: habit?.reminderEnabled ?? false)
        let time = Calendar.current.date(from: DateComponents(hour: habit?.reminderHour ?? 9,
                                                              minute: habit?.reminderMinute ?? 0)) ?? .now
        _reminderTime = State(initialValue: time)
        _autoSource = State(initialValue: habit?.autoSource ?? .none)
        _isArchived = State(initialValue: habit?.isArchived ?? false)
    }

    private var isSteps: Bool { kind == .count && autoSource == .steps }

    var body: some View {
        NavigationStack {
            Form {
                if habit == nil { presetsSection }

                Section("Habitude") {
                    HStack(spacing: 12) {
                        Text(emoji)
                            .font(.title)
                            .frame(width: 50, height: 50)
                            .background(color.color.opacity(0.18), in: Circle())
                        TextField("Nom (ex. Méditer)", text: $name)
                            .font(.headline)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Self.emojis, id: \.self) { item in
                                Button { emoji = item } label: {
                                    Text(item)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(item == emoji ? color.color.opacity(0.25) : Color.clear, in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        ForEach(HabitColor.allCases) { item in
                            Button { color = item } label: {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if item == color {
                                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Objectif quotidien") {
                    Picker("Type", selection: $kind) {
                        ForEach(HabitKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        if newKind == .check { autoSource = .none }
                        else if target <= 1 { target = 5 }
                    }
                    if kind == .count {
                        Picker("Suivi", selection: $autoSource) {
                            ForEach(HabitAutoSource.allCases) { Text($0.label).tag($0) }
                        }
                        .onChange(of: autoSource) { _, source in
                            if source == .steps {
                                unit = "pas"
                                if target < 1000 { target = 10_000 }
                            } else if source == .stretching {
                                unit = "min"
                                if target > 120 || target < 1 { target = 5 }
                            }
                        }
                        Stepper(value: $target, in: isSteps ? 500...50_000 : 1...1000, step: isSteps ? 500 : 1) {
                            HStack {
                                Text("Cible")
                                Spacer()
                                Text(target.formatted(.number.precision(.fractionLength(0))))
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                        }
                        if autoSource == .none {
                            TextField("Unité (verres, min, pages…)", text: $unit)
                        }
                    }
                }

                Section("Fréquence") {
                    Picker("Fréquence", selection: $schedule) {
                        ForEach(HabitSchedule.allCases) { Text($0.label).tag($0) }
                    }
                    if schedule == .weekdays {
                        HStack {
                            ForEach(0..<7, id: \.self) { index in
                                let selected = weekdaysMask & (1 << index) != 0
                                Button {
                                    let toggled = weekdaysMask ^ (1 << index)
                                    if toggled != 0 { weekdaysMask = toggled }
                                } label: {
                                    Text(Self.dayLetters[index])
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 34, height: 34)
                                        .background(selected ? color.color : Color.secondary.opacity(0.15), in: Circle())
                                        .foregroundStyle(selected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    if schedule == .timesPerWeek {
                        Stepper("\(timesPerWeek) fois par semaine", value: $timesPerWeek, in: 1...7)
                    }
                }

                Section {
                    Toggle("Rappel", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Heure", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    if reminderEnabled {
                        Text("Une notification te sera envoyée les jours prévus.")
                    }
                }

                if habit != nil {
                    Section {
                        Toggle("Archiver (masquer sans perdre l'historique)", isOn: $isArchived)
                        Button("Supprimer l'habitude", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(habit == nil ? "Nouvelle habitude" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Supprimer cette habitude et tout son historique ?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { delete() }
            }
        }
    }

    private var presetsSection: some View {
        Section("Idées") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HabitPreset.all) { preset in
                        Button {
                            name = preset.name
                            emoji = preset.emoji
                            color = preset.color
                            kind = preset.kind
                            target = preset.target
                            unit = preset.unit
                            schedule = preset.schedule
                            timesPerWeek = preset.timesPerWeek
                            autoSource = preset.autoSource
                        } label: {
                            Text("\(preset.emoji) \(preset.name)")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(preset.color.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(preset.color.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func save() {
        let item = habit ?? Habit(name: "", emoji: "")
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.emoji = emoji
        item.habitColor = color
        item.kind = kind
        item.target = kind == .check ? 1 : max(target, 1)
        item.unit = kind == .check ? "" : unit.trimmingCharacters(in: .whitespaces)
        item.autoSource = kind == .check ? .none : autoSource
        item.schedule = schedule
        item.weekdaysMask = weekdaysMask
        item.timesPerWeek = timesPerWeek
        item.reminderEnabled = reminderEnabled
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        item.reminderHour = components.hour ?? 9
        item.reminderMinute = components.minute ?? 0
        item.isArchived = isArchived
        if habit == nil {
            item.sortOrder = (allHabits.map(\.sortOrder).max() ?? -1) + 1
            context.insert(item)
        }
        try? context.save()
        Task { await HabitReminders.update(for: item) }
        dismiss()
    }

    private func delete() {
        guard let habit else { return }
        let id = habit.id
        Task { await HabitReminders.remove(for: id) }
        context.delete(habit)
        try? context.save()
        dismiss()
    }
}
