import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.sortOrder) private var allHabits: [Habit]
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var steps = StepsStore()
    @State private var showEditor = false
    @State private var showArchived = false

    private var habits: [Habit] { allHabits.filter { !$0.isArchived } }
    private var archived: [Habit] { allHabits.filter(\.isArchived) }
    private var usesSteps: Bool { habits.contains { $0.autoSource == .steps } }

    private func valueProvider(for habit: Habit) -> HabitLogic.ValueProvider {
        if habit.autoSource == .steps {
            let store = steps
            return { store.steps(on: $0) }
        }
        return { habit.loggedValue(on: $0) }
    }

    private var scheduledToday: [Habit] { habits.filter { HabitLogic.isScheduled($0, on: selectedDay) } }
    private var otherHabits: [Habit] { habits.filter { !HabitLogic.isScheduled($0, on: selectedDay) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                weekStrip
                if habits.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    VStack(spacing: 10) {
                        ForEach(scheduledToday) { habit in row(habit) }
                    }
                    if !otherHabits.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pas prévu ce jour").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(otherHabits) { habit in row(habit).opacity(0.55) }
                        }
                    }
                }
                if !archived.isEmpty {
                    DisclosureGroup("Archivées (\(archived.count))", isExpanded: $showArchived) {
                        ForEach(archived) { habit in
                            NavigationLink(value: habit) {
                                HStack {
                                    Text(habit.emoji)
                                    Text(habit.name)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.subheadline)
                    .card()
                }
            }
            .padding()
        }
        .navigationTitle("Habitudes")
        .navigationDestination(for: Habit.self) { habit in
            HabitDetailView(habit: habit, value: valueProvider(for: habit))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nouvelle habitude", systemImage: "plus") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) { HabitEditorView(habit: nil) }
        .task(id: usesSteps) { if usesSteps { await steps.load() } }
        .refreshable { if usesSteps { await steps.load() } }
    }

    // MARK: - Semaine

    private var weekStrip: some View {
        let cal = HabitDay.calendar
        let today = cal.startOfDay(for: .now)
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let fraction = completion(on: day)
                let isSelected = day == selectedDay
                Button {
                    withAnimation(.snappy) { selectedDay = day }
                } label: {
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "fr_FR"))))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : .secondary)
                        ZStack {
                            Circle().stroke((isSelected ? Color.white : Color.orange).opacity(0.25), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: fraction)
                                .stroke(isSelected ? Color.white : Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(cal.component(.day, from: day))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .frame(width: 30, height: 30)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.orange : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }

    private func completion(on day: Date) -> Double {
        let scheduled = habits.filter { HabitLogic.isScheduled($0, on: day) && $0.createdAt <= endOfDay(day) }
        guard !scheduled.isEmpty else { return 0 }
        let done = scheduled.filter { HabitLogic.isSatisfied($0, on: day, value: valueProvider(for: $0)) }.count
        return Double(done) / Double(scheduled.count)
    }

    private func endOfDay(_ day: Date) -> Date {
        HabitDay.calendar.date(byAdding: .day, value: 1, to: day) ?? day
    }

    // MARK: - Résumé

    private var summaryCard: some View {
        let scheduled = scheduledToday
        let done = scheduled.filter { HabitLogic.isSatisfied($0, on: selectedDay, value: valueProvider(for: $0)) }.count
        let fraction = scheduled.isEmpty ? 0 : Double(done) / Double(scheduled.count)
        let isToday = selectedDay == HabitDay.calendar.startOfDay(for: .now)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.orange.opacity(0.18), lineWidth: 10)
                Circle().trim(from: 0, to: fraction)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(fraction * 100)) %").font(.subheadline.weight(.bold).monospacedDigit())
            }
            .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text(isToday ? "Aujourd'hui" : Fmt.dayShort(selectedDay).capitalized)
                    .font(.headline)
                Text("\(done) sur \(scheduled.count) habitude\(scheduled.count > 1 ? "s" : "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !scheduled.isEmpty && done == scheduled.count {
                    Text("Journée parfaite 🎉").font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    // MARK: - Ligne

    private func row(_ habit: Habit) -> some View {
        let value = valueProvider(for: habit)
        return HabitRow(habit: habit,
                        day: selectedDay,
                        currentValue: value(selectedDay),
                        satisfied: HabitLogic.isSatisfied(habit, on: selectedDay, value: value),
                        stats: HabitLogic.stats(for: habit, value: value),
                        weekDone: HabitLogic.doneCount(habit, inWeekOf: selectedDay, value: value)) { newValue in
            habit.setLoggedValue(newValue, on: selectedDay)
            try? context.save()
        }
    }

    // MARK: - État vide

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suis tes habitudes au quotidien")
                .font(.headline)
            Text("Eau, méditation, lecture, étirements, sommeil… Coche chaque jour ce que tu as fait et construis des séries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Créer ma première habitude") { showEditor = true }
                .buttonStyle(.borderedProminent)
        }
        .card()
    }
}

struct HabitRow: View {
    let habit: Habit
    let day: Date
    let currentValue: Double
    let satisfied: Bool
    let stats: HabitStats
    let weekDone: Int
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: habit) {
                HStack(spacing: 12) {
                    Text(habit.emoji)
                        .font(.title2)
                        .frame(width: 46, height: 46)
                        .background(habit.color.opacity(0.18), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.name).font(.headline).lineLimit(1)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if stats.currentStreak > 1 {
                        Label("\(stats.currentStreak)", systemImage: "flame.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            control
        }
        .card()
    }

    private var subtitle: String {
        var parts: [String] = []
        if habit.kind == .count {
            parts.append("\(habit.formatValue(currentValue)) / \(habit.formatValue(habit.effectiveTarget)) \(habit.unit)")
        }
        if habit.schedule == .timesPerWeek {
            parts.append("\(weekDone)/\(habit.timesPerWeek) cette semaine")
        } else if habit.kind == .check {
            parts.append(habit.scheduleDescription)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var control: some View {
        if habit.autoSource == .steps {
            progressRing
        } else if habit.kind == .check {
            Button {
                onChange(currentValue >= 1 ? 0 : 1)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: currentValue >= 1 ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34))
                    .foregroundStyle(currentValue >= 1 ? habit.color : Color.secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(currentValue >= 1 ? "Fait" : "À faire")
        } else {
            HStack(spacing: 8) {
                Button {
                    onChange(max(0, currentValue - step))
                } label: {
                    Image(systemName: "minus").frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(currentValue <= 0)
                ZStack {
                    progressRing
                }
                Button {
                    onChange(currentValue + step)
                    if currentValue + step >= habit.effectiveTarget, currentValue < habit.effectiveTarget {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } label: {
                    Image(systemName: "plus").frame(width: 30, height: 30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(habit.color)
            }
        }
    }

    /// Pas de saisie : 1 unité, ou 5 pour les cibles en minutes élevées.
    private var step: Double {
        habit.effectiveTarget >= 60 ? 5 : 1
    }

    private var progressRing: some View {
        let fraction = min(currentValue / habit.effectiveTarget, 1)
        return ZStack {
            Circle().stroke(habit.color.opacity(0.2), lineWidth: 4)
            Circle().trim(from: 0, to: fraction)
                .stroke(habit.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if satisfied {
                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(habit.color)
            } else {
                Text("\(Int(fraction * 100))").font(.system(size: 10, weight: .bold)).monospacedDigit()
            }
        }
        .frame(width: 34, height: 34)
    }
}
