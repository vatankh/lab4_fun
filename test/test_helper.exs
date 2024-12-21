ExUnit.start()

Mox.defmock(MyApp.Distribution.NodeResponsibilityManagerMock,
  for: MyApp.Distribution.NodeResponsibilityManagerBehaviour
)

Mox.defmock(MyApp.API.RPCMock,
  for: MyApp.API.RPCBehaviour
)
Mox.defmock(MyApp.MockClient, for: MyApp.API.ClientBehaviour)
