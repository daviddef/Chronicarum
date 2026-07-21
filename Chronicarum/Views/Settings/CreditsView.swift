import SwiftUI

/// Where the catalogue came from, and what each source is owed.
///
/// Most of this app's data is CC0 or public domain and owes nothing — but not all of it,
/// and the obligations are real rather than decorative. Site-level credits already appear
/// on the sites they belong to (`DataSource`) and on each photo. This screen covers the
/// sources that shaped the catalogue as a whole and therefore have nowhere else to appear:
/// notably Historic England, whose scheduled-monument boundaries establish which sites sit
/// inside which, under a licence that requires the credit even though only the derived
/// relations ship.
struct CreditsView: View {

    private struct Source: Identifiable {
        let name: String
        let what: String
        let licence: String
        let url: String
        var id: String { name }
    }

    private let sources: [Source] = [
        .init(name: "Wikidata",
              what: "The bulk of the catalogue — names, coordinates, heritage designations, "
                  + "and the part-of relations between sites.",
              licence: "CC0 1.0 — public domain",
              url: "https://www.wikidata.org"),
        .init(name: "Wikimedia Commons",
              what: "Site photographs. Each photo carries its own author and licence on the "
                  + "image itself.",
              licence: "Various — shown per photo",
              url: "https://commons.wikimedia.org"),
        .init(name: "Historic England",
              what: "Scheduled monument boundaries, used to work out which sites stand "
                  + "inside a monument's grounds. The boundaries themselves are not "
                  + "included in the app.",
              licence: "Open Government Licence v3.0. Contains Historic England data "
                  + "© Historic England. Contains Ordnance Survey data © Crown copyright "
                  + "and database right.",
              url: "https://historicengland.org.uk/listing/the-list/data-downloads/"),
        .init(name: "Base Mérimée",
              what: "French monuments historiques, including the register's own "
                  + "descriptions in French.",
              licence: "Licence Ouverte 2.0 — Ministère de la Culture",
              url: "https://data.culture.gouv.fr"),
        .init(name: "National Register of Historic Places",
              what: "United States listings.",
              licence: "Public domain — National Park Service",
              url: "https://www.nps.gov/subjects/nationalregister/index.htm"),
        .init(name: "South Australian Heritage Places",
              what: "The South Australian state register.",
              licence: "CC BY 3.0 AU — Government of South Australia",
              url: "https://data.sa.gov.au/data/dataset/sa-heritage-places"),
        .init(name: "Wikipedia",
              what: "Summaries shown on some sites, fetched as you read them rather than "
                  + "bundled, exactly as the official Wikipedia app does.",
              licence: "CC BY-SA 4.0",
              url: "https://www.wikipedia.org"),
    ]

    var body: some View {
        List {
            Section {
                Text("Chronicarum is built almost entirely on open government heritage "
                     + "registers and on Wikidata. Where a source asks to be credited, it "
                     + "is credited here and on the sites it contributed.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            ForEach(sources) { source in
                Section {
                    Text(source.what)
                        .font(.footnote)
                    Text(source.licence)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let url = URL(string: source.url) {
                        Link("Source", destination: url)
                            .font(.caption)
                    }
                } header: {
                    Text(source.name)
                }
            }

            Section {
                Text("Opening hours are not recorded by any heritage register, so the app "
                     + "never claims to know them. Travel times between stops are measured "
                     + "with Apple Maps where a route exists.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("What the app doesn't know")
            }
        }
        .navigationTitle("Sources & licences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { CreditsView() }
}
