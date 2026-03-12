import Foundation
import Testing
@testable import Portasaurus

struct PortainerEndpointDecodingTests {

    private func decode(_ json: String) throws -> PortainerEndpoint {
        try JSONDecoder().decode(PortainerEndpoint.self, from: Data(json.utf8))
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "Id": 3,
            "Name": "production",
            "Type": 1,
            "Status": 1,
            "URL": "tcp://localhost:2375",
            "PublicURL": "https://docker.example.com",
            "Snapshots": [
                {
                    "RunningContainerCount": 5,
                    "StoppedContainerCount": 2,
                    "HealthyContainerCount": 4,
                    "UnhealthyContainerCount": 1,
                    "DockerVersion": "24.0.7"
                }
            ]
        }
        """
        let ep = try decode(json)

        #expect(ep.id == 3)
        #expect(ep.name == "production")
        #expect(ep.type == .dockerStandalone)
        #expect(ep.status == .up)
        #expect(ep.url == "tcp://localhost:2375")
        #expect(ep.publicURL == "https://docker.example.com")
        #expect(ep.snapshots.count == 1)

        let snap = try #require(ep.snapshot)
        #expect(snap.runningContainerCount == 5)
        #expect(snap.stoppedContainerCount == 2)
        #expect(snap.healthyContainerCount == 4)
        #expect(snap.unhealthyContainerCount == 1)
        #expect(snap.dockerVersion == "24.0.7")
        #expect(snap.totalContainerCount == 7)
    }

    @Test func missingPublicURLDefaultsToEmpty() throws {
        let json = """
        {
            "Id": 1,
            "Name": "local",
            "Type": 1,
            "Status": 1,
            "URL": "tcp://localhost:2375"
        }
        """
        let ep = try decode(json)
        #expect(ep.publicURL == "")
    }

    @Test func missingSnapshotsDefaultsToEmptyArray() throws {
        let json = """
        {
            "Id": 1,
            "Name": "local",
            "Type": 1,
            "Status": 1,
            "URL": "tcp://localhost:2375"
        }
        """
        let ep = try decode(json)
        #expect(ep.snapshots.isEmpty)
        #expect(ep.snapshot == nil)
    }

    @Test func snapshotNilDockerVersion() throws {
        let json = """
        {
            "Id": 1,
            "Name": "local",
            "Type": 1,
            "Status": 1,
            "URL": "tcp://localhost:2375",
            "Snapshots": [
                {
                    "RunningContainerCount": 0,
                    "StoppedContainerCount": 0,
                    "HealthyContainerCount": 0,
                    "UnhealthyContainerCount": 0
                }
            ]
        }
        """
        let ep = try decode(json)
        #expect(ep.snapshot?.dockerVersion == nil)
    }

    @Test func unknownEndpointTypeFallsBackToDockerStandalone() throws {
        let json = """
        {
            "Id": 1,
            "Name": "mystery",
            "Type": 99,
            "Status": 1,
            "URL": "tcp://localhost:2375"
        }
        """
        let ep = try decode(json)
        #expect(ep.type == .dockerStandalone)
    }

    @Test func unknownStatusFallsBackToDown() throws {
        let json = """
        {
            "Id": 1,
            "Name": "mystery",
            "Type": 1,
            "Status": 99,
            "URL": "tcp://localhost:2375"
        }
        """
        let ep = try decode(json)
        #expect(ep.status == .down)
    }

    @Test func allEndpointTypesDecodeCorrectly() throws {
        let cases: [(Int, PortainerEndpoint.EndpointType)] = [
            (1, .dockerStandalone),
            (2, .dockerAgent),
            (3, .azure),
            (4, .edgeAgent),
            (5, .kubernetes),
            (6, .kubeConfig),
        ]
        for (raw, expected) in cases {
            let json = """
            {"Id":1,"Name":"x","Type":\(raw),"Status":1,"URL":"tcp://localhost:2375"}
            """
            let ep = try decode(json)
            #expect(ep.type == expected)
        }
    }
}
