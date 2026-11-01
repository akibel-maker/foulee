import SwiftUI

/// Pastille colorée avec pictogramme (à la place d'une illustration).
struct StretchArtwork: View {
    let symbol: String
    let tint: HabitColor
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [tint.color.opacity(0.95), tint.color.opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
    }
}

/// Grande carte de routine (suggestions, carrousels).
struct RoutineCard: View {
    let routine: StretchRoutine
    var width: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: -10) {
                StretchArtwork(symbol: routine.symbol, tint: routine.tint, size: 58)
                ForEach(Array(Set(routine.moves.map(\.symbol))).sorted().prefix(3), id: \.self) { symbol in
                    StretchArtwork(symbol: symbol, tint: routine.tint, size: 34)
                        .opacity(0.85)
                        .overlay(Circle().stroke(Color(.secondarySystemBackground), lineWidth: 3))
                }
            }
            Spacer(minLength: 0)
            Text("\(routine.minutes) MIN · \(routine.steps.count) MOUVEMENTS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(routine.name)
                .font(.title3.weight(.bold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(routine.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(width: width, height: 210, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Ligne compacte de routine (listes).
struct RoutineRow: View {
    let routine: StretchRoutine

    var body: some View {
        HStack(spacing: 14) {
            StretchArtwork(symbol: routine.symbol, tint: routine.tint, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name).font(.headline).foregroundStyle(.primary)
                Text("\(routine.minutes) min · \(routine.summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Favoris enregistrés sous forme de liste d'identifiants.
enum StretchFavorites {
    static func ids(_ raw: String) -> [String] { raw.split(separator: ",").map(String.init) }

    static func toggled(_ id: String, in raw: String) -> String {
        var list = ids(raw)
        if let index = list.firstIndex(of: id) { list.remove(at: index) } else { list.append(id) }
        return list.joined(separator: ",")
    }
}
