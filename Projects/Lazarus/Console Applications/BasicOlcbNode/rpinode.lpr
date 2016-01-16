program rpinode;

{$mode objfpc}{$H+}

{$IFDEF darwin}
  {$DEFINE UseCThreads}
{$ENDIF}
{$IFDEF linux}
  {$DEFINE UseCThreads}
{$ENDIF}


uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  { you can add units after this }
  crt, lcc_nodemanager, lcc_app_common_settings, lcc_ethernetclient, lcc_ethenetserver,
  lcc_messages, lcc_raspberrypi
  ;

const
  LF = #10+#13;
const
  // SETTINGS_PATH = '/Users/jimkueneman/Documents/LccLib/Projects/Lazarus/Console Applications/BasicOlcbNode/settings.ini';
 // SETTINGS_PATH = '/home/pi/Documents/LccLib/Projects/LazarusRaspberryPi/RPiOlcbNode/settings.ini';
 SETTINGS_PATH = '/home/pi/Documents/LccLib/Projects/Lazarus/Console Applications/BasicOlcbNode/settings.ini';
//  SETTINGS_PATH = './settings.ini';
  CDI_PATH      = './example_cdi.xml';

type

  { TOlcbNodeApplication }

  TOlcbNodeApplication = class(TCustomApplication)
  private
    FConnected: Boolean;
    FEthernet: TLccEthernetClient;
    FEthernetServer: TLccEthernetServer;
    FFailedConnecting: Boolean;
    FIsServer: Boolean;
    FLccSettings: TLccSettings;
    FNodeManager: TLccNodeManager;
    FTriedConnecting: Boolean;
  protected
    procedure DoRun; override;
    procedure EthernetConnectChange(Sender: TObject; EthernetRec: TLccEthernetRec);
    function CreateOlcbServer: Boolean;
    function LogIntoOlcbNetwork: Boolean;

    property FailedConnecting: Boolean read FFailedConnecting write FFailedConnecting;
    property TriedConnecting: Boolean read FTriedConnecting write FTriedConnecting;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;

    property Connected: Boolean read FConnected write FConnected;
    property Ethernet: TLccEthernetClient read FEthernet write FEthernet;
    property EthernetServer: TLccEthernetServer read FEthernetServer write FEthernetServer;
    property IsServer: Boolean read FIsServer write FIsServer;
    property LccSettings: TLccSettings read FLccSettings write FLccSettings;
    property NodeManager: TLccNodeManager read FNodeManager write FNodeManager;
  end;

{ TOlcbNode }

procedure TOlcbNodeApplication.DoRun;
var
  ErrorMsg: String;
  Running: Boolean;
  Uart: TRaspberryPiUart;
  Buffer, RxBuffer: TPiUartBuffer;
  RxCount, i: Integer;
begin
  Uart := TRaspberryPiUart.Create;
  Uart.Speed:= pus_9600Hz;
  if Uart.OpenUart('/dev/' + GetRaspberryPiUartPortNames) then
  begin
    Buffer[0] := 0;
    while true do
    begin
      Uart.Write(@Buffer, 1);
      Inc(Buffer[0]);
      Delay(1);
   //   RxCount := Uart.Read(@RxBuffer, 1);
   //   for i := 0 to RxCount - 1 do
   //     WriteLn(IntToHex(RxBuffer[i], 2));
    end;
    Uart.CloseUart;
  end;
  Uart.Free;

  // quick check parameters
  ErrorMsg:=CheckOptions('h s', 'help server');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  if HasOption('s', 'server') then
    IsServer := True;

  { add your program here }
  LccSettings.FilePath := SETTINGS_PATH;
  if not FileExists(SETTINGS_PATH) then
    LccSettings.SaveToFile
  else
    LccSettings.LoadFromFile;

  if IsServer then
    NodeManager.HardwareConnection := EthernetServer
  else
    NodeManager.HardwareConnection := Ethernet;

  NodeManager.CAN := True;

  Ethernet.GridConnect := True;
  EthernetServer.Gridconnect := True;

  if IsServer then
  begin
    if CreateOlcbServer then
    begin
      Running := True;
      NodeManager.Enabled := True;
      WriteLn('Enabled');
      while Running do
      begin
        CheckSynchronize();  // Pump the timers
        if KeyPressed then
          Running := ReadKey <> 'q';
      end;
    end;
  end else
  begin
    if LogInToOlcbNetwork then
    begin
      Running := True;
      NodeManager.Enabled := True;
      WriteLn('Enabled');
      while Running do
      begin
        CheckSynchronize();  // Pump the timers
        if KeyPressed then
          Running := ReadKey <> 'q';
      end;
    end;


    NodeManager.Enabled := False;
    Ethernet.CloseConnection(nil);
    EthernetServer.CloseConnection(nil);
    NodeManager.HardwareConnection := nil;
    Ethernet.NodeManager := nil;
    EthernetServer.NodeManager := nil;
    FreeAndNil(FLccSettings);
    FreeAndNil(FEthernet);
    FreeAndNil(FEthernetServer);
    FreeAndNil(FNodeManager);
    WriteLn('Exiting');
  end;

  // stop program loop
  Terminate;
end;

procedure TOlcbNodeApplication.EthernetConnectChange(Sender: TObject; EthernetRec: TLccEthernetRec);
begin
  case EthernetRec.ConnectionState of
    ccsClientConnecting :
      begin
        WriteLn('Connecting');
        TriedConnecting := True;
      end;
    ccsClientConnected :
      begin
        WriteLn('Connected');
        WriteLn('IP = ' + EthernetRec.ClientIP + ' ' + IntToStr(EthernetRec.ClientPort));
        Connected := True;
      end;
    ccsClientDisconnecting :
      begin
        WriteLn('DisConnecting');
      end;
    ccsClientDisconnected :
      begin
        WriteLn('DisConnected');
        FailedConnecting := True;
      end;
    ccsListenerConnecting :
      begin
        WriteLn('Connecting Listener');
        TriedConnecting := True;
      end;
    ccsListenerConnected :
      begin
        WriteLn('Connected Listener');
        WriteLn('IP = ' + EthernetRec.ListenerIP + ' ' + IntToStr(EthernetRec.ListenerPort));
        Connected := True;
      end;
    ccsListenerDisconnecting :
      begin

      end;
    ccsListenerDisconnected :
      begin

      end;
    ccsListenerClientConnecting :
      begin

      end;
    ccsListenerClientConnected :
      begin
        WriteLn('New Client');
        WriteLn('IP = ' + EthernetRec.ListenerIP + ' ' + IntToStr(EthernetRec.ListenerPort));
        WriteLn('IP = ' + EthernetRec.ClientIP + ' ' + IntToStr(EthernetRec.ClientPort));
        Connected := True;
      end;
  end;
end;

function TOlcbNodeApplication.LogIntoOlcbNetwork: Boolean;
var
  WaitCount: Integer;
begin
  Result := True;
  while not Connected and Result do
  begin
    TriedConnecting := False;
    FailedConnecting := False;
    Ethernet.OpenConnectionWithLccSettings;
    while not TriedConnecting do
    begin
      if KeyPressed then Result := ReadKey <> 'q';
      CheckSynchronize();  // Pump the timers
    end;
    while not FailedConnecting and not Connected do
    begin
      if KeyPressed then Result := ReadKey <> 'q';
      CheckSynchronize();  // Pump the timers
    end;
    if FailedConnecting then
    begin
      WaitCount := 0;
      while (WaitCount < 50) and Result do
      begin
        if KeyPressed then Result := ReadKey <> 'q';
        Sleep(100);
        Inc(WaitCount);
      end;
    end;
  end;
end;

constructor TOlcbNodeApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
  LccSettings := TLccSettings.Create(nil);
  NodeManager := TLccNodeManager.Create(nil);
  Ethernet := TLccEthernetClient.Create(nil);
  EthernetServer := TLccEthernetServer.Create(nil);
  NodeManager.CreateRootNode;
  NodeManager.LccSettings := LccSettings;
  NodeManager.RootNode.CDI.LoadFromXml(CDI_PATH);
  NodeManager.RootNode.EventsConsumed.AutoGenerate.Count := 10;
  NodeManager.RootNode.EventsConsumed.AutoGenerate.Enable := True;
  NodeManager.RootNode.EventsProduced.AutoGenerate.Count := 10;
  NodeManager.RootNode.EventsProduced.AutoGenerate.Enable := True;
  Ethernet.LccSettings := LccSettings;
  Ethernet.OnConnectionStateChange := @EthernetConnectChange;
  Ethernet.NodeManager := NodeManager;
  EthernetServer.LccSettings := LccSettings;
  EthernetServer.OnConnectionStateChange := @EthernetConnectChange;
  EthernetServer.NodeManager := NodeManager;
end;

function TOlcbNodeApplication.CreateOlcbServer: Boolean;
var
  WaitCount: Integer;
begin
  Result := True;
  while not Connected and Result do
  begin
    TriedConnecting := False;
    FailedConnecting := False;
    EthernetServer.OpenConnectionWithLccSettings;
    while not TriedConnecting do
    begin
      if KeyPressed then Result := ReadKey <> 'q';
      CheckSynchronize();  // Pump the timers
    end;
    while not FailedConnecting and not Connected do
    begin
      if KeyPressed then Result := ReadKey <> 'q';
      CheckSynchronize();  // Pump the timers
    end;
    if FailedConnecting then
    begin
      WaitCount := 0;
      while (WaitCount < 50) and Result do
      begin
        if KeyPressed then Result := ReadKey <> 'q';
        Sleep(100);
        Inc(WaitCount);
      end;
    end;
  end;
end;

destructor TOlcbNodeApplication.Destroy;
begin
  inherited Destroy;
end;

procedure TOlcbNodeApplication.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: TOlcbNodeApplication;
begin
  Application:=TOlcbNodeApplication.Create(nil);
  Application.Title:='OpenLcb Node';
  Application.Run;
  Application.Free;
end.
