import XCTest
@testable import LightstreamerClient

final class ClientTests: BaseTestCase, ClientDelegate {
    
    var actualClient: LightstreamerClient?
    var actualEvents = ""

    func testAddDelegate() {
        let client = LightstreamerClient(serverAddress: "http://host")
        client.addDelegate(self)
        
        wait(for: [expectation], timeout: 1)
        
        XCTAssert(client === actualClient)
        XCTAssertEqual("clientDidAddDelegate", actualEvents)
        XCTAssertEqual(1, client.delegates.count)
        XCTAssert(self === client.delegates[0])
    }
    
    func testRemoveDelegate() {
        expectation.expectedFulfillmentCount = 2
        
        let client = LightstreamerClient(serverAddress: "http://host")
        client.addDelegate(self)
        client.removeDelegate(self)
        
        wait(for: [expectation], timeout: 1)
        
        XCTAssert(client === actualClient)
        XCTAssertEqual("clientDidAddDelegate clientDidRemoveDelegate", actualEvents)
        XCTAssertEqual(0, client.delegates.count)
    }
    
    func testPropertyChange1() {
        expectation.expectedFulfillmentCount = 9
        
        let client = LightstreamerClient(serverAddress: "http://host")
        client.addDelegate(self)
        client.connectionDetails.serverAddress = "http://server"
        client.connectionDetails.adapterSet = "adapter"
        client.connectionDetails.user = "user"
        client.connectionDetails.setPassword("pwd")
        client.connectionDetails.setSessionId("sid")
        client.connectionDetails.setServerInstanceAddress("inst")
        client.connectionDetails.setServerSocketName("sock")
        client.connectionDetails.setClientIp("ip")
        
        wait(for: [expectation], timeout: 1)
        
        XCTAssertEqual(
            "clientDidAddDelegate " +
            "didChangeProperty(serverAddress) " +
            "didChangeProperty(adapterSet) " +
            "didChangeProperty(user) " +
            "didChangeProperty(password) " +
            "didChangeProperty(sessionId) " +
            "didChangeProperty(serverInstanceAddress) " +
            "didChangeProperty(serverSocketName) " +
            "didChangeProperty(clientIp)", actualEvents)
        XCTAssertEqual("http://server", client.connectionDetails.serverAddress)
        XCTAssertEqual("adapter", client.connectionDetails.adapterSet)
        XCTAssertEqual("user", client.connectionDetails.user)
        XCTAssertEqual("sid", client.connectionDetails.sessionId)
        XCTAssertEqual("inst", client.connectionDetails.serverInstanceAddress)
        XCTAssertEqual("sock", client.connectionDetails.serverSocketName)
        XCTAssertEqual("ip", client.connectionDetails.clientIp)
    }

    func testPropertyChange2() {
        expectation.expectedFulfillmentCount = 18
        
        let client = LightstreamerClient(serverAddress: "http://host")
        client.addDelegate(self)
        client.connectionOptions.contentLength = 10
        client.connectionOptions.firstRetryMaxDelay = 20
        client.connectionOptions.forcedTransport = .WS_STREAMING
        client.connectionOptions.HTTPExtraHeaders = ["h":"v"]
        client.connectionOptions.idleTimeout = 30
        client.connectionOptions.keepaliveInterval = 40
        client.connectionOptions.requestedMaxBandwidth = .limited(50)
        client.connectionOptions.setRealMaxBandwidth(.unlimited)
        client.connectionOptions.pollingInterval = 60
        client.connectionOptions.reconnectTimeout = 70
        client.connectionOptions.retryDelay = 80
        client.connectionOptions.reverseHeartbeatInterval = 90
        client.connectionOptions.sessionRecoveryTimeout = 100
        client.connectionOptions.stalledTimeout = 110
        client.connectionOptions.HTTPExtraHeadersOnSessionCreationOnly = true
        client.connectionOptions.serverInstanceAddressIgnored = true
        client.connectionOptions.slowingEnabled = true
        
        wait(for: [expectation], timeout: 1)
        
        XCTAssertEqual(
            "clientDidAddDelegate " +
            "didChangeProperty(contentLength) " +
            "didChangeProperty(firstRetryMaxDelay) " +
            "didChangeProperty(forcedTransport) " +
            "didChangeProperty(httpExtraHeaders) " +
            "didChangeProperty(idleTimeout) " +
            "didChangeProperty(keepaliveInterval) " +
            "didChangeProperty(requestedMaxBandwidth) " +
            "didChangeProperty(realMaxBandwidth) " +
            "didChangeProperty(pollingInterval) " +
            "didChangeProperty(reconnectTimeout) " +
            "didChangeProperty(retryDelay) " +
            "didChangeProperty(reverseHeartbeatInterval) " +
            "didChangeProperty(sessionRecoveryTimeout) " +
            "didChangeProperty(stalledTimeout) " +
            "didChangeProperty(httpExtraHeadersOnSessionCreationOnly) " +
            "didChangeProperty(serverInstanceAddressIgnored) " +
            "didChangeProperty(slowingEnabled)", actualEvents)
        XCTAssertEqual(10, client.connectionOptions.contentLength)
        XCTAssertEqual(20, client.connectionOptions.firstRetryMaxDelay)
        XCTAssertEqual(.WS_STREAMING, client.connectionOptions.forcedTransport!)
        XCTAssertEqual(["h":"v"], client.connectionOptions.HTTPExtraHeaders)
        XCTAssertEqual(30, client.connectionOptions.idleTimeout)
        XCTAssertEqual(40, client.connectionOptions.keepaliveInterval)
        XCTAssertEqual(.limited(50), client.connectionOptions.requestedMaxBandwidth)
        XCTAssertEqual(.unlimited, client.connectionOptions.realMaxBandwidth)
        XCTAssertEqual(60, client.connectionOptions.pollingInterval)
        XCTAssertEqual(70, client.connectionOptions.reconnectTimeout)
        XCTAssertEqual(80, client.connectionOptions.retryDelay)
        XCTAssertEqual(90, client.connectionOptions.reverseHeartbeatInterval)
        XCTAssertEqual(100, client.connectionOptions.sessionRecoveryTimeout)
        XCTAssertEqual(110, client.connectionOptions.stalledTimeout)
        XCTAssertEqual(true, client.connectionOptions.HTTPExtraHeadersOnSessionCreationOnly)
        XCTAssertEqual(true, client.connectionOptions.serverInstanceAddressIgnored)
        XCTAssertEqual(true, client.connectionOptions.slowingEnabled)
    }
    
    func testServerAddress() {
        XCTAssertEqual(.failure(.malformed), parseServerAddress(""))
        XCTAssertEqual(.failure(.malformed), parseServerAddress("%&/"))
        XCTAssertEqual(.failure(.wrongScheme), parseServerAddress("host"))
        XCTAssertEqual(.failure(.wrongScheme), parseServerAddress("ws://host"))
        XCTAssertEqual(.failure(.wrongQuery), parseServerAddress("http://host/?q"))
        XCTAssertEqual(.success("http://host"), parseServerAddress("http://host"))
        XCTAssertEqual(.success("http://host/"), parseServerAddress("http://host/"))
        XCTAssertEqual(.success("http://host.com/foo/bar"), parseServerAddress("http://host.com/foo/bar"))
        XCTAssertEqual(.success("https://host.com/foo/bar"), parseServerAddress("https://host.com/foo/bar"))
    }
    
    func addEvent(_ e: String) {
        actualEvents += actualEvents.isEmpty ? e : " \(e)"
    }

    func clientDidRemoveDelegate(_ client: LightstreamerClient) {
        actualClient = client
        addEvent("clientDidRemoveDelegate")
        expectation.fulfill()
    }
    
    func clientDidAddDelegate(_ client: LightstreamerClient) {
        actualClient = client
        addEvent("clientDidAddDelegate")
        expectation.fulfill()
    }
    
    func client(_ client: LightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String) {
        actualClient = client
        addEvent("didReceiveServerError")
        expectation.fulfill()
    }
    
    func client(_ client: LightstreamerClient, didChangeStatus status: LightstreamerClient.Status) {
        actualClient = client
        addEvent("didChangeStatus")
        expectation.fulfill()
    }
    
    func client(_ client: LightstreamerClient, didChangeProperty property: String) {
        actualClient = client
        addEvent("didChangeProperty(\(property))")
        expectation.fulfill()
    }
    
    func client(_ client: LightstreamerClient, willSendRequestForAuthenticationChallenge challenge: URLAuthenticationChallenge) {
        actualClient = client
        addEvent("willSendRequestForAuthenticationChallenge")
        expectation.fulfill()
    }
}
