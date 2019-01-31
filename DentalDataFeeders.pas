unit DentalDataFeeders;

interface

uses
  DentalIntf, DB, pFIBDataSet, pFIBDatabase, uCommonDefinitions, Classes,
  WideStrings, Pfibquery;

type
  omStates = (omCreating, omIdle);
  TOnDestroyTransaction = procedure of object;
  TOnGetOwnerID = procedure (var AID: IDentifier) of object;
  TOnSetOwnerID = TOnGetOwnerID;

  ICompoPartDataFeederBridge = interface(IInterface)
  ['{8A3CDD5A-89B6-4EA9-BB94-44994ACDFD6A}']
    procedure SetGeneralTransaction(const Value: TpFIBTransaction);
    function GetGeneralTransaction: TpFIBTransaction;
    property GeneralTransaction: TpFIBTransaction read GetGeneralTransaction write SetGeneralTransaction;
  end;

  ICompoPartDataFeeder = interface(IInterface)
  ['{93A34536-0A5A-4110-94FB-FCEC33AF7FF4}']
    procedure CompoOpenEdit(var Aid: IDentifier; AProps: IProperties);
    procedure CompoOpenView(var Aid: IDentifier; AProps: IProperties);
    procedure CompoReadProps(var Aid: IDentifier; AProps: IProperties);
    procedure CompoSave(var Aid: IDentifier; AProps: IProperties);
    procedure CompoDelete(Aid: IDentifier; AProps: IProperties);
    procedure SetOnGetOwnerID(const Value: TOnGetOwnerID);
    function GetOnGetOwnerID: TOnGetOwnerID;
    property OnGetOwnerID: TOnGetOwnerID read GetOnGetOwnerID write SetOnGetOwnerID;
    procedure SetOnSetOwnerID(const Value: TOnSetOwnerID);
    function GetOnSetOwnerID: TOnSetOwnerID;
    property OnSetOwnerID: TOnSetOwnerID read GetOnSetOwnerID write SetOnSetOwnerID;
  end;

  ICompoExposedDataFeeder = interface(IInterface)
  ['{0E2E47F7-EA42-4A13-8139-1986DB331850}']
    function GetDataFeeder: IDataFeeder;
    property DataFeeder: IDataFeeder read GetDataFeeder;
  end;

  TBaseDataFeeder = class(TInterfacedObject, IDataFeeder)
  private
    procedure OnDestroyTransactionNative;
  protected
    FState: omStates;
    Fds: TpFIBDataSet;
    Ftr: TpFIBTransaction;
    FDbEventName: string;
    FOnDestroyTransaction: TOnDestroyTransaction;
    procedure OnCreateTransaction; virtual;
    procedure DoOnDestroyTransaction; virtual;
  protected
    {IDataFeeder}
    procedure ProcessDbEvent(EventName: string); virtual;
    procedure Init; virtual;
    function GetListSource: TDataSet; virtual;
  public
    { class methods }
    constructor Create;
    destructor Destroy; override;
  end;

  TListedDataFeeder = class(TBaseDataFeeder, IListDataFeeder)
  private
    FOnChangedCurrentID: TOnChangedCurrentID;
    procedure OnAfterScroll(DataSet: TDataSet);
    procedure DoChangeCurrentID;
    {function GetRecordID: IDentifier;}
  protected
    FIdField: string;
    function GetCurrentID: IDentifier;
    procedure SetCurrentID(Value: IDentifier);
    function GetOnChangedCurrentID: TOnChangedCurrentID;
    procedure SetOnChangedCurrentID(Value: TOnChangedCurrentID);
  protected
    { IDataFeeder }
    function GetListSource: TDataSet; override;
    { IListDataFeeder }
    property CurrentID: IDentifier read GetCurrentID write SetCurrentID;
    property OnChangedCurrentID: TOnChangedCurrentID read GetOnChangedCurrentID write SetOnChangedCurrentID;
    procedure PostInit;
  public
    { class methods }
    constructor Create;
    destructor Destroy; override;
  end;

  TRWDataFeeder = class(TBaseDataFeeder, IObjectDataFeeder)
  protected
    procedure RestartTrans(const params: string); virtual;
    procedure SoftCommit; virtual;
    procedure SoftRollback; virtual;
    procedure HardCommit; virtual;
    procedure HardRollback; virtual;
    procedure StartTransaction; virtual;
    procedure InternalOpenEdit(var Aid: IDentifier; AProps: IProperties); virtual; abstract;
    procedure InternalOpenView(var Aid: IDentifier; AProps: IProperties); virtual; abstract;
    procedure InternalReadProps(var Aid: IDentifier; AProps: IProperties); virtual; abstract;
    procedure InternalSave(var Aid: IDentifier; AProps: IProperties); virtual; abstract;
    procedure InternalDelete(Aid: IDentifier; AProps: IProperties); virtual; abstract;
  protected
    function Read(var Aid: IDentifier; AProps: IProperties; AOpenState: TOpenState; var AEditViewState: TEditViewState): dbopState;
    function Save(var Aid: IDentifier; AProps: IProperties): dbopState;
    function Delete(Aid: IDentifier; AProps: IProperties): dbopState;
  end;

  TCompoPartDataFeederRW = class(TRWDataFeeder, ICompoPartDataFeeder)
  protected
    FOnGetOwnerID: TOnGetOwnerID;
    FOnSetOwnerID: TOnSetOwnerID;
    procedure SetOnGetOwnerID(const Value: TOnGetOwnerID);
    function GetOnGetOwnerID: TOnGetOwnerID;
    procedure SetOnSetOwnerID(const Value: TOnSetOwnerID);
    function GetOnSetOwnerID: TOnSetOwnerID;
    procedure DoOnSetOwnerID(var AID: IDentifier);
    procedure DoOnGetOwnerID(var AID: IDentifier);
  protected
    procedure CompoOpenEdit(var Aid: IDentifier; AProps: IProperties); virtual;
    procedure CompoOpenView(var Aid: IDentifier; AProps: IProperties); virtual;
    procedure CompoReadProps(var Aid: IDentifier; AProps: IProperties); virtual;
    procedure CompoSave(var Aid: IDentifier; AProps: IProperties); virtual;
    procedure CompoDelete(Aid: IDentifier; AProps: IProperties); virtual;
    property OnSetOwnerID: TOnSetOwnerID read GetOnSetOwnerID write SetOnSetOwnerID;
    property OnGetOwnerID: TOnGetOwnerID read GetOnGetOwnerID write SetOnGetOwnerID;
  end;

  TCompositeDataFeeder = class(TRWDataFeeder, ICompositeDataFeeder)
  private
    FDFList: TInterfaceList;
  protected
    function GetDataFeeder(Idx: integer): IDataFeeder;
    function GetDataFeederCount: integer;
    procedure InternalOpenEdit(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalOpenView(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalReadProps(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalSave(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalDelete(Aid: IDentifier; AProps: IProperties); override;
  protected
    property DataFeeders[Idx: integer]: IDataFeeder read GetDataFeeder;
    function RegisterDataFeeder(DF: IDataFeeder): integer;
    property DataFeederCount: integer read GetDataFeederCount;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TMasterDrivenDataFeeder = class(TListedDataFeeder, IMasterDrivenDataFeeder)
  protected
    FMasterID: IDentifier;
    FForceSetMasterID: boolean;
    function GetMasterID: IDentifier;
    procedure SetMasterID(Value: IDentifier); virtual;
    procedure ReassignParams; virtual;
    procedure RecreateListSource;
  protected
    { IMasterDrivenDataFeeder }
    property MasterID: IDentifier read GetMasterID write SetMasterID;
  public
    { class methods }
    constructor Create;
    destructor Destroy; override;
  end;

  TdstrPair = class(TObject)
  public
    ds: TpFIBDataSet;
    tr: TpFIBTransaction;
    constructor Create;
    destructor Destroy; override;
  end;

  TqtrPair = class(TObject)
  public
    q: TpFIBQuery;
    tr: TpFIBTransaction;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  uDB, SysUtils, Variants, Dialogs, Fib, IB_ErrorCodes, uErrorLog, PFibProps, FIBDataSet;

{ TBaseDataFeeder }

constructor TBaseDataFeeder.Create;
begin
  inherited;
  FState := omCreating;
  Fds := dbmDental.CreateDS;
  FOnDestroyTransaction := OnDestroyTransactionNative;

  OnCreateTransaction;

  Fds.Transaction := Ftr;
  Fds.UpdateTransaction := Ftr;
end;

destructor TBaseDataFeeder.Destroy;
begin
  dbmDental.CloseDS(Fds);
//  if Assigned(Fds) then
//    FreeAndNil(Fds);

  DoOnDestroyTransaction;

  inherited;
end;

procedure TBaseDataFeeder.DoOnDestroyTransaction;
begin
  if Assigned(FOnDestroyTransaction) then
    FOnDestroyTransaction;
end;

function TBaseDataFeeder.GetListSource: TDataSet;
begin
  Result := Fds;
end;

procedure TBaseDataFeeder.Init;
begin
  FState := omIdle;
end;

procedure TBaseDataFeeder.OnCreateTransaction;
begin
  Ftr := dbmDental.CreateTr(trSingleLockTrans);
end;

procedure TBaseDataFeeder.OnDestroyTransactionNative;
begin
  if Assigned(Ftr) then
  begin
    if Ftr.InTransaction then
      Ftr.Rollback;
    dbmDental.CloseTR(Ftr);
//    FreeAndNil(Ftr);
  end;
end;

procedure TBaseDataFeeder.ProcessDbEvent(EventName: string);
begin
  if AnsiCompareText(EventName, FDbEventName)=0 then
  begin
    Fds.DisableControls;
    try
      Fds.DisableScrollEvents;
      try
        if (Fds.CacheModelOptions.CacheModelKind=cmkStandard)
           and (Fds.AutoUpdateOptions.KeyFields<>'')
        then
          Fds.ReopenLocate(Fds.AutoUpdateOptions.KeyFields)
        else
          Fds.FullRefresh;
        if Assigned(Fds.AfterScroll) then
          Fds.AfterScroll(Fds);
      finally
        Fds.EnableScrollEvents;
      end;
    finally
      Fds.EnableControls;
    end;
  end;
end;

{ TListedDataFeeder }

constructor TListedDataFeeder.Create;
begin
  inherited;
  Fds.AfterScroll := OnAfterScroll;
end;

destructor TListedDataFeeder.Destroy;
begin
  inherited;
end;

procedure TListedDataFeeder.DoChangeCurrentID;
begin
  if Assigned(FOnChangedCurrentID) then
    FOnChangedCurrentID(CurrentID);
end;

function TListedDataFeeder.GetCurrentID: IDentifier;
begin
  if Fds.Active then
  begin
    if not VarIsNull(Fds.FieldByName(FIdField).Value) then
      Result := Fds.FieldByName(FIdField).Value
    else
      Result := UndefiniteID;
  end
  else
    Result := UndefiniteID;
end;

function TListedDataFeeder.GetListSource: TDataSet;
begin
  Result := Fds;
end;

function TListedDataFeeder.GetOnChangedCurrentID: TOnChangedCurrentID;
begin
  Result := FOnChangedCurrentID;
end;
(*
function TListedDataFeeder.GetRecordID: IDentifier;
begin
  if Fds.Active then begin
    if not VarIsNull(Fds.FieldByName(FIdField).Value) then
      Result := Fds.FieldByName(FIdField).Value
    else
      Result := UndefiniteID;
  end else
    Result := UndefiniteID;
end;
*)
procedure TListedDataFeeder.OnAfterScroll(DataSet: TDataSet);
begin
  DoChangeCurrentID;
end;

procedure TListedDataFeeder.PostInit;
begin
  if Assigned(Fds.AfterScroll) then
    Fds.AfterScroll(Fds);
end;

procedure TListedDataFeeder.SetCurrentID(Value: IDentifier);
begin
  if FState<>omCreating then
    Fds.Locate(FIdField, Value, []);
end;

procedure TListedDataFeeder.SetOnChangedCurrentID(
  Value: TOnChangedCurrentID);
begin
  FOnChangedCurrentID := Value;
end;

{ TRWDataFeeder }

function TRWDataFeeder.Delete(Aid: IDentifier; AProps: IProperties): dbopState;
begin
  Result := dbopUndef;
  try
    StartTransaction;
    try
      InternalDelete(Aid, AProps);
      HardCommit;
      Result := dbopSucc;
    except
      on E:Exception do
      begin
       if Fds.State in [dsEdit, dsInsert] then
          Fds.Cancel;
        HardRollback;
        ErrorLog.AddToLog(E.Message);
        raise;
      end;
    end;
  except
    on E:EFIBInterBaseError do
    begin
      case E.IBErrorCode of
      isc_lock_conflict:
        Result := dbopLocked;
      end;
    end;
    on E:Exception do
      Result := dbopFailed;
  end;
end;

procedure TRWDataFeeder.HardCommit;
begin
  Ftr.Commit;
end;

procedure TRWDataFeeder.HardRollback;
begin
  Ftr.Rollback;
end;

function TRWDataFeeder.Read(var Aid: IDentifier; AProps: IProperties;
  AOpenState: TOpenState; var AEditViewState: TEditViewState): dbopState;
begin
  Result := dbopUndef;

  try
    if AOpenState in [osEditOnly, osEditOrView] then
    begin
      try
        RestartTrans(trSingleLockTrans);
        InternalOpenEdit(Aid, AProps);
        AEditViewState := evsEdit;
      except
        on E:EFIBInterBaseError do
        begin
          case E.IBErrorCode of
          isc_lock_conflict:
            if AOpenState=osEditOrView then
            begin
              RestartTrans(trSingleNoLockTrans);
              InternalOpenView(Aid, AProps);
              AEditViewState := evsView;
            end
            else
              Result := dbopLocked; (* 1 *)
          end;
        end;
        on E:Exception do
          raise;
      end;
    end
    else
    begin
      RestartTrans(trSingleNoLockTrans);
      InternalOpenView(Aid, AProps);
      AEditViewState := evsView;
    end;

    if Result<>dbopLocked then // если не попадали в точку (* 1 *)
    begin
      InternalReadProps(Aid, AProps);
      Result := dbopSucc;
    end;

  except
    on E:EFIBInterBaseError do
    begin
      case E.IBErrorCode of
      isc_lock_conflict:
        Result := dbopLocked;
      end;
    end;
    on E:Exception do
    begin
      ErrorLog.AddToLog(E.Message);
      Result := dbopFailed;
    end;
  end;
end;

procedure TRWDataFeeder.RestartTrans(const params: string);
begin
  if Fds.UpdateTransaction.Active then
    Fds.UpdateTransaction.Rollback;
  Fds.UpdateTransaction.TRParams.CommaText := params;
  Fds.UpdateTransaction.StartTransaction;
end;

function TRWDataFeeder.Save(var Aid: IDentifier;
  AProps: IProperties): dbopState;
begin
  Result := dbopUndef;

  try
    try
      InternalSave(Aid, AProps);
      SoftCommit;
      Result := dbopSucc;

    except
      on E:Exception do
      begin
        if Fds.State in [dsEdit, dsInsert] then
          Fds.Cancel;
        SoftRollback;
        ErrorLog.AddToLog(E.Message);
        raise;
      end;
    end;
  except
    on E:EFIBInterBaseError do
    begin
      case E.IBErrorCode of
      isc_lock_conflict:
        Result := dbopLocked;
      end;
    end;
    on E:Exception do
      Result := dbopFailed;
  end;
end;

procedure TRWDataFeeder.SoftCommit;
begin
  Fds.UpdateTransaction.CommitRetaining;
end;

procedure TRWDataFeeder.SoftRollback;
begin
  Fds.UpdateTransaction.RollbackRetaining;
end;

procedure TRWDataFeeder.StartTransaction;
begin
  Ftr.StartTransaction;
end;

{ TMasterDrivenDataFeeder }

constructor TMasterDrivenDataFeeder.Create;
begin
  inherited;
  FMasterID := UndefiniteID;
  FForceSetMasterID := False;
end;

destructor TMasterDrivenDataFeeder.Destroy;
begin
  inherited;
end;

function TMasterDrivenDataFeeder.GetMasterID: IDentifier;
begin
  Result := FMasterID;
end;

procedure TMasterDrivenDataFeeder.ReassignParams;
begin
  Fds.ParamByName('MasterID').Value := FMasterID;
end;

procedure TMasterDrivenDataFeeder.RecreateListSource;
begin
  Fds.DisableControls;
  try
    Fds.DisableScrollEvents;
    try
      Fds.Close;
      ReassignParams;
      Fds.Open;
      // “акое поведение Scroll'а нужно потому что
      // AfterScroll не происходит при пустом DataSet.
      // ј так - произойдЄт в любом случае.
      if Assigned(Fds.AfterScroll) then
        Fds.AfterScroll(Fds);
    finally
      Fds.EnableScrollEvents;
    end;
  finally
    Fds.EnableControls;
  end;
end;

procedure TMasterDrivenDataFeeder.SetMasterID(Value: IDentifier);
begin
  if FState<>omCreating then
    if (FMasterID<>Value) or FForceSetMasterID then
    begin
      FMasterID := Value;
      RecreateListSource;
    end;
end;

{ TCompositeDataFeeder }

constructor TCompositeDataFeeder.Create;
begin
  inherited;
  FDFList := TInterfaceList.Create;
end;

destructor TCompositeDataFeeder.Destroy;
begin
  if Assigned(FDFList) then
    FreeAndNil(FDFList);
  inherited;
end;

function TCompositeDataFeeder.GetDataFeeder(Idx: integer): IDataFeeder;
begin
  Result := FDFList.Items[Idx] as IDataFeeder;
end;

function TCompositeDataFeeder.GetDataFeederCount: integer;
begin
  Result := FDFList.Count;
end;

procedure TCompositeDataFeeder.InternalDelete(Aid: IDentifier; AProps: IProperties);
var
  i: integer;
begin
  for i:=0 to FDFList.Count-1 do
    (FDFList.Items[i] as ICompoPartDataFeeder).CompoDelete(Aid, AProps);
end;

procedure TCompositeDataFeeder.InternalOpenEdit(var Aid: IDentifier; AProps: IProperties);
var
  i: integer;
begin
  for i:=0 to FDFList.Count-1 do
    (FDFList.Items[i] as ICompoPartDataFeeder).CompoOpenEdit(Aid, AProps);
end;

procedure TCompositeDataFeeder.InternalOpenView(var Aid: IDentifier; AProps: IProperties);
var
  i: integer;
begin
  for i:=0 to FDFList.Count-1 do
    (FDFList.Items[i] as ICompoPartDataFeeder).CompoOpenView(Aid, AProps);
end;

procedure TCompositeDataFeeder.InternalReadProps(var Aid: IDentifier; AProps: IProperties);
var
  i: integer;
begin
  for i:=0 to FDFList.Count-1 do
    (FDFList.Items[i] as ICompoPartDataFeeder).CompoReadProps(Aid, AProps);
end;

procedure TCompositeDataFeeder.InternalSave(var Aid: IDentifier;
  AProps: IProperties);
var
  i: integer;
begin
  for i:=0 to FDFList.Count-1 do
    (FDFList.Items[i] as ICompoPartDataFeeder).CompoSave(Aid, AProps);
end;

function TCompositeDataFeeder.RegisterDataFeeder(DF: IDataFeeder): integer;
begin
  Result := FDFList.Add(DF);
end;

{ TCompoPartDataFeederRW }

procedure TCompoPartDataFeederRW.CompoDelete(Aid: IDentifier; AProps: IProperties);
var
  intID: IDentifier;
begin
  intID := Aid;
  DoOnGetOwnerID(intID);
  InternalDelete(intID, AProps);
  DoOnSetOwnerID(intID);
end;

procedure TCompoPartDataFeederRW.CompoOpenEdit(var Aid: IDentifier; AProps: IProperties);
var
  intID: IDentifier;
begin
  intID := Aid;
  DoOnGetOwnerID(intID);
  InternalOpenEdit(intID, AProps);
  DoOnSetOwnerID(intID);
end;

procedure TCompoPartDataFeederRW.CompoOpenView(var Aid: IDentifier; AProps: IProperties);
var
  intID: IDentifier;
begin
  intID := Aid;
  DoOnGetOwnerID(intID);
  InternalOpenView(intID, AProps);
  DoOnSetOwnerID(intID);
end;

procedure TCompoPartDataFeederRW.CompoReadProps(var Aid: IDentifier; AProps: IProperties);
var
  intID: IDentifier;
begin
  intID := Aid;
  DoOnGetOwnerID(intID);
  InternalReadProps(intID, AProps);
  DoOnSetOwnerID(intID);
end;

procedure TCompoPartDataFeederRW.CompoSave(var Aid: IDentifier; AProps: IProperties);
var
  intID: IDentifier;
begin
  intID := Aid;
  DoOnGetOwnerID(intID);
  InternalSave(intID, AProps);
  DoOnSetOwnerID(intID);
end;

procedure TCompoPartDataFeederRW.DoOnGetOwnerID(var AID: IDentifier);
begin
  if Assigned(FOnGetOwnerID) then
    FOnGetOwnerID(AID);
end;

procedure TCompoPartDataFeederRW.DoOnSetOwnerID(var AID: IDentifier);
begin
  if Assigned(FOnSetOwnerID) then
    FOnSetOwnerID(AID);
end;

function TCompoPartDataFeederRW.GetOnGetOwnerID: TOnGetOwnerID;
begin
  Result := FOnGetOwnerID;
end;

function TCompoPartDataFeederRW.GetOnSetOwnerID: TOnSetOwnerID;
begin
  Result := FOnSetOwnerID;
end;

procedure TCompoPartDataFeederRW.SetOnGetOwnerID(const Value: TOnGetOwnerID);
begin
  FOnGetOwnerID := Value;
end;

procedure TCompoPartDataFeederRW.SetOnSetOwnerID(const Value: TOnSetOwnerID);
begin
  FOnSetOwnerID := Value;
end;

{ TdstrPair }

constructor TdstrPair.Create;
begin
  inherited;
  tr := dbmDental.CreateTr;
  tr.StartTransaction;
  ds := dbmDental.CreateDS;
  ds.Transaction := tr;
  ds.UpdateTransaction := tr;
end;

destructor TdstrPair.Destroy;
begin
  if Assigned(ds) then
    dbmDental.CloseDS(ds);
  if Assigned(tr) then
    dbmDental.CloseTr(tr);
  inherited;
end;

{ TqtrPair }

constructor TqtrPair.Create;
begin
  inherited;
  tr := dbmDental.CreateTr;
  tr.StartTransaction;
  q := dbmDental.CreateQuery;
  q.Transaction := tr;
end;

destructor TqtrPair.Destroy;
begin
  if Assigned(q) then
    dbmDental.CloseQ(q);
  if Assigned(tr) then
    dbmDental.CloseTr(tr);
  inherited;
end;

end.

