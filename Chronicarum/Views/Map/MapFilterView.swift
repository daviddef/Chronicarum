import SwiftUI

struct MapFilterView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // First, and phrased as an interest rather than a filter: this is the one
                // control that answers "I like castles and Roman history", and it reads
                // as a preference the user expresses rather than a category they narrow.
                Section {
                    ThemePickerView(selection: $mapVM.activeThemes)
                } header: {
                    Text("What are you interested in?")
                } footer: {
                    Text(mapVM.activeThemes.isEmpty
                         ? "Nothing selected — showing everything."
                         : mapVM.activeThemes.components.map(\.label)
                             .formatted(.list(type: .and)))
                }

                Section("Era") {
                    ForEach(Era.allCases, id: \.self) { era in
                        Toggle(era.displayName, isOn: Binding(
                            get: { mapVM.activeEras.contains(era) },
                            set: { on in
                                if on { mapVM.activeEras.insert(era) }
                                else  { mapVM.activeEras.remove(era) }
                            }
                        ))
                    }
                }

                Section("Type") {
                    ForEach(SiteType.allCases, id: \.self) { type in
                        Toggle(type.displayName, isOn: Binding(
                            get: { mapVM.activeTypes.contains(type) },
                            set: { on in
                                if on { mapVM.activeTypes.insert(type) }
                                else  { mapVM.activeTypes.remove(type) }
                            }
                        ))
                    }
                }

                Section("Minimum Significance Tier") {
                    Picker("Tier \(mapVM.minimumTier)+", selection: $mapVM.minimumTier) {
                        ForEach(1...5, id: \.self) { tier in
                            Text("Tier \(tier)+").tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        mapVM.activeEras = Set(Era.allCases)
                        mapVM.activeTypes = Set(SiteType.allCases)
                        mapVM.activeThemes = []
                        mapVM.minimumTier = 1
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}


/// Themes as a wrapping grid of toggle chips.
///
/// Deliberately not a list of switches like Era and Type above: those are 7 and 12
/// exhaustive categories where a user *removes* what they don't want, and they default to
/// all-on. Themes are the opposite — 16 interests where a user *adds* the two or three
/// they came for, defaulting to none selected. Same data shape, opposite gesture, so the
/// control should look different.
struct ThemePickerView: View {
    @Binding var selection: Theme

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Theme.all, id: \.rawValue) { theme in
                let isOn = selection.contains(theme)
                Button {
                    if isOn { selection.remove(theme) } else { selection.insert(theme) }
                } label: {
                    HStack(spacing: 5) {
                        Text(theme.glyph).font(.system(size: 12))
                        Text(theme.label)
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isOn ? Color.accentColor.opacity(0.18)
                                     : Color.secondary.opacity(0.10),
                                in: Capsule())
                    .overlay(
                        Capsule().stroke(isOn ? Color.accentColor : .clear, lineWidth: 1)
                    )
                    .foregroundColor(isOn ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }
}
