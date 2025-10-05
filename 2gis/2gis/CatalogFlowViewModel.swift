import Foundation
import Observation

@MainActor
@Observable
class CatalogFlowViewModel {
    struct FlowResult: Sendable {
        var building: BuildingDetails?
        var organizations: [PlaceItem]
        var diagnostics: [String]
    }

    private let client: CatalogAPIClient

    var isRunning: Bool = false
    var lastResult: FlowResult?
    var lastError: String?

    init(apiKey: String = "6fe4cc7a-89b8-4aec-a5c3-ac94224044fe") {
        self.client = CatalogAPIClient(apiKey: apiKey)
    }

    func run(lon: Double, lat: Double) async {
        guard !isRunning else { return }
        isRunning = true
        lastError = nil
        var diagnostics: [String] = []

        var buildingId: String?
        var buildingDetails: BuildingDetails?
        var organizations: [PlaceItem] = []

        // 1) Nearest building via geocoder with increasing radius
        do {
            let radii = [10, 50, 150, 300]
            var found: GeocodeItem?
            for r in radii {
                let geo = try await client.geocodeBuilding(lon: lon, lat: lat, radius: r)
                if let item = geo.result?.items?.first {
                    found = item
                    diagnostics.append("geocode: hit radius=\(r)")
                    break
                } else {
                    diagnostics.append("geocode: empty radius=\(r)")
                }
            }
            buildingId = found?.id
        } catch {
            diagnostics.append("geocode error: \(error.localizedDescription)")
        }

        // 2) Building details by id (best-effort)
        if let id = buildingId {
            let fields = "items.address,items.floors,items.structure_info.material,items.structure_info.apartments_count,items.structure_info.porch_count,items.structure_info.floor_type,items.structure_info.year_of_construction,items.structure_info.elevators_count,items.structure_info.gas_type,items.structure_info.project_type,items.structure_info.chs_name,items.structure_info.chs_category"
            do {
                let resp = try await client.buildingDetails(id: id, fields: fields)
                buildingDetails = resp.result?.items?.first
                if buildingDetails == nil { diagnostics.append("details: no items") }
            } catch {
                diagnostics.append("details error: \(error.localizedDescription)")
            }
        } else {
            diagnostics.append("no building id — skipping details & orgs")
        }

        // 3) Organizations inside building (fallback to servicing)
        if let id = buildingId {
            do {
                let resp = try await client.listIndoorOrganizations(buildingId: id, page: 1, pageSize: 12)
                organizations = resp.result?.items ?? []
                if organizations.isEmpty {
                    diagnostics.append("indoor: empty; try byservicing")
                    do {
                        let svc = try await client.listServicing(buildingId: id, group: "default", fields: "items.contact_groups,items.working_hours,items.links")
                        organizations = svc.result?.items ?? []
                    } catch {
                        diagnostics.append("byservicing error: \(error.localizedDescription)")
                    }
                }
            } catch {
                diagnostics.append("indoor error: \(error.localizedDescription)")
                // Try servicing even if indoor failed
                do {
                    let svc = try await client.listServicing(buildingId: id, group: "default", fields: "items.contact_groups,items.working_hours,items.links")
                    organizations = svc.result?.items ?? []
                } catch {
                    diagnostics.append("byservicing error: \(error.localizedDescription)")
                }
            }
        }

        self.lastResult = FlowResult(building: buildingDetails, organizations: organizations, diagnostics: diagnostics)
        isRunning = false
    }
}

