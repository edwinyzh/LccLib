//
// Reads the information about what memory spaces are available to a datagram
//

{$IFNDEF DWSCRIPT}
{$I lcc_compilers.inc}
{$ENDIF}

unit lcc_protocol_memory_information;

interface

uses
{$IFDEF DWSCRIPT}
  System.Types,
  System.Types.Convert,
  System.Time,
  System.Streams,
  System.Reader,
  System.Writer,
  System.Lists,
  System.Device.Storage,
  SmartCL.Device.Storage,
  SmartCL.Application,
  SmartCL.Components,
  SmartCL.System,
{$ELSE}
  Classes,
  SysUtils,
  {$IFDEF DELPHI}
  System.Generics.Collections,
  {$ELSE}
  contnrs,
  {$ENDIF}
{$ENDIF}
  lcc_protocol_base,
  lcc_defines,
  lcc_node_messages,
  lcc_utilities;

type

  TConfigMemAddressSpaceInfoObject = class
  private
    FHighAddress: DWord;
    FIsReadOnly: Boolean;
    FImpliedZeroLowAddress: Boolean;
    FLowAddress: DWord;
    FIsPresent: Boolean;
    FAddressSpace: Byte;
  public
    property AddressSpace: Byte read FAddressSpace;
    property IsPresent: Boolean read FIsPresent;
    property IsReadOnly: Boolean read FIsReadOnly;
    property ImpliedZeroLowAddress: Boolean read FImpliedZeroLowAddress;
    property LowAddress: DWord read FLowAddress;
    property HighAddress: DWord read FHighAddress;
  end;

  { TProtocolMemoryInfo }

  TProtocolMemoryInfo = class(TNodeProtocolBase)
  private
    {$IFDEF DELPHI}
    FList: TObjectList<TConfigMemAddressSpaceInfoObject>;
    {$ELSE}
    FList: TObjectList;
    {$ENDIF}
    function GetAddressSpace(Index: Integer): TConfigMemAddressSpaceInfoObject;
    function GetCount: Integer;
  protected
    {$IFDEF DELPHI}
     property List: TObjectList<TConfigMemAddressSpaceInfoObject> read FList write FList;
    {$ELSE}
     property List: TObjectList read FList write FList;
    {$ENDIF}

  public
    property AddressSpace[Index: Integer]: TConfigMemAddressSpaceInfoObject read GetAddressSpace; default;
    property Count: Integer read GetCount;

    constructor Create(ASendMessageFunc: TOnMessageEvent); override;
    destructor Destroy; override;
    procedure Add(_Space: Byte; _IsPresent, _IsReadOnly, _ImpliedZeroLowAddress: Boolean; _LowAddress, _HighAddress: DWord);
    procedure Clear;
    function FindByAddressSpace(Space: Byte): TConfigMemAddressSpaceInfoObject;
    procedure LoadReply(LccMessage: TLccMessage; OutMessage: TLccMessage);
//    function ProcessMessage(SourceLccMessage: TLccMessage): Boolean; override;
  end;

implementation

{ TProtocolMemoryInfo }

procedure TProtocolMemoryInfo.Add(_Space: Byte; _IsPresent, _IsReadOnly, _ImpliedZeroLowAddress: Boolean; _LowAddress, _HighAddress: DWord);
var
 Info: TConfigMemAddressSpaceInfoObject;
begin
 Info := TConfigMemAddressSpaceInfoObject.Create;
 Info.FAddressSpace := _Space;
 Info.FIsPresent := _IsPresent;
 Info.FIsReadOnly := _IsReadOnly;
 Info.FImpliedZeroLowAddress := _ImpliedZeroLowAddress;
 Info.FLowAddress := _LowAddress;
 Info.FHighAddress := _HighAddress;
 List.Add(Info);
end;

procedure TProtocolMemoryInfo.Clear;
var
 i: Integer;
begin
 try
   for i := 0 to List.Count - 1 do
     TObject(List[i]).Free;
 finally
   List.Clear
 end;
end;

constructor TProtocolMemoryInfo.Create(ASendMessageFunc: TOnMessageEvent);
begin
 inherited Create(ASendMessageFunc);
 {$IFDEF DELPHI}
 List := TObjectList<TConfigMemAddressSpaceInfoObject>.Create;
 {$ELSE}
 List := TObjectList.Create;
 {$ENDIF}
 {$IFNDEF DWSCRIPT}
 List.OwnsObjects := False;
 {$ENDIF}
end;

destructor TProtocolMemoryInfo.Destroy;
begin
 Clear;
 FList.Free;
 inherited;
end;

function TProtocolMemoryInfo.FindByAddressSpace(Space: Byte): TConfigMemAddressSpaceInfoObject;
var
 i: Integer;
begin
 i := 0;
 Result := nil;
 while (i < Count) and not Assigned(Result) do
 begin
   if AddressSpace[i].AddressSpace = Space then
     Result := AddressSpace[i];
   Inc(i);
 end;
end;

function TProtocolMemoryInfo.GetAddressSpace(Index: Integer): TConfigMemAddressSpaceInfoObject;
begin
 Result := TConfigMemAddressSpaceInfoObject( List[Index])
end;

function TProtocolMemoryInfo.GetCount: Integer;
begin
 Result := List.Count
end;

procedure TProtocolMemoryInfo.LoadReply(LccMessage, OutMessage: TLccMessage);
var
 Info: TConfigMemAddressSpaceInfoObject;
begin
  // Decode the LccMessage
 Info := FindByAddressSpace( LccMessage.DataArrayIndexer[2]);
 OutMessage.DataArrayIndexer[0] := $20;
 if Assigned(Info) then
 begin
   if Info.IsPresent then
     OutMessage.DataArrayIndexer[1] := MCP_OP_GET_ADD_SPACE_INFO_PRESENT_REPLY
   else
     OutMessage.DataArrayIndexer[1] := MCP_OP_GET_ADD_SPACE_INFO_NOT_PRESENT_REPLY;
   OutMessage.DataArrayIndexer[2] := LccMessage.DataArrayIndexer[2];
   OutMessage.DataArrayIndexer[3] := _Highest(Info.FHighAddress);
   OutMessage.DataArrayIndexer[4] := _Higher(Info.FHighAddress);
   OutMessage.DataArrayIndexer[5] := _Hi(Info.FHighAddress);
   OutMessage.DataArrayIndexer[6] := _Lo(Info.FHighAddress);
   OutMessage.DataArrayIndexer[7] := 0;
   if Info.IsReadOnly then
     OutMessage.DataArrayIndexer[7] := OutMessage.DataArrayIndexer[7] or $01;
   OutMessage.DataCount := 8;
   if not Info.ImpliedZeroLowAddress then
   begin
     OutMessage.DataArrayIndexer[8] := _Highest(Info.FLowAddress);
     OutMessage.DataArrayIndexer[9] := _Higher(Info.FLowAddress);
     OutMessage.DataArrayIndexer[10] := _Hi(Info.FLowAddress);
     OutMessage.DataArrayIndexer[11] := _Lo(Info.FLowAddress);
     OutMessage.DataCount := 12;
   end;
 end else
 begin
   OutMessage.DataArrayIndexer[1] := MCP_OP_GET_ADD_SPACE_INFO_NOT_PRESENT_REPLY;
   OutMessage.DataArrayIndexer[2] := LccMessage.DataArrayIndexer[2];
   OutMessage.DataArrayIndexer[3] := 0;
   OutMessage.DataArrayIndexer[4] := 0;
   OutMessage.DataArrayIndexer[5] := 0;
   OutMessage.DataArrayIndexer[6] := 0;
   OutMessage.DataArrayIndexer[7] := $01;
   OutMessage.DataCount := 8;
 end;
end;

{
function TProtocolMemoryInfo.ProcessMessage(SourceLccMessage: TLccMessage): Boolean;
var
 Info: TConfigMemAddressSpaceInfoObject;
 IsPresent, ImpliedZeroAddress, IsReadOnly: Boolean;
 Space: Byte;
begin
 Result := True;
 IsPresent := SourceLccMessage.DataArrayIndexer[1] = MCP_OP_GET_ADD_SPACE_INFO_PRESENT_REPLY;
 ImpliedZeroAddress := SourceLccMessage.DataArrayIndexer[7] and $02 = 0;
 IsReadOnly := SourceLccMessage.DataArrayIndexer[7] and $01 <> 0;
 Space := SourceLccMessage.DataArrayIndexer[2];

 Info := FindByAddressSpace(Space);
 if not Assigned(Info) then
 begin
   if ImpliedZeroAddress then
     Add(Space,                                       // Space
         IsPresent,                                   // Present?
         IsReadOnly,                                  // Readonly?
         ImpliedZeroAddress,                          // Implied Zero Address
         0,                                           // Low Memory Address
         SourceLccMessage.ExtractDataBytesAsInt(3, 6))      // High Memory Address
   else
     Add(Space,                                       // Space
         IsPresent,                                   // Present?
         IsReadOnly,                                  // Readonly?
         ImpliedZeroAddress,                          // Implied Zero Address
         SourceLccMessage.ExtractDataBytesAsInt(8, 11),     // Low Memory Address
         SourceLccMessage.ExtractDataBytesAsInt(3, 6));     // High Memory Address
 end;
 Valid := True;                                       // Had at least one....
end;
}
end.

