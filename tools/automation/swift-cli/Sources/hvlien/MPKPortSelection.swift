import Foundation

public func mpkPort2Present(_ d: ControllerDevice) -> Bool {
  let inOk = d.endpointsIn.contains { $0.normName.contains("port 2") }
  let outOk = d.endpointsOut.contains { $0.normName.contains("port 2") }
  return inOk && outOk
}
