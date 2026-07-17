import SwiftUI

struct MapFilterView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
                        mapVM.minimumTier = 1
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}
