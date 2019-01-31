unit DentalObjectModels;

interface

uses
  SysUtils, DentalDataFeeders, DentalIntf, DB, uCommonDefinitions,
  Classes, WideStrings, VirtualTrees, Controls, uDB;

type
  TDentalInterfacedObject = class(TObject)
  protected
    FRefCount: Integer;
    function QueryInterface(const IID: TGUID; out Obj): HResult; virtual; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    class function NewInstance: TObject; override;
    property RefCount: Integer read FRefCount;
  end;

  TAbstractOM = class(TInterfacedObject, IAbstractOM)
  protected
    FSync: TMultiReadExclusiveWriteSynchronizer;
    FState: omStates;
  protected
    { IAbstractOM }
    procedure Init; virtual;
  public
    { class methods }
    constructor Create;
    destructor Destroy; override;
  end;

  TDbAwaredOM = class(TAbstractOM, IDbAwaredOM)
  protected
    FDbEventName: string;
    FDataFeeder: IDataFeeder;
    procedure CreateDataFeeder; virtual;
  protected
    procedure Init; override;
    {IDbAwaredOM}
    function GetListSource: TDataSet; virtual;
    procedure ProcessDbEvent(EventName: string); virtual;
  public
    { class methods }
    constructor Create;
    destructor Destroy; override;
  end;

  TListedOM = class(TDbAwaredOM, IListedOM)
  protected
    FCurrentID: IDentifier;
    procedure FOnDataFeederChangedCurrentID(NewID: integer);
    procedure InternalSetCurrentID(NewID: integer); virtual;
  protected
    { IListedOM }
    function GetCurrentID: IDentifier;
    procedure SetCurrentID(Value: IDentifier); virtual;
    property CurrentID: IDentifier read GetCurrentID write SetCurrentID;
    function IsRecordPointed: boolean;
    procedure Init; override;
  public
    { class methods }
    constructor Create;
    destructor Destroy; override;
  end;

  TMasteredOM = class(TListedOM, IMasterDrivenList)
  protected
    FMasterID: IDentifier;
    FForceSetMasterID: boolean;
    function GetMasterID: IDentifier;
    procedure SetMasterID(Value: IDentifier);
  protected
    { IMasterDrivenList }
    property MasterID: IDentifier read GetMasterID write SetMasterID;
    procedure MasterIDChanged(NewMasterIDValue: IDentifier);
  public
    { class methods }
    constructor Create;
    destructor Destroy; override;
  end;

  TCompositedOM = class(TMasteredOM, ICompositedList)
  private
    FOnNotifySuperModelCurrentIDChanged: TOnNotifySuperModel;
    function GetOnNotifySuperModelCurrentIDChanged: TOnNotifySuperModel;
    procedure SetOnNotifySuperModelCurrentIDChanged(Value: TOnNotifySuperModel);
  private
    procedure DoNotifySuperModelCurrentIDChanged;
  protected
    procedure InternalSetCurrentID(NewID: integer); override;
  protected
    { ICompositedList }
    property OnNotifySuperModelCurrentIDChanged: TOnNotifySuperModel read GetOnNotifySuperModelCurrentIDChanged write SetOnNotifySuperModelCurrentIDChanged;
  end;

  TListedObject = class({TInterfacedObject}TAbstractOM, IListedObject)
  protected
    FProps: IProperties;
    FID: IDentifier;
    FDataFeeder: IObjectDataFeeder;
    FEditViewState: TEditViewState;
    FForcedCloseNoSave: boolean;
    FForcedCloseWithSave: boolean;
    function GetID: IDentifier;
    procedure SetID(Value: IDentifier); virtual;
    function GetProperties: IProperties;
    procedure SetProperties(Value: IProperties);
    function GetEditState: TEditViewState;
    procedure SetEditState(Value: TEditViewState);
    procedure CreateDataFeeder; virtual; abstract;
    procedure CreateProperties; virtual; abstract;
    function CreateTempDataFeeder: IDataFeeder; virtual; abstract;
    procedure SetForcedCloseWithSave(const Value: boolean);
    function GetForcedCloseWithSave: boolean;
    procedure SetForcedCloseNoSave(const Value: boolean);
    function GetForcedCloseNoSave: boolean;
  protected
    { IListedObject }
    property ID: IDentifier read GetID write SetID;
    property Props: IProperties read GetProperties write SetProperties;
    function Edit(AOpenState: TOpenState = osEditOnly): ObjDbConvState; virtual;
    function Delete: ObjDbConvState; virtual;
    procedure EditProps; virtual;
    function Save(AProps: IProperties): ObjDbConvState;
    function SaveWithRetry(AProps: IProperties): ObjDbConvState;
    function CreatePropForm: IEditPropForm; virtual; abstract;
    property EditState: TEditViewState read GetEditState write SetEditState;
    function OpenedForEdit: boolean; virtual;
    function OpenedForView: boolean; virtual;
    function ReadProperties(AOpenState: TOpenState = osEditOnly): ObjDbConvState; virtual;
    function IsCorrectBeforeSave(AProps: IProperties; var msg: widestring): boolean; virtual;
    property ForcedCloseWithSave: boolean read GetForcedCloseWithSave write SetForcedCloseWithSave;
    property ForcedCloseNoSave: boolean read GetForcedCloseNoSave write SetForcedCloseNoSave;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TVirtualIDList = class(TInterfacedObject, IVirtualIDList)
  protected
    FState: omStates;
    FOnChangedSrcIdx: TOnChangedSrcIdx;
    FID: IDentifier;
    FSrcIdx: integer;
    FOnNotifySuperModelIdChanged: TOnNotifySuperModel;
    function GetID: integer;
    procedure SetID(const Value: integer); virtual; abstract;
    procedure DoChangedSrcIdx;
    function GetOnChangedSrcIdx: TOnChangedSrcIdx;
    procedure SetOnChangedSrcIdx(const Value: TOnChangedSrcIdx);
    function GetSrcIdx: integer;
    procedure SetSrcIdx(const Value: integer); virtual; abstract;
    function GetOnNotifySuperModelIdChanged: TOnNotifySuperModel;
    procedure SetOnNotifySuperModelIdChanged(Value: TOnNotifySuperModel);
    procedure DoNotifySuperModelIdChanged;
  protected
    { IVirtualIDList }
    property ID: integer read GetID write SetID;
    property SrcIdx: integer read GetSrcIdx write SetSrcIdx;
    property OnChangedSrcIdx: TOnChangedSrcIdx read GetOnChangedSrcIdx write SetOnChangedSrcIdx;
    property OnNotifySuperModelIdChanged: TOnNotifySuperModel read GetOnNotifySuperModelIdChanged write SetOnNotifySuperModelIdChanged;
    function GetList: TWideStrings; virtual; abstract;
    procedure Init; virtual;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TCompositeProperties = class(TDentalInterfacedObject, IProperties, ICompositeProperties)
  private
    FPropList: TInterfaceList;
  protected
    function GetProp(Idx: integer): IProperties;
    function GetPropCount: integer;
    function QueryInterface(const IID: TGUID; out Obj): HResult; override; stdcall;
  protected
    property Prop[Idx: integer]: IProperties read GetProp;
    function RegisterProp(Prop: IProperties): integer;
    property PropCount: integer read GetPropCount;
    function Clone: IProperties; virtual;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TOption = class(TInterfacedObject, IOption)
  protected
    FName: string;
    FValue: Variant;
    function GetName: string;
    procedure SetName(const Value: string);
    function GetValue: Variant;
    procedure SetValue(const Value: Variant);
  protected
    property Name: string read GetName write SetName;
    property Value: Variant read GetValue write SetValue;
  end;

  TOptions = class(TInterfacedObject, IOptions)
  private
    LocalDbm: TdbmDental;
  protected
    FList: TInterfaceList;
    FDataSet, FKeyField, FNameField, FValueField, FTypeField: string;
    function GetOption(Name: string): Variant;
    procedure SetOption(Name: string; const Value: Variant);
    function GetOptionDef(Name: string; Default: Variant): Variant;
    function _Find(Name: string): IOption;
  protected
    property Option[Name: string]: Variant read GetOption write SetOption;
    property OptionDef[Name: string; Default: Variant]: Variant read GetOptionDef; default;
    procedure Load;
    procedure Save;
  public
    constructor Create(Adbm: TdbmDental; ADataSet, AKeyField, ANameField, AValueField, ATypeField: string);
    destructor Destroy; override;
  end;

  TCachePointList = class(TList)
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  end;

  TBuildCacheItem = class(TObject)
  public
    pid: IDentifier;
    list: TList;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
  end;

  TBuildCache = class(TList)
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  public
    procedure Clear; override;
    function FindId(id: IDentifier): pointer;
  end;

  TBuildCachePoint = class(TObject)
  public
    id: IDentifier;
    deleted: boolean;
    constructor Create;
  end;

  TAbstractVTAdapter = class(TInterfacedObject, IAbstractVTAdapter)
  protected
    FVT, FOldVT: TVirtualStringTree;
    FBuildCache: TBuildCache;
    FGetName: TOnGetName;
    procedure SetVT(const Value: TVirtualStringTree); virtual;
    function GetVT: TVirtualStringTree;
    function GetOnAddNode: TOnAddNode;
    property procOnAddNode: TOnAddNode read GetOnAddNode;
    function GetOnBeginBuildTree: TOnBuildTree;
    property procOnBeginBuildTree: TOnBuildTree read GetOnBeginBuildTree;
    function GetOnEndBuildTree: TOnBuildTree;
    property procOnEndBuildTree: TOnBuildTree read GetOnEndBuildTree;
    function GetOnBeginUpdateTree: TOnUpdateTree;
    property procOnBeginUpdateTree: TOnUpdateTree read GetOnBeginUpdateTree;
    function GetOnEndUpdateTree: TOnUpdateTree;
    property procOnEndUpdateTree: TOnUpdateTree read GetOnEndUpdateTree;
    procedure SetOnGetName(const Value: TOnGetName);
    function GetOnGetName: TOnGetName;
    function IsTopmostNode(ParentID: IDentifier): boolean; virtual;
  protected
    function _coreCompareStruID(Node: PVirtualNode; const StructID: IDentifier): boolean; virtual; abstract;
    procedure _coreAssignDataOnAddNode(Node: PVirtualNode; const StructID: IDentifier; const ADeleted: boolean); virtual;
    property OnGetName: TOnGetName read GetOnGetName write SetOnGetName;
    procedure OnAddNode(const StructID, ParentStructID: IDentifier; const ADeleted: boolean); virtual;
    procedure OnBeginBuildTree; virtual;
    procedure OnBeginUpdateTree; virtual;
    procedure OnEndBuildTree; virtual;
    procedure OnEndUpdateTree; virtual;
    procedure OnTreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType; var CellText: WideString); virtual;
    procedure OnTreeFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex); virtual;
    procedure OnTreeFocusChanging(Sender: TBaseVirtualTree;
      OldNode, NewNode: PVirtualNode; OldColumn, NewColumn: TColumnIndex; var Allowed: Boolean); virtual;
    procedure OnTreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode); virtual;
    procedure OnTreeCollapsed(Sender: TBaseVirtualTree; Node: PVirtualNode); virtual;
    procedure OnTreeKeyPress(Sender: TObject; var Key: Char); virtual;
    function FindNodeByData(const StructID: IDentifier): PVirtualNode; virtual; 
  protected
    FOldGetText: TVSTGetTextEvent;
    FOldFocusChanged: TVTFocusChangeEvent;
    FOldFocusChanging: TVTFocusChangingEvent;
    FOldCollapsed: TVTChangeEvent;
    FOldExpanded: TVTChangeEvent;
    FOldKeyPress: TKeyPressEvent;
  protected
    property VT: TVirtualStringTree read GetVT write SetVT;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  Dialogs, Windows, uErrorLog, Variants, PFibDataSet, PFibDataBase;

{ TAbstractOM }

constructor TAbstractOM.Create;
begin
  inherited;
  FSync := TMultiReadExclusiveWriteSynchronizer.Create;
  FState := omCreating;
end;

destructor TAbstractOM.Destroy;
begin
  if Assigned(FSync) then
    FreeAndNil(FSync);
  inherited;
end;

procedure TAbstractOM.Init;
begin
  FState := omIdle;
end;

{ TDbAwaredOM }

constructor TDbAwaredOM.Create;
begin
  inherited;
  CreateDataFeeder;
end;

procedure TDbAwaredOM.CreateDataFeeder;
begin
  FDataFeeder := TBaseDataFeeder.Create;
end;

destructor TDbAwaredOM.Destroy;
begin
  FDataFeeder := nil;
  inherited;
end;

function TDbAwaredOM.GetListSource: TDataSet;
begin
  Result := FDataFeeder.GetListSource;
end;

procedure TDbAwaredOM.Init;
begin
  FDataFeeder.Init;
  inherited;
end;

procedure TDbAwaredOM.ProcessDbEvent(EventName: string);
begin
  if AnsiCompareText(EventName, FDbEventName)=0 then
    FDataFeeder.ProcessDbEvent(EventName);
end;

{ TListedOM }

procedure TListedOM.InternalSetCurrentID(NewID: integer);
begin
  FCurrentID := NewID;
end;

constructor TListedOM.Create;
begin
  inherited;
  FState := omCreating;
  FCurrentID := UndefiniteID;
  (FDataFeeder as IListDataFeeder).OnChangedCurrentID := FOnDataFeederChangedCurrentID; 
end;

destructor TListedOM.Destroy;
begin
  inherited;
end;

procedure TListedOM.FOnDataFeederChangedCurrentID(NewID: integer);
begin
  CurrentID := (FDataFeeder as IListDataFeeder).CurrentID;
end;

function TListedOM.GetCurrentID: IDentifier;
begin
  Result := FCurrentID;
end;

function TListedOM.IsRecordPointed: boolean;
begin
  Result := FCurrentID<>UndefiniteID;
end;

procedure TListedOM.SetCurrentID(Value: IDentifier);
begin
  if FState<>omCreating then
    if FCurrentID<>Value then
      InternalSetCurrentID(Value);
end;

procedure TListedOM.Init;
begin
  inherited;
  (FDataFeeder as IListDataFeeder).PostInit;
end;

{ TMasteredOM }

constructor TMasteredOM.Create;
begin
  inherited;
  FMasterID := UndefiniteID;
  FForceSetMasterID := False;
end;

destructor TMasteredOM.Destroy;
begin
  inherited;
end;

function TMasteredOM.GetMasterID: IDentifier;
begin
  Result := FMasterID;
end;

procedure TMasteredOM.MasterIDChanged(NewMasterIDValue: IDentifier);
begin
  MasterID := NewMasterIDValue;
end;

procedure TMasteredOM.SetMasterID(Value: IDentifier);
begin
  if FState<>omCreating then
    if (FMasterID<>Value) or FForceSetMasterID then
    begin
      FMasterID := Value;
      (FDataFeeder as IMasterDrivenDataFeeder).MasterID := Value;
    end;
end;

{ TCompositedOM }

procedure TCompositedOM.InternalSetCurrentID(NewID: integer);
begin
  inherited;
  DoNotifySuperModelCurrentIDChanged;
end;

procedure TCompositedOM.DoNotifySuperModelCurrentIDChanged;
begin
  if Assigned(FOnNotifySuperModelCurrentIDChanged) then
    FOnNotifySuperModelCurrentIDChanged;
end;

function TCompositedOM.GetOnNotifySuperModelCurrentIDChanged: TOnNotifySuperModel;
begin
  Result := FOnNotifySuperModelCurrentIDChanged;
end;

procedure TCompositedOM.SetOnNotifySuperModelCurrentIDChanged(
  Value: TOnNotifySuperModel);
begin
  FOnNotifySuperModelCurrentIDChanged := Value;
end;

{ TListedObject }

constructor TListedObject.Create;
begin
  inherited;
  FEditViewState := evsUndef;
  FID := UndefiniteID;
  CreateProperties;
  CreateDataFeeder;
  FForcedCloseNoSave := False;
  FForcedCloseWithSave := False;
end;

function TListedObject.Delete: ObjDbConvState;
begin                        
  Result := FDataFeeder.Delete(FID, FProps);
  case Result of
  dbopSucc:
    ;
  dbopLocked:
    ErrorLog.AddToLog('Запись уже кто-то редактирует. Попробуйте позже');
  dbopFailed:
    ErrorLog.AddToLog('Ошибка в базе данных. Попробуйте позже');
  end;
end;

destructor TListedObject.Destroy;
begin
  FDataFeeder := nil;
  FProps := nil;
  inherited;
end;

function TListedObject.Edit(AOpenState: TOpenState = osEditOnly): ObjDbConvState;
begin
  Result := FDataFeeder.Read(FID, FProps, AOpenState, FEditViewState);
  case Result of
  dbopSucc:
    EditProps;
  dbopLocked:
    ErrorLog.AddToLog('Запись уже кто-то редактирует. Попробуйте позже');
  dbopFailed:
    ErrorLog.AddToLog('Ошибка в базе данных. Попробуйте позже');
  end;
end;

procedure TListedObject.EditProps;
var
  f: IEditPropForm;
begin
  f := CreatePropForm;
  try
    f.ListedObject := Self;
    f.EditedProps := FProps.Clone;
    if OpenedForView then
      f.OnOpenInViewMode;
    f.ShowPropForm;
    if f.SavedSuccess then
      FProps := f.EditedProps;
  finally
    f.Terminate;
  end;
end;

function TListedObject.GetEditState: TEditViewState;
begin
  Result := FEditViewState; 
end;

function TListedObject.GetForcedCloseNoSave: boolean;
begin
  Result := FForcedCloseNoSave;
end;

function TListedObject.GetForcedCloseWithSave: boolean;
begin
  Result := FForcedCloseWithSave;
end;

function TListedObject.GetID: IDentifier;
begin
  Result := FID;
end;

function TListedObject.GetProperties: IProperties;
begin
  Result := FProps;
end;

function TListedObject.IsCorrectBeforeSave(AProps: IProperties; var msg: widestring): boolean;
begin
  msg := '';
  Result := True;
end;

function TListedObject.OpenedForEdit: boolean;
begin
  Result := FEditViewState=evsEdit;
end;

function TListedObject.OpenedForView: boolean;
begin
  Result := FEditViewState=evsView;
end;

function TListedObject.ReadProperties(AOpenState: TOpenState): ObjDbConvState;
var
  tempDF: IDataFeeder;
begin
  tempDF := CreateTempDataFeeder;
  try
    Result := (tempDF as IObjectDataFeeder).Read(FID, FProps, AOpenState, FEditViewState);
    case Result of
    dbopLocked:
      ErrorLog.AddToLog('Запись уже кто-то редактирует. Попробуйте позже');
    dbopFailed:
      ErrorLog.AddToLog('Ошибка в базе данных. Попробуйте позже');
    end;
  finally
    tempDF := nil;
  end;
end;

function TListedObject.Save(AProps: IProperties): ObjDbConvState;
begin
  Result := FDataFeeder.Save(FID, AProps);
end;

function TListedObject.SaveWithRetry(AProps: IProperties): ObjDbConvState;
begin
  Result := ObjDbConvUndef;
  if OpenedForEdit then
  begin
    repeat
      case FDataFeeder.Save(FID, AProps) of
      dbopSucc: Result := ObjDbConvSuccYes;
      dbopLocked:
        begin
          case MessageDlg('Запись уже кто-то редактирует. Попробовать сохранить опять?',
                          mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
            IdNo: Result := ObjDbConvSuccNo;
            IdCancel: Result := ObjDbConvCancelled;
          end;
        end;
      dbopFailed:
        begin
          case MessageDlg('Ошибка в базе данных. Попробовать сохранить опять?',
                          mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
            IdNo: Result := ObjDbConvSuccNo;
            IdCancel: Result := ObjDbConvCancelled;
          end;
        end;
      end;
    until Result <> ObjDbConvUndef;
  end;  
end;

procedure TListedObject.SetEditState(Value: TEditViewState);
begin
  FEditViewState := Value;
end;

procedure TListedObject.SetForcedCloseNoSave(const Value: boolean);
begin
  FForcedCloseNoSave := Value;
end;

procedure TListedObject.SetForcedCloseWithSave(const Value: boolean);
begin
  FForcedCloseWithSave := Value;
end;

procedure TListedObject.SetID(Value: IDentifier);
begin
  FID := Value;
end;

procedure TListedObject.SetProperties(Value: IProperties);
begin
  FProps := Value;
end;

{ TVirtualIDList }

constructor TVirtualIDList.Create;
begin
  inherited;
  FState := omCreating;
  FID := UndefiniteID;
  FSrcIdx := -1;
end;

destructor TVirtualIDList.Destroy;
begin
  inherited;
end;

procedure TVirtualIDList.DoChangedSrcIdx;
begin
  if Assigned(FOnChangedSrcIdx) then
    FOnChangedSrcIdx(FSrcIdx);
end;

procedure TVirtualIDList.DoNotifySuperModelIdChanged;
begin
  if Assigned(FOnNotifySuperModelIdChanged) then
    FOnNotifySuperModelIdChanged;
end;

function TVirtualIDList.GetID: integer;
begin
  Result := FID;
end;

function TVirtualIDList.GetOnChangedSrcIdx: TOnChangedSrcIdx;
begin
  Result := FOnChangedSrcIdx;
end;

function TVirtualIDList.GetOnNotifySuperModelIdChanged: TOnNotifySuperModel;
begin
  Result := FOnNotifySuperModelIdChanged;
end;

function TVirtualIDList.GetSrcIdx: integer;
begin
  Result := FSrcIdx;
end;

procedure TVirtualIDList.Init;
begin
  FState := omIdle;
end;

procedure TVirtualIDList.SetOnChangedSrcIdx(const Value: TOnChangedSrcIdx);
begin
  FOnChangedSrcIdx := Value;
end;

procedure TVirtualIDList.SetOnNotifySuperModelIdChanged(
  Value: TOnNotifySuperModel);
begin
  FOnNotifySuperModelIdChanged := Value;
end;

{ TCompositeProperties }

function TCompositeProperties.Clone: IProperties;
var
  i: integer;
begin
  Result := TCompositeProperties.Create;
  for i:=0 to FPropList.Count-1 do
    (Result as ICompositeProperties).RegisterProp((FPropList.Items[i] as IProperties).Clone);
end;

constructor TCompositeProperties.Create;
begin
  inherited;
  FPropList := TInterfaceList.Create;
end;

destructor TCompositeProperties.Destroy;
begin
  if Assigned(FPropList) then
    FreeAndNil(FPropList);
  inherited;
end;

function TCompositeProperties.GetProp(Idx: integer): IProperties;
begin
  Result := FPropList.Items[Idx] as IProperties;
end;

function TCompositeProperties.GetPropCount: integer;
begin
  Result := FPropList.Count;
end;

function TCompositeProperties.QueryInterface(const IID: TGUID; out Obj): HResult;
var
  i: integer;
begin
  Result := inherited QueryInterface(IID, Obj);
  if Result=E_NOINTERFACE then
    for i:=0 to FPropList.Count-1 do
    begin
      Result := (FPropList.Items[i] as IInterface).QueryInterface(IID, Obj);
      if Result<>E_NOINTERFACE then
        Break;
    end;
end;

function TCompositeProperties.RegisterProp(Prop: IProperties): integer;
begin
  Result := FPropList.Add(Prop);
end;

{ TDentalInterfacedObject }

function TDentalInterfacedObject._AddRef: Integer;
begin
  Result := InterlockedIncrement(FRefCount);
end;

function TDentalInterfacedObject._Release: Integer;
begin
  Result := InterlockedDecrement(FRefCount);
  if Result = 0 then
    Destroy;
end;

procedure TDentalInterfacedObject.AfterConstruction;
begin
// Release the constructor's implicit refcount
  InterlockedDecrement(FRefCount);
end;

procedure TDentalInterfacedObject.BeforeDestruction;
begin
  if RefCount <> 0 then
    System.Error(reInvalidPtr);
end;

class function TDentalInterfacedObject.NewInstance: TObject;
begin
  Result := inherited NewInstance;
  TDentalInterfacedObject(Result).FRefCount := 1;
end;

function TDentalInterfacedObject.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

{ TOption }

function TOption.GetName: string;
begin
  Result := FName;
end;

function TOption.GetValue: Variant;
begin
  Result := FValue;
end;

procedure TOption.SetName(const Value: string);
begin
  FName := Value;
end;

procedure TOption.SetValue(const Value: Variant);
begin
  FValue := Value;
end;

{ TOptions }

constructor TOptions.Create(Adbm: TdbmDental; ADataSet, AKeyField, ANameField, AValueField, ATypeField: string);
begin
  inherited Create;
  LocalDbm := Adbm;
  FList := TInterfaceList.Create;
  FDataSet := ADataSet;
  FKeyField := AKeyField;
  FNameField := ANameField;
  FValueField := AValueField;
  FTypeField := ATypeField;
end;

destructor TOptions.Destroy;
begin
  if Assigned(FList) then
    FList.Free;
  inherited;
end;

function TOptions.GetOption(Name: string): Variant;
var
  o: IOption;
begin
  Result := Null;
  o := _Find(Name);
  if o<>nil then
    Result := o.Value;
end;

function TOptions.GetOptionDef(Name: string; Default: Variant): Variant;
var
  o: IOption;
begin
  Result := Default;
  o := _Find(Name);
  if (o<>nil) and not (VarIsNull(o.Value) or VarIsEmpty(o.Value)) then
    Result := o.Value;
end;

procedure TOptions.Load;
var
  ds: TpFIBDataSet;
  tr: TpFIBTransaction;
  o: IOption;
begin
  FList.Clear;
  tr := LocalDbm.CreateTr;
  try
    tr.StartTransaction;
    ds := LocalDbm.CreateDS;
    try
      ds.Transaction := tr;
      ds.SQLs.SelectSQL.Text := 'select * from '+FDataSet;
      ds.Open;
      while not ds.Eof do
      begin
        o := TOption.Create;
        o.Name := VariantAsAnsiString(ds.FieldByName(FNameField).Value);
        o.Value := ReadVariant(ds, FValueField, FTypeField, Null);
        FList.Add(o);
        ds.Next;
      end;
    finally
      LocalDbm.CloseDS(ds);
    end;
  finally
    tr.Rollback;
    LocalDbm.CloseTR(tr);
  end;
end;

procedure TOptions.Save;
var
  ds: TpFIBDataSet;
  tr: TpFIBTransaction;
  o: IOption;
  i: integer;
begin
  tr := LocalDbm.CreateTr;
  try
    tr.StartTransaction;
    try
      ds := LocalDbm.CreateDS;
      try
        ds.Transaction := tr;
        ds.UpdateTransaction := tr;
        ds.AutoUpdateOptions.UpdateTableName := AnsiUpperCase(FDataSet);
        ds.AutoUpdateOptions.KeyFields := AnsiUpperCase(FKeyField);
        ds.SQLs.SelectSQL.Text := 'select * from '+FDataSet;
        ds.Open;
        for i:=0 to FList.Count-1 do
        begin
          o := FList.Items[i] as IOption;
          if not ds.Locate(FNameField, o.Name, [loCaseInsensitive]) then
          begin
            ds.Append;
            ds.FieldByName(FNameField).Value := o.Name;
          end
          else
            ds.Edit;

          WriteVariant(ds, FValueField, FTypeField, o.Value);
          ds.Post;
        end;
      finally
        LocalDbm.CloseDS(ds);
      end;

      tr.Commit;
    except
      tr.Rollback;
      Raise;
    end;
  finally
    LocalDbm.CloseTR(tr);
  end;
end;

procedure TOptions.SetOption(Name: string; const Value: Variant);
var
  o: IOption;
begin
  o := _Find(Name);
  if o=nil then
  begin
    o := TOption.Create;
    o.Name := Name;
    FList.Add(o);
  end;
  o.Value := Value;
end;

function TOptions._Find(Name: string): IOption;
var
  i: integer;
begin
  Result := nil;
  for i:=0 to FList.Count-1 do
    if AnsiCompareText((FList.Items[i] as IOption).Name, Name)=0  then
    begin
      Result := FList.Items[i] as IOption;
      Break;
    end;
end;

{ TAbstractVTAdapter }

constructor TAbstractVTAdapter.Create;
begin
  inherited;
  FBuildCache := TBuildCache.Create;
end;

destructor TAbstractVTAdapter.Destroy;
begin
  if Assigned(FBuildCache) then
    FBuildCache.Free;
  VT := nil;
  inherited;
end;

function TAbstractVTAdapter.FindNodeByData(const StructID: IDentifier): PVirtualNode;
var
  Node: PVirtualNode;
begin
  Result := nil;
  Node := FVT.RootNode.FirstChild;
  while Node<>nil do
  begin
    if _coreCompareStruID(Node, StructID) then
    begin
      Result := Node;
      Break;
    end;
    Node := FVT.GetNext(Node);
  end;
end;

function TAbstractVTAdapter.GetOnAddNode: TOnAddNode;
begin
  Result := OnAddNode;
end;

function TAbstractVTAdapter.GetOnBeginBuildTree: TOnBuildTree;
begin
  Result := OnBeginBuildTree;
end;

function TAbstractVTAdapter.GetOnBeginUpdateTree: TOnUpdateTree;
begin
  Result := OnBeginUpdateTree;
end;

function TAbstractVTAdapter.GetOnEndBuildTree: TOnBuildTree;
begin
  Result := OnEndBuildTree;
end;

function TAbstractVTAdapter.GetOnEndUpdateTree: TOnUpdateTree;
begin
  Result := OnEndUpdateTree;
end;

function TAbstractVTAdapter.GetOnGetName: TOnGetName;
begin
  Result := FGetName;
end;

function TAbstractVTAdapter.GetVT: TVirtualStringTree;
begin
  Result := FVT;
end;

function TAbstractVTAdapter.IsTopmostNode(ParentID: IDentifier): boolean;
begin
  Result := ParentID=UndefiniteID;
end;

procedure TAbstractVTAdapter.OnAddNode(const StructID, ParentStructID: IDentifier; const ADeleted: boolean);
var
  ParentNode: PVirtualNode;
  CacheItem: TBuildCacheItem;
  CachePoint: TBuildCachePoint;

  procedure _addNode(const StructID, ParentStructID: IDentifier; const ADeleted: boolean);
  var
    Node, ParentNode: PVirtualNode;
    CacheItem: TBuildCacheItem;
    i: integer;
  begin
    ParentNode := FindNodeByData(ParentStructID);
    Node := FVT.AddChild(ParentNode);
    _coreAssignDataOnAddNode(Node, StructID, ADeleted);

    // искать в кеше всех с id=StructID
    CacheItem := TBuildCacheItem(FBuildCache.FindId(StructID));
    if CacheItem<>nil then begin
      for i:=0 to CacheItem.list.Count-1 do  begin
        CachePoint := TBuildCachePoint(CacheItem.list.Items[i]);
        _addNode(CachePoint.id, StructID, CachePoint.deleted);
      end;
      CacheItem.Clear;
    end;
  end;

begin
  ParentNode := FindNodeByData(ParentStructID);
  // если не нашли в дереве парента
  if ParentNode=nil then begin
    // если это нода верхнего уровня
    if IsTopmostNode(ParentStructID) then begin
      _addNode(StructID, ParentStructID, ADeleted);
    end else begin
      // ищем в кеше Parent
      CacheItem := TBuildCacheItem(FBuildCache.FindId(ParentStructID));
      if CacheItem=nil then begin
        CacheItem := TBuildCacheItem.Create;
        CacheItem.pid := ParentStructID;
        FBuildCache.Add(Pointer(CacheItem));
      end;
      CachePoint := TBuildCachePoint.Create;
      CachePoint.id := StructID;
      CachePoint.deleted := ADeleted;
      CacheItem.list.Add(Pointer(CachePoint));
    end;
  end else
    _addNode(StructID, ParentStructID, ADeleted);
end;

procedure TAbstractVTAdapter.OnBeginBuildTree;
begin
  FVT.BeginUpdate;
  FVT.Clear;
  FBuildCache.Clear;
end;

procedure TAbstractVTAdapter.OnBeginUpdateTree;
begin
  FVT.BeginUpdate;
end;

procedure TAbstractVTAdapter.OnEndBuildTree;
begin
  FVT.EndUpdate;
  FBuildCache.Clear;
end;

procedure TAbstractVTAdapter.OnEndUpdateTree;
begin
  FVT.EndUpdate;
end;

procedure TAbstractVTAdapter.OnTreeCollapsed(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  Sender.FocusedNode := Node;
  if Assigned(FOldCollapsed) then
    FOldCollapsed(Sender, Node);
end;

procedure TAbstractVTAdapter.OnTreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  Sender.FocusedNode := Node;
  if Assigned(FOldExpanded) then
    FOldExpanded(Sender, Node);
end;

procedure TAbstractVTAdapter.OnTreeFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
begin
  if Assigned(FOldFocusChanged) then
    FOldFocusChanged(Sender, Node, Column);
  if Node<>nil then
    Sender.Selected[Node] := True;
end;

procedure TAbstractVTAdapter.OnTreeFocusChanging(Sender: TBaseVirtualTree; OldNode, NewNode: PVirtualNode; OldColumn, NewColumn: TColumnIndex; var Allowed: Boolean);
begin
  if Assigned(FOldFocusChanging) then
    FOldFocusChanging(Sender, OldNode, NewNode, OldColumn, NewColumn, Allowed);
end;

procedure TAbstractVTAdapter.OnTreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: WideString);
begin
  if Assigned(FOldGetText) then
    FOldGetText(Sender, Node, Column, TextType, CellText);
end;

procedure TAbstractVTAdapter.OnTreeKeyPress(Sender: TObject; var Key: Char);
var
  Node: PVirtualNode;
begin
  if Key='-' then begin
    Node := FVT.FocusedNode;
    if Node<>nil then begin
      if FVT.HasChildren[Node] then begin // если раздел
        if FVT.Expanded[Node] then // если он открыт, то его надо сворачиваем (это и сделаем ниже)
        else // а если раздел ужа закрыт, то надо свернуть его Parent'а
          Node := Node^.Parent;
      end else begin
        Node := Node^.Parent;
      end;
      if Node<>nil then begin // если выше брали Parent'а от первоначальной ноды, то надо проверить, чтобы они, эти Parent'ы, существовали
        FVT.Expanded[Node] := False;
        FVT.FocusedNode := Node;
      end;
    end;
  end;
  if Assigned(FOldKeyPress) then
    FOldKeyPress(Sender, Key);
end;

procedure TAbstractVTAdapter.SetOnGetName(const Value: TOnGetName);
begin
  FGetName := Value;
end;

procedure TAbstractVTAdapter.SetVT(const Value: TVirtualStringTree);
begin
  FOldVT := FVT;
  FVT := Value;
  if FVT<>nil then
  begin
    FOldGetText := FVT.OnGetText;
    FOldFocusChanged := FVT.OnFocusChanged;
    FOldFocusChanging := FVT.OnFocusChanging;
    FOldCollapsed := FVT.OnCollapsed;
    FOldExpanded  := FVT.OnExpanded;
    FOldKeyPress  := FVT.OnKeyPress;
    FVT.OnGetText := OnTreeGetText;
    FVT.OnFocusChanged := OnTreeFocusChanged;
    FVT.OnFocusChanging := OnTreeFocusChanging;
    FVT.OnCollapsed := OnTreeCollapsed;
    FVT.OnExpanded  := OnTreeExpanded;
    FVT.OnKeyPress  := OnTreeKeyPress;
  end
  else
  begin
    if FOldVT<>nil then
    begin
      FOldVT.OnGetText := FOldGetText;
      FOldVT.OnFocusChanged := FOldFocusChanged;
      FOldVT.OnFocusChanging := FOldFocusChanging;
      FOldVT.OnCollapsed := FOldCollapsed;
      FOldVT.OnExpanded  := FOldExpanded;
      FOldVT.OnKeyPress  := FOldKeyPress;
    end;
  end;
end;

procedure TAbstractVTAdapter._coreAssignDataOnAddNode(Node: PVirtualNode; const StructID: IDentifier; const ADeleted: boolean);
begin
//
end;

{ TBuildCacheItem }

procedure TBuildCacheItem.Clear;
begin
  list.Clear;
end;

constructor TBuildCacheItem.Create;
begin
  pid := UndefiniteID;
  list := TCachePointList.Create;
end;

destructor TBuildCacheItem.Destroy;
begin
  list.Free;
  inherited;
end;

{ TBuildCache }

procedure TBuildCache.Clear;
var
  i: integer;
begin
  for i:=Count-1 downto 0 do
    TBuildCacheItem(Items[i]).Clear;
  inherited;
end;

function TBuildCache.FindId(id: IDentifier): pointer;
var
  i: integer;
begin
  Result := nil;
  for i:=0 to Count-1 do
    if TBuildCacheItem(Items[i]).pid=id then
    begin
      Result := Items[i];
      Break;
    end;
end;

procedure TBuildCache.Notify(Ptr: Pointer; Action: TListNotification);
begin
  if Action=lnDeleted then
    TBuildCacheItem(Ptr).Free;
end;

{ TCachePointList }

procedure TCachePointList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  if Action=lnDeleted then
    TBuildCachePoint(Ptr).Free;
end;

{ TBuildCachePoint }

constructor TBuildCachePoint.Create;
begin
  inherited;
  id := UndefiniteID;
  deleted := false;
end;

end.
