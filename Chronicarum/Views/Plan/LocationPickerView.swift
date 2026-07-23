import SwiftUI
import MapKit

/// Search for somewhere to plan a trip around — so you can be in Brisbane and plan Adelaide.
///
/// Backed by `MKLocalSearchCompleter`, which is Apple Maps' own search-as-you-type. Picking
/// a result resolves it to a coordinate with a second `MKLocalSearch`, because the completer
/// hands back a label, not a place. All of it is on-device and needs no key.
struct LocationPickerView: View {
    /// Called with the chosen coordinate and a short name for it.
    let onPick: (CLLocationCoordinate2D, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = LocationSearch()

    var body: some View {
        NavigationStack {
            List(search.results, id: \.self) { completion in
                Button {
                    resolve(completion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(Color(hex: "#C9A84C"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                                .foregroundColor(.primary)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if search.query.isEmpty {
                    ContentUnavailableView("Plan somewhere else",
                                           systemImage: "map",
                                           description: Text("Search for a town, city or place "
                                               + "to build the trip around it instead of where "
                                               + "you are."))
                }
            }
            .searchable(text: $search.query, prompt: "Town, city or place")
            .navigationTitle("Where to?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else { return }
            onPick(item.placemark.coordinate, completion.title)
            dismiss()
        }
    }
}

/// Thin `ObservableObject` around `MKLocalSearchCompleter`, so SwiftUI can bind the query
/// and observe results.
final class LocationSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        // Places, not shops: a trip is planned around a town, not a particular café.
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
