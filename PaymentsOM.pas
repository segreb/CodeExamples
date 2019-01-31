unit PaymentsOM;

interface
uses
  DentalIntf, DentalObjectModels, uCommonDefinitions, DentalDataFeeders,
  Pfibdatabase, DiscardsOM, DB, Pfibdataset;

const
  dbevChangePayList = 'PAYLISTCHANGED';
  dbevChangePayments = 'PAYMENTSCHANGED';

const
  rmUndef    = 0;
  rmWorkDate = 1;
  rmUnpayed  = 2;
  rmUnpayedData = 3;
  rmUnpayedLast = 4;
  rm2Undef   = 0;
  rm2Current = 1;
  rm2All     = 2;
  
type
  TOnChangeWorkDate = procedure (const ADate: TDateType) of object;
  IWorkDateDrivenObject = interface(IInterface)
  ['{E66479B1-20A6-4EF8-AF9B-2F325738D629}']
    procedure SetWorkDate(const Value: TDateType);
    function GetWorkDate: TDateType;
    property WorkDate: TDateType read GetWorkDate write SetWorkDate;
    procedure SetOnChangeWorkDate(const Value: TOnChangeWorkDate);
    function GetOnChangeWorkDate: TOnChangeWorkDate;
    property OnChangeWorkDate: TOnChangeWorkDate read GetOnChangeWorkDate write SetOnChangeWorkDate;
  end;

  IUnpayedNarList = interface(IInterface)
  ['{5BF5272D-CF56-484E-9EE4-96ACF80002CC}']
    procedure SetUnpayedViewMode(const Value: integer);
    function GetUnpayedViewMode: integer;
    property UnpayedViewMode: integer read GetUnpayedViewMode write SetUnpayedViewMode;
    procedure SetShowUnpayedOnly(AValue: boolean);
    function GetShowDeactivated: boolean;
    procedure SetShowDeactivated(Value: boolean);
    property ShowDeactivated: boolean read GetShowDeactivated write SetShowDeactivated;
  end;

  IPaymentsListViewManager = interface(IInterface)
  ['{198FDEF8-EE07-4EB2-8249-3AF1A1ABD690}']
    procedure ShowAllPaymentsByDate;
    procedure ShowPaymentsByCurrent;
  end;

  IPaymentsDataFeeder = interface(IListDataFeeder)
  ['{74A7D584-115F-4CE8-A4FD-5782FA748F8B}']
    function GetCurrentPatID: IDentifier;
    property CurrentPatID: IDentifier read GetCurrentPatID;
    procedure MoveToNarid(ANarID: IDentifier);
    procedure ForceRefresh(Summa: currency);
  end;

  IPaymentsOM = interface(IListedOM)
  ['{958DBAC1-3154-4A1A-8509-DFE6BAA6F815}']
    procedure ReportCassaAll;
    procedure ReportCassaByCasser;
    procedure ReportCassaByUser;
    procedure ReportBankAll;
    procedure ReportNoPay;
    procedure CallDiscards;
    procedure CallDiscounts;
    procedure MoveToNarid(ANarID: IDentifier);
    procedure ReportInnerPays;
    procedure Refresh;
    procedure SetMasterSource(ADataSource: TDataSource);
  end;

  IChangePaymentNarad = interface(IInterface)
  ['{127C20CB-C7D8-48F7-B0C4-F10E6296AB68}']
    procedure ChangePaymentNarad;
  end;

  TOnSuccessPayment = procedure of object;
  TOnOperation = procedure (Summa: currency) of object;
  IPaymentsProcessor = interface(IInterface)
  ['{9264416C-C448-4C22-AFFB-46AE35A1BCF0}']
    procedure MakePayment(Summa: currency; PayDate: TDateType; Src: integer; SrcID: IDentifier; Direction: integer; Comment: widestring);
    procedure MakeStorn;
    procedure SetOnSuccessPayment(const Value: TOnSuccessPayment);
    function GetOnSuccessPayment: TOnSuccessPayment;
    property OnSuccessPayment: TOnSuccessPayment read GetOnSuccessPayment write SetOnSuccessPayment;
    procedure SetOnOperation(const Value: TOnOperation);
    function GetOnOperation: TOnOperation;
    property OnOperation: TOnOperation read GetOnOperation write SetOnOperation;
    function GetBankAccountsList: TDataSet;
    function GetCassesList: TDataSet;
    procedure MarkPrintedRRO;
  end;

  IInnPaymentsProcessor = interface(IInterface)
  ['{1195D8B4-332A-485A-B335-68615F754D9F}']
    procedure MakeInnPayment(Summa: currency; PayDate: TDateType; Direction: integer; Comment: widestring);
    procedure MakeInnStorn;
    procedure SetOnSuccessInnPayment(const Value: TOnSuccessPayment);
    function GetOnSuccessInnPayment: TOnSuccessPayment;
    property OnSuccessInnPayment: TOnSuccessPayment read GetOnSuccessInnPayment write SetOnSuccessInnPayment;
  end;

  IPaymentsListAncestor = interface(IListedOM)
  ['{AD9DFA42-1A98-421E-8182-024940599430}']
  end;

  IPaymentsListDataFeederAncestor = interface(IListDataFeeder)
  ['{79A81773-3C76-4FDE-B75A-606CDE494FC1}']
    function GetReportMode: integer;
    property ReportMode: integer read GetReportMode;
  end;

  IPaymentsList = interface(IPaymentsListAncestor)
  ['{E62CA6D1-70BE-4FB7-B075-7A9156E9DC7E}']
    function GetInnerListSource: TDataSet;
  end;

  IPaymentsListDataFeeder = interface(IListDataFeeder)
  ['{A600FA27-E591-4DEB-AE36-35CBF2401350}']
    function GetInnerListSource: TDataSet;
  end;

  TOnIndicate = procedure of object;
  IPaymentsIndicator = interface(IDataFeeder)
  ['{D3C5CEBE-B47B-4B3A-908B-1DF2BFF2C772}']
    function GetSummaPay: TPriceType;
    property SummaPay: TPriceType read GetSummaPay;
    function GetSummaPayEx: TPriceType;
    property SummaPayEx: TPriceType read GetSummaPayEx;
    function GetSummaPayAll: TPriceType;
    property SummaPayAll: TPriceType read GetSummaPayAll;
    function GetSummaPayAvans: TPriceType;
    property SummaPayAvans: TPriceType read GetSummaPayAvans;
    function GetOnIndicate: TOnIndicate;
    procedure SetOnIndicate(const Value: TOnIndicate);
    property OnIndicate: TOnIndicate read GetOnIndicate write SetOnIndicate;
    function GetIsOutOfPercentLimit: boolean;
    property IsOutOfPercentLimit: boolean read GetIsOutOfPercentLimit;
    function GetSummaNarlisted: TPriceType;
    property SummaNarlisted: TPriceType read GetSummaNarlisted;
    function GetSummaDebet: TPriceType;
    property SummaDebet: TPriceType read GetSummaDebet;
    function GetSummaBonus: TPriceType;
    property SummaBonus: TPriceType read GetSummaBonus;
    procedure SetMasterSource(ADataSource: TDataSource);
  end;

  TPaymentsOM = class(TListedOM, IPaymentsOM, IPaymentsList, IWorkDateDrivenObject, IPaymentsProcessor, IInnPaymentsProcessor,
                      IUnpayedNarList, IPaymentsIndicator, IChangePaymentNarad)
  private
    FPaymentsList: IPaymentsList;
    FPaymentsIndicator: IPaymentsIndicator;
    function GetWorkDateDrivenObject: IWorkDateDrivenObject;
  protected
    procedure InternalSetCurrentID(NewID: integer); override;
    function GetPaymentsProcessor: IPaymentsProcessor;
    function GetInnPaymentsProcessor: IInnPaymentsProcessor;
    procedure CreateDataFeeder; override;
    function GetUnpayedNarList: IUnpayedNarList;
    procedure SetWorkDate(const Value: TDateType);
    function GetWorkDate: TDateType;
    procedure SetOnChangeWorkDate(const Value: TOnChangeWorkDate);
    function GetOnChangeWorkDate: TOnChangeWorkDate;
    procedure OnOperation(Summa: currency);
    function GetChangePaymentNarad: IChangePaymentNarad;
  public
    property PaymentsList: IPaymentsList read FPaymentsList implements IPaymentsList;
    property PaymentsProcessor: IPaymentsProcessor read GetPaymentsProcessor implements IPaymentsProcessor;
    property InnPaymentsProcessor: IInnPaymentsProcessor read GetInnPaymentsProcessor implements IInnPaymentsProcessor;
    property UnpayedList: IUnpayedNarList read GetUnpayedNarList implements IUnpayedNarList;
    property ChangePaymentNarad: IChangePaymentNarad read GetChangePaymentNarad implements IChangePaymentNarad;
    property WorkDate: TDateType read GetWorkDate write SetWorkDate;
    property OnChangeWorkDate: TOnChangeWorkDate read GetOnChangeWorkDate write SetOnChangeWorkDate;
    procedure Init; override;
    procedure ProcessDbEvent(EventName: string); override;
    constructor Create;
    procedure ReportCassaAll;
    procedure ReportCassaByCasser;
    procedure ReportCassaByUser;
    procedure ReportBankAll;
    procedure ReportNoPay;
    procedure CallDiscards;
    procedure CallDiscounts;
    property PaymentsIndicator: IPaymentsIndicator read FPaymentsIndicator implements IPaymentsIndicator;
    procedure MoveToNarid(ANarID: IDentifier);
    procedure ReportInnerPays;
    procedure Refresh;
    procedure SetMasterSource(ADataSource: TDataSource);
  end;

  TPaymentsDataFeeder = class(TListedDataFeeder, IPaymentsDataFeeder, IWorkDateDrivenObject, IUnpayedNarList, IChangePaymentNarad)
  private
    FReportMode: integer;
    FWorkDate: TDateType;
    FOnChangeWorkDate: TOnChangeWorkDate;
    FShowUnpayedOnly: boolean;
    FShowDeactivated: boolean;
    FuTr: TpFIBTransaction;
    procedure SetWorkDate(const Value: TDateType);
    function GetWorkDate: TDateType;
    procedure SetOnChangeWorkDate(const Value: TOnChangeWorkDate);
    function GetOnChangeWorkDate: TOnChangeWorkDate;
    procedure SetSQLforDate;
    procedure SetSQLforUnPayed;
    procedure RecreateCurrentDateList;
    procedure ShowUnpayed;
    function GetCurrentPatID: IDentifier;
    procedure SetUnpayedViewMode(const Value: integer);
    function GetUnpayedViewMode: integer;
    procedure SetShowUnpayedOnly(AValue: boolean);
    function GetShowDeactivated: boolean;
    procedure SetShowDeactivated(Value: boolean);
  public
    property WorkDate: TDateType read GetWorkDate write SetWorkDate;
    property OnChangeWorkDate: TOnChangeWorkDate read GetOnChangeWorkDate write SetOnChangeWorkDate;
    property UnpayedViewMode: integer read GetUnpayedViewMode write SetUnpayedViewMode;
    property ShowDeactivated: boolean read GetShowDeactivated write SetShowDeactivated;
    property CurrentPatID: IDentifier read GetCurrentPatID;
    constructor Create;
    destructor Destroy; override;
    procedure MoveToNarid(ANarID: IDentifier);
    procedure ForceRefresh(Summa: currency);
    procedure ChangePaymentNarad;
  end;

  TPaymentsListAncestor = class(TMasteredOM, IPaymentsListAncestor, IPaymentsProcessor, IPaymentsListViewManager,
                                             IPaymentsListDataFeederAncestor)
  protected
    procedure CreateDataFeeder; override;
    function GetPaymentsProcessor: IPaymentsProcessor;
    function GetPaymentsListViewManager: IPaymentsListViewManager;
    function GetPaymentsListDataFeederAncestor: IPaymentsListDataFeederAncestor;
  public
    property PaymentsProcessor: IPaymentsProcessor read GetPaymentsProcessor implements IPaymentsProcessor;
    property PaymentsListViewManager: IPaymentsListViewManager read GetPaymentsListViewManager implements IPaymentsListViewManager;
    property PaymentsListDataFeederAncestor: IPaymentsListDataFeederAncestor read GetPaymentsListDataFeederAncestor implements IPaymentsListDataFeederAncestor;
  end;

  TPaymentsListDataFeederAncestor = class(TMasterDrivenDataFeeder, IPaymentsListDataFeederAncestor, IPaymentsProcessor,
                                                                   IPaymentsListViewManager)
  private
    FBankAccountsList: TpFIBDataSet;
    FCassesList: TpFIBDataSet;
  protected
    FReportMode: integer;
    FUpdTr: TpFIBTransaction;
    FOnSuccessPayment: TOnSuccessPayment;
    FOnOperation: TOnOperation;
    procedure SetOnSuccessPayment(const Value: TOnSuccessPayment);
    function GetOnSuccessPayment: TOnSuccessPayment;
    procedure DoOnSuccessPayment;
    function GetReportMode: integer;
    procedure DoOnOperation(Summa: currency);
    procedure SetOnOperation(const Value: TOnOperation);
    function GetOnOperation: TOnOperation;
    procedure SetSQLforCurrent;
    procedure SetSQLforAll;
    procedure RecreateListSource2;
    procedure OnRecreateListSource2; virtual; abstract;
    procedure OnSetSQLParamOwner; virtual; abstract;
    procedure SetMasterID(Value: IDentifier); override;
    procedure OnCreate; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    { IPaymentsProcessor }
    procedure MakePayment(Summa: currency; PayDate: TDateType; Src: integer; SrcID: IDentifier; Direction: integer; Comment: widestring);
    procedure MakeStorn;
    property OnSuccessPayment: TOnSuccessPayment read GetOnSuccessPayment write SetOnSuccessPayment;
    property OnOnOperation: TOnOperation read GetOnOperation write SetOnOperation;
    function GetBankAccountsList: TDataSet;
    function GetCassesList: TDataSet;
    procedure MarkPrintedRRO;
    { IPaymentsListDataFeederAncestor }
    property ReportMode: integer read GetReportMode;
    { IPaymentsListViewManager }
    procedure ShowAllPaymentsByDate;
    procedure ShowPaymentsByCurrent;
    { IDataFeeder }
    procedure ProcessDbEvent(EventName: string); override;
  end;

  {  }
  TPaymentsList = class(TPaymentsListAncestor, IPaymentsList, IInnPaymentsProcessor, IWorkDateDrivenObject,
                                               IPaymentsListDataFeeder)
  protected
    procedure CreateDataFeeder; override;
    function GetWorkDateDrivenObject: IWorkDateDrivenObject;
    function GetPaymentsListDataFeeder: IPaymentsListDataFeeder;
    function GetInnPaymentsProcessor: IInnPaymentsProcessor;
  public
    { IPaymentsList }
    constructor Create;
    property WorkDateDrivenObject: IWorkDateDrivenObject read GetWorkDateDrivenObject implements IWorkDateDrivenObject;
    function GetInnerListSource: TDataSet;
    property PaymentsListDataFeeder: IPaymentsListDataFeeder read GetPaymentsListDataFeeder implements IPaymentsListDataFeeder;
    { IInnPaymentsProcessor }
    property InnPaymentsProcessor: IInnPaymentsProcessor read GetInnPaymentsProcessor implements IInnPaymentsProcessor;
  end;

  TPaymentsListDataFeeder = class(TPaymentsListDataFeederAncestor, IListDataFeeder, IPaymentsListDataFeeder,
                                  IInnPaymentsProcessor, IWorkDateDrivenObject)
  protected
    FWorkDate: TDateType;
    FOnChangeWorkDate: TOnChangeWorkDate;
    FInnerPay: TpFibDataSet;
    FOnSuccessInnPayment: TOnSuccessPayment;
    procedure DoOnSuccessInnPayment;
    procedure SetWorkDate(const Value: TDateType);
    function GetWorkDate: TDateType;
    procedure SetOnChangeWorkDate(const Value: TOnChangeWorkDate);
    function GetOnChangeWorkDate: TOnChangeWorkDate;
    procedure RecreateInnerPaymentsList;
    procedure SetOnSuccessInnPayment(const Value: TOnSuccessPayment);
    function GetOnSuccessInnPayment: TOnSuccessPayment;
  protected  
    procedure OnRecreateListSource2; override;
    procedure OnSetSQLParamOwner; override;
    procedure OnCreate; override;
  public
    constructor Create;
    destructor Destroy; override;
    { IWorkDateDrivenObject }
    property WorkDate: TDateType read GetWorkDate write SetWorkDate;
    property OnChangeWorkDate: TOnChangeWorkDate read GetOnChangeWorkDate write SetOnChangeWorkDate;
    { IInnPaymentsProcessor }
    procedure MakeInnPayment(Summa: currency; PayDate: TDateType; Direction: integer; Comment: widestring);
    procedure MakeInnStorn;
    property OnSuccessInnPayment: TOnSuccessPayment read GetOnSuccessInnPayment write SetOnSuccessInnPayment;
    { IPaymentsListDataFeeder }
    function GetInnerListSource: TDataSet;
  end;

  TIPaymentsIndicator = class(TBaseDataFeeder, IPaymentsIndicator)
  protected
    FOnIndicate: TOnIndicate;
    function GetSummaPay: TPriceType;
    function GetSummaPayEx: TPriceType;
    function GetSummaPayAll: TPriceType;
    function GetSummaPayAvans: TPriceType;
    function GetOnIndicate: TOnIndicate;
    procedure SetOnIndicate(const Value: TOnIndicate);
    procedure OnCreateTransaction; override;
    function GetIsOutOfPercentLimit: boolean;
    function GetSummaNarlisted: TPriceType;
    function GetSummaDebet: TPriceType;
    function GetSummaBonus: TPriceType;
    procedure OnAfterOpen(Sender: TDataSet);
  public
    property SummaPay: TPriceType read GetSummaPay;
    property SummaPayEx: TPriceType read GetSummaPayEx;
    property SummaPayAll: TPriceType read GetSummaPayAll;
    property SummaPayAvans: TPriceType read GetSummaPayAvans;
    property SummaNarlisted: TPriceType read GetSummaNarlisted;
    property SummaDebet: TPriceType read GetSummaDebet;
    property SummaBonus: TPriceType read GetSummaBonus;
    property OnIndicate: TOnIndicate read GetOnIndicate write SetOnIndicate;
    property IsOutOfPercentLimit: boolean read GetIsOutOfPercentLimit;
    procedure SetMasterSource(ADataSource: TDataSource);
    procedure ProcessDbEvent(EventName: string); override;
    constructor Create;
    destructor Destroy; override;
  end;

  IPaymentNarChanger = interface(IListedObject)
  ['{45DB2B3A-B95D-4741-A881-AA3CC23E68BC}']
  end;

  IPaymentNarChangerProperties = interface(IProperties)
  ['{51A8C2D9-89FE-426A-945D-0553E29B14E5}']
    procedure SetNewNarID(const Value: IDentifier);
    function GetNewNarID: IDentifier;
    property NewNarID: IDentifier read GetNewNarID write SetNewNarID;
    procedure SetNewComment;
    function GetNewComment: widestring;
    property NewComment: widestring read GetNewComment;
    function GetMovedSumm: TPriceType;
    procedure SetMovedSumm(const Value: TPriceType);
    property MovedSumm: TPriceType read GetMovedSumm write SetMovedSumm;
    function GetBonusSumm: TPriceType;
    procedure SetBonusSumm(const Value: TPriceType);
    property BonusSumm: TPriceType read GetBonusSumm write SetBonusSumm;
  end;

  IPaymentNarChangerDataFeeder = interface(IObjectDataFeeder)
  ['{947C3D3F-B7EC-4B95-A294-3E50C8E1CA57}']
  end;

  TPaymentNarChangerProperties = class(TInterfacedObject, IPaymentNarChangerProperties, IProperties)
  protected
    FNewNarID: IDentifier;
    FNewComment: widestring;
    FMovedSumm: TPriceType;
    FBonusSumm: TPriceType;
    procedure SetNewNarID(const Value: IDentifier);
    function GetNewNarID: IDentifier;
    procedure SetNewComment;
    function GetNewComment: widestring;
    function GetMovedSumm: TPriceType;
    procedure SetMovedSumm(const Value: TPriceType);
    function GetBonusSumm: TPriceType;
    procedure SetBonusSumm(const Value: TPriceType);
  public
    property NewNarID: IDentifier read GetNewNarID write SetNewNarID;
    property NewComment: widestring read GetNewComment;
    property MovedSumm: TPriceType read GetMovedSumm write SetMovedSumm;
    property BonusSumm: TPriceType read GetBonusSumm write SetBonusSumm;
    constructor Create;
    function Clone: IProperties;
  end;

  TPaymentNarChangerDataFeeder = class(TRWDataFeeder, IPaymentNarChangerDataFeeder)
  protected
    procedure InternalOpenEdit(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalOpenView(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalReadProps(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalSave(var Aid: IDentifier; AProps: IProperties); override;
    procedure InternalDelete(Aid: IDentifier; AProps: IProperties); override;
  public
    constructor Create;
  end;

  TPaymentNarChanger = class(TListedObject, IPaymentNarChanger)
  protected
    procedure CreateDataFeeder; override;
    procedure CreateProperties; override;
  public
    procedure EditProps; override;
  end;

implementation

uses
  DentalDateUtils, SysUtils, uDB, GlobalObjectIntf, Pfibprops,
  Variants, uErrorLog, Fib, IB_errorcodes, Dialogs, Controls, Fibdataset,
  uStdReports, ServiceDialogs, SrvcPatDiscards, DiscountsOM, uKvitsImpl,
  SrvcPayChangeNarad, PriceOM, Forms;

{ TPaymentsOM }

procedure TPaymentsOM.CallDiscards;
var
  f: TfrmPatDiscards;
begin
  if IsRecordPointed then
  begin
    f := TfrmPatDiscards.Create(Application);
    try
      f.SetExternalMasterID((FDataFeeder as IPaymentsDataFeeder).CurrentPatID);
      f.ShowModal;
    finally
      f.Free;
    end;
  end;
end;

procedure TPaymentsOM.CallDiscounts;
var
  dm: IListedObject;
begin
  if not GlobalObj.LoginedUser.CheckAccess(sctDiscounts) then
    Exit;

  dm := TKvitFasadeForDiscount.Create;
  try
    dm.ID := FCurrentID;
    dm.Edit(osEditOnly);
    ProcessDbEvent(dbevChangePayList);
    ProcessDbEvent(dbevChangePayments);
  finally
    dm := nil;
  end;
end;

constructor TPaymentsOM.Create;
begin
  inherited;
  FPaymentsList := TPaymentsList.Create;
  FDbEventName := dbevChangePayList;
  FPaymentsIndicator := TIPaymentsIndicator.Create;
  PaymentsProcessor.OnOperation := OnOperation;
end;

procedure TPaymentsOM.CreateDataFeeder;
begin
  FDataFeeder := TPaymentsDataFeeder.Create;
end;

function TPaymentsOM.GetChangePaymentNarad: IChangePaymentNarad;
begin
  Result := FDataFeeder as IChangePaymentNarad;
end;

function TPaymentsOM.GetInnPaymentsProcessor: IInnPaymentsProcessor;
begin
  Result := FPaymentsList as IInnPaymentsProcessor;
end;

function TPaymentsOM.GetOnChangeWorkDate: TOnChangeWorkDate;
begin
  Result := (FDataFeeder as IWorkDateDrivenObject).OnChangeWorkDate;
end;

function TPaymentsOM.GetPaymentsProcessor: IPaymentsProcessor;
begin
  Result := FPaymentsList as IPaymentsProcessor;
end;

function TPaymentsOM.GetUnpayedNarList: IUnpayedNarList;
begin
  Result := FDataFeeder as IUnpayedNarList;
end;

function TPaymentsOM.GetWorkDate: TDateType;
begin
  Result := (FDataFeeder as IWorkDateDrivenObject).WorkDate;
end;

function TPaymentsOM.GetWorkDateDrivenObject: IWorkDateDrivenObject;
begin
  Result := FDataFeeder as IWorkDateDrivenObject;
end;

procedure TPaymentsOM.Init;
begin
  FPaymentsList.Init;
  FPaymentsIndicator.Init;
  inherited;
  WorkDate := Date;
end;

procedure TPaymentsOM.InternalSetCurrentID(NewID: integer);
begin
  inherited;
  //FPaymentsIndicator.OnIndicate;
  (FPaymentsList as IMasterDrivenList).MasterID := NewID;
end;

procedure TPaymentsOM.MoveToNarid(ANarID: IDentifier);
begin
  (FDataFeeder as IPaymentsDataFeeder).MoveToNarid(ANarID);
end;

procedure TPaymentsOM.OnOperation(Summa: currency);
begin
  (FDataFeeder as IPaymentsDataFeeder).ForceRefresh(Summa);
end;

procedure TPaymentsOM.ProcessDbEvent(EventName: string);
begin
  FPaymentsList.ProcessDbEvent(EventName);
  FPaymentsIndicator.ProcessDbEvent(EventName);
  inherited;
end;

procedure TPaymentsOM.Refresh;
begin
  FPaymentsList.ProcessDbEvent(dbevChangePayments);
  FPaymentsIndicator.ProcessDbEvent(dbevChangePayments);
end;

procedure TPaymentsOM.ReportBankAll;
var
  report: IReport;
begin
  report := CreateBankReportAll;
  if report.AskPeriod then
    report.Execute;
end;

procedure TPaymentsOM.ReportCassaAll;
var
  report: IReport;
begin
  report := CreateCassReportAllFrx;
  (report.Properties as ICassReportProperties).ReportTitle := 'Отчёт по кассе';
  if report.AskPeriod then
    report.Execute;
end;

procedure TPaymentsOM.ReportCassaByCasser;
var
  report: IReport;
begin
  report := CreateCassReportByCasser;
  if report.AskPeriod then
    report.Execute;
end;

procedure TPaymentsOM.ReportCassaByUser;
var
  report: IReport;
begin
  report := CreateCassReportByUser;
  if report.AskPeriod then
    report.Execute;
end;

procedure TPaymentsOM.ReportInnerPays;
var
  report: IReport;
begin
  report := CreateReportInnerPay;
  if report.AskPeriod then
    report.Execute;
end;

procedure TPaymentsOM.ReportNoPay;
var
  report: IReport;
begin
  report := TReportNoPayFrx.Create;
  if report.AskPeriod then
    report.Execute;
end;

procedure TPaymentsOM.SetMasterSource(ADataSource: TDataSource);
begin
  FPaymentsIndicator.SetMasterSource(ADataSource);
end;

procedure TPaymentsOM.SetOnChangeWorkDate(const Value: TOnChangeWorkDate);
begin
  (FDataFeeder as IWorkDateDrivenObject).OnChangeWorkDate := Value;
end;

procedure TPaymentsOM.SetWorkDate(const Value: TDateType);
begin
  (FDataFeeder as IWorkDateDrivenObject).WorkDate := Value;
  (FPaymentsList as IWorkDateDrivenObject).WorkDate := Value;
end;

{ TPaymentsListDataFeeder }

constructor TPaymentsListDataFeeder.Create;
begin
  inherited;
  Fds.PrepareOptions := Fds.PrepareOptions - [psAskRecordCount];
end;

destructor TPaymentsListDataFeeder.Destroy;
begin
  if Assigned(FInnerPay) then
    dbmDental.CloseDS(FInnerPay);
  inherited;
end;

function TPaymentsListDataFeeder.GetOnChangeWorkDate: TOnChangeWorkDate;
begin
  Result := FOnChangeWorkDate;
end;

function TPaymentsListDataFeeder.GetWorkDate: TDateType;
begin
  Result := FWorkDate;
end;

procedure TPaymentsListDataFeeder.SetOnChangeWorkDate(const Value: TOnChangeWorkDate);
begin
  FOnChangeWorkDate := Value;
end;

procedure TPaymentsListDataFeeder.SetWorkDate(const Value: TDateType);
begin
  if FState<>omCreating then
    if (FWorkDate<>Value) then
    begin
      FWorkDate := Value;

      if FReportMode=rm2All then
        RecreateListSource2;

      RecreateInnerPaymentsList;

      if Assigned(FOnChangeWorkDate) then
        FOnChangeWorkDate(FWorkDate);
    end;
end;

function TPaymentsListDataFeeder.GetInnerListSource: TDataSet;
begin
  Result := FInnerPay;
end;

procedure TPaymentsListDataFeeder.RecreateInnerPaymentsList;
begin
  FInnerPay.Close;
  FInnerPay.ParamByName('pdate').AsDate := DateTypeToFieldValue(FWorkDate);
  FInnerPay.Open;
end;

function TPaymentsListDataFeeder.GetOnSuccessInnPayment: TOnSuccessPayment;
begin
  Result := FOnSuccessInnPayment;
end;

procedure TPaymentsListDataFeeder.MakeInnPayment(Summa: currency;
  PayDate: TDateType; Direction: integer; Comment: widestring);
var
  mr: integer;
begin
  if (Trunc(PayDate) <> CurrentDate())
     and (GlobalObj.GlobalOptions.OptionDef[_RestrictBackCass, _Def_RestrictBackCass])
     and (not GlobalObj.LoginedUser.CheckAccess(sctManagement)) then
  begin
    ErrorLog.AddToLog('Запрещено выполнять кассовые операции "задним числом"');
    Exit;
  end;

  if PayDate<>Date() then
    mr := AskDialog2('Операция проводится не сегодняшним числом. Продолжать?')
  else
    mr := mrYes;

  if mr=mrYes then
  begin
    FInnerPay.UpdateTransaction.StartTransaction;
    try
      FInnerPay.Append;
      FInnerPay.FieldByName('UserID').Value := GlobalObj.LoginedUser.UserID;
      FInnerPay.FieldByName('PayDate').Value := DateTypeToFieldValue(PayDate);
      FInnerPay.FieldByName('Summa').Value := Summa;
      FInnerPay.FieldByName('PayDirection').Value := Direction;
      FInnerPay.FieldByName('Storned').Value := False;
      FInnerPay.FieldByName('Comment').Value := Comment;
      FInnerPay.FieldByName('CassaID').Value := GlobalObj.LoginedUser.CassaID;
      FInnerPay.Post;
      DoOnSuccessInnPayment;

      FInnerPay.UpdateTransaction.Commit;
    except
      on E:Exception do
      begin
        if FInnerPay.State in [dsEdit, dsInsert] then
          FInnerPay.Cancel;
        FInnerPay.UpdateTransaction.Rollback;
      end;
    end;
  end;
end;

procedure TPaymentsListDataFeeder.MakeInnStorn;
begin
  if (Trunc(FieldValueToDateType(FInnerPay.FieldByName('PayDate').Value)) <> CurrentDate())
     and (GlobalObj.GlobalOptions.OptionDef[_RestrictBackCass, _Def_RestrictBackCass])
     and (not GlobalObj.LoginedUser.CheckAccess(sctManagement)) then
  begin
    ErrorLog.AddToLog('Запрещено выполнять кассовые операции "задним числом"');
    Exit;
  end;

  if MessageDlg('Провести отмену операции?', mtConfirmation, [mbYes, mbNo], 0)=mrYes then
  begin
    FInnerPay.UpdateTransaction.StartTransaction;
    try
      FInnerPay.Edit;
      FInnerPay.FieldByName('Storned').Value := True;
      FInnerPay.Post;
      FInnerPay.UpdateTransaction.Commit;
    except
      on E:Exception do
      begin
        if FInnerPay.State in [dsEdit, dsInsert] then
          FInnerPay.Cancel;
        if E is EFIBInterBaseError then
        begin
          if EFIBInterBaseError(E).IBErrorCode=isc_lock_conflict then
            ErrorLog.AddToLog('Запись кем-то редактируется. Попробуйте позже');
        end
        else
          ErrorLog.AddToLog(E.Message);
        FInnerPay.UpdateTransaction.Rollback;
      end;
    end;
  end;
end;

procedure TPaymentsListDataFeeder.SetOnSuccessInnPayment(const Value: TOnSuccessPayment);
begin
  FOnSuccessInnPayment := Value;
end;

procedure TPaymentsListDataFeeder.DoOnSuccessInnPayment;
begin
  if Assigned(FOnSuccessInnPayment) then
    FOnSuccessInnPayment;
end;

procedure TPaymentsListDataFeeder.OnCreate;
begin
  FInnerPay := dbmDental.CreateDS;
  FInnerPay.PrepareOptions := FInnerPay.PrepareOptions - [psAskRecordCount];
  FInnerPay.Transaction := Fds.Transaction;
  FInnerPay.UpdateTransaction := FUpdTr;
  FInnerPay.AutoUpdateOptions.KeyFields := 'PAYID';
  FInnerPay.AutoUpdateOptions.UpdateTableName := 'INNERPAYMENTS';
  FInnerPay.RefreshTransactionKind := tkUpdateTransaction;
  FInnerPay.Options := FInnerPay.Options + [poKeepSorting, poPersistentSorting];
  FInnerPay.SQLs.SelectSQL.Text :=
    'SELECT PayID, PayDate, Summa, InnerPayments.UserID, PayDirection, Storned, '+
           'Users.USecondName, Users.UFirstName, Users.USurName, Comment, CassaID '+
    'FROM InnerPayments '+
    'LEFT JOIN Users ON InnerPayments.UserID=Users.UserID '+
    'left join securityrights on securityrights.objectid=users.userid and securityrights.securitytoken=:sctReception '+
    'WHERE PayDate=:pdate and @whsec '+
    'ORDER BY PayID';
  if GlobalObj.GlobalOptions[_ShowInnerPayOwner, _Def_ShowInnerPayOwner] and
     GlobalObj.LoginedUser.CheckAccess(sctReception) and
     not GlobalObj.LoginedUser.CheckAccess(sctManagement) and
     not GlobalObj.LoginedUser.CheckAccess(sctSuperUser)
  then
    FInnerPay.ParamByName('whsec').Value := 'securitytoken=:sctReception'
  else begin
    FInnerPay.ParamByName('whsec').Value := '1=1';
  end;
  FInnerPay.ParamByName('sctReception').Value := sctReception;
end;

procedure TPaymentsListDataFeeder.OnRecreateListSource2;
begin
  Fds.ParamByName('whPayDate').Value := '(PayDate=:pdate)';
//  Fds.Prepare;
  Fds.ParamByName('pdate').AsDate := DateTypeToFieldValue(FWorkDate);
end;

procedure TPaymentsListDataFeeder.OnSetSQLParamOwner;
begin
  Fds.ParamByName('whOwner').Value := '(patients.patid is not null)';
end;

{ TPaymentsListAncestor }

function TPaymentsListAncestor.GetPaymentsProcessor: IPaymentsProcessor;
begin
  Result := FDataFeeder as IPaymentsProcessor;
end;

procedure TPaymentsListAncestor.CreateDataFeeder;
begin
  FDataFeeder := TPaymentsListDataFeederAncestor.Create;
end;

function TPaymentsListAncestor.GetPaymentsListDataFeederAncestor: IPaymentsListDataFeederAncestor;
begin
  Result := FDataFeeder as IPaymentsListDataFeederAncestor;
end;

function TPaymentsListAncestor.GetPaymentsListViewManager: IPaymentsListViewManager;
begin
  Result := FDataFeeder as IPaymentsListViewManager;
end;

{ TPaymentsListDataFeederAncestor }

constructor TPaymentsListDataFeederAncestor.Create;
var
  SQLWhereCassa: string;
begin
  inherited;
  FReportMode := rm2Undef;
  FDbEventName := dbevChangePayments;
  FIdField := 'PAYID';
  FUpdTr := dbmDental.CreateTr(trSimpleWrite);

  Fds.UpdateTransaction := FUpdTr;
  Fds.AutoUpdateOptions.KeyFields := 'PAYID';
  Fds.AutoUpdateOptions.UpdateTableName := 'PAYMENTS';
  Fds.RefreshTransactionKind := tkUpdateTransaction;
  Fds.Options := Fds.Options + [poKeepSorting, poPersistentSorting];

  OnCreate;

  FBankAccountsList := dbmDental.CreateDS;
  FBankAccountsList.Transaction := Ftr;
  FBankAccountsList.UpdateTransaction := Ftr;
  FBankAccountsList.SelectSQL.Text := 'select * from BankAccounts order by BankAccountName';

  FCassesList := dbmDental.CreateDS;
  FCassesList.Transaction := Ftr;
  FCassesList.UpdateTransaction := Ftr;
  SQLWhereCassa := '';
  if GlobalObj.LoginedUser.CassaID<>UndefiniteID then begin
    if GlobalObj.LoginedUser.CheckAccess(sctViewAllCasses, false) then begin
      SQLWhereCassa := '';
    end else begin
      SQLWhereCassa := 'where CassaID='+IntToStr(GlobalObj.LoginedUser.CassaID);
    end;
  end else begin
    SQLWhereCassa := 'where 1=0';
  end;

  FCassesList.SelectSQL.Text := Format('select * from Casses %s order by CassaName', [SQLWhereCassa]);

  Ftr.StartTransaction;
//  FUpdTr.StartTransaction;
  SetSQLforCurrent;
  FBankAccountsList.Open;
  FCassesList.Open;
end;

destructor TPaymentsListDataFeederAncestor.Destroy;
begin
  if Assigned(FBankAccountsList) then
    dbmDental.CloseDS(FBankAccountsList);
  if Assigned(FCassesList) then
    dbmDental.CloseDS(FCassesList);
  if Assigned(FUpdTr) then
    dbmDental.CloseTR(FUpdTr);
  inherited;
end;

procedure TPaymentsListDataFeederAncestor.SetOnSuccessPayment(const Value: TOnSuccessPayment);
begin
  FOnSuccessPayment := Value;
end;

function TPaymentsListDataFeederAncestor.GetOnSuccessPayment: TOnSuccessPayment;
begin
  Result := FOnSuccessPayment;
end;

procedure TPaymentsListDataFeederAncestor.DoOnSuccessPayment;
begin
  if Assigned(FOnSuccessPayment) then
    FOnSuccessPayment;
end;

function TPaymentsListDataFeederAncestor.GetReportMode: integer;
begin
  Result := FReportMode;
end;

procedure TPaymentsListDataFeederAncestor.MakePayment(Summa: currency; PayDate: TDateType;
  Src: integer; SrcID: IDentifier; Direction: integer; Comment: widestring);
var
  ds: TpFIBDataSet;
  mr: integer;
begin
  if PayDate<>Date() then
    mr := AskDialog2('Операция проводится не сегодняшним числом. Продолжать?')
  else
    mr := mrYes;

  if mr=mrYes then
  begin
    ds := dbmDental.CreateDS;
    try
      Fds.UpdateTransaction.StartTransaction;
      try
        ds.PrepareOptions := ds.PrepareOptions - [psAskRecordCount];
        ds.Transaction := Fds.UpdateTransaction;
        ds.SelectSQL.Text :=
          'SELECT * FROM NarList WHERE (NarID=:narid) and (NarList.deleted=:deleted) FOR UPDATE WITH LOCK';
        ds.ParamByName('narid').Value := FMasterID;
        ds.ParamByName('deleted').Value := False;
        ds.Open;

        ds.First;
        if not (VarIsNull(ds.FieldByName('NarID').Value) or VarIsEmpty(ds.FieldByName('NarID').Value)) then
        begin
          Fds.Append;
          Fds.FieldByName('NarID').Value := ds.FieldByName('NarID').Value;
          Fds.FieldByName('PatID').Value := ds.FieldByName('PatID').Value;
          Fds.FieldByName('UserID').Value := GlobalObj.LoginedUser.UserID;
          Fds.FieldByName('PayDate').Value := DateTypeToFieldValue(PayDate);
          Fds.FieldByName('Summa').Value := Summa;
          Fds.FieldByName('PayDirection').Value := Direction;
          Fds.FieldByName('PaySource').Value := Src;
          Fds.FieldByName('Storned').Value := False;
          Fds.FieldByName('CassaID').Value := SrcID;
          Fds.FieldByName('Comment').Value := Comment;
          Fds.Post;
          DoOnSuccessPayment;
        end
        else
          ErrorLog.AddToLog('Наряд для оплаты не обнаружен');

        Fds.UpdateTransaction.Commit;
        // 2008.12.11. Именно здесь, после транзакции
        DoOnOperation(Summa);
      except
        on E:Exception do
        begin
          if Fds.State in [dsEdit, dsInsert] then
            Fds.Cancel;
          if E is EFIBInterBaseError then
          begin
            if EFIBInterBaseError(E).IBErrorCode=isc_lock_conflict then
              ErrorLog.AddToLog('Наряд кем-то редактируется. Попробуйте позже');
          end
          else
            ErrorLog.AddToLog(E.Message);
          Fds.UpdateTransaction.Rollback;
        end;
      end;
    finally
      dbmDental.CloseDS(ds);
    end;
  end;
end;

procedure TPaymentsListDataFeederAncestor.MakeStorn;
begin
  if (Trunc(FieldValueToDateType(Fds.FieldByName('PayDate').Value)) <> CurrentDate())
     and (GlobalObj.GlobalOptions.OptionDef[_RestrictBackCass, _Def_RestrictBackCass])
     and (not GlobalObj.LoginedUser.CheckAccess(sctManagement)) then
  begin
    ErrorLog.AddToLog('Запрещено выполнять кассовые операции "задним числом"');
  end else
    if MessageDlg('Провести отмену операции?', mtConfirmation, [mbYes, mbNo], 0)=mrYes then
    begin
      Fds.UpdateTransaction.StartTransaction;
      try
        Fds.Edit;
        Fds.FieldByName('Storned').Value := True;
        Fds.Post;
        Fds.UpdateTransaction.Commit;
        DoOnSuccessPayment;
        // 2008.12.15. А это здесь не нужно. При сторнировании не нужно передёргивать список нарядов
        // 2011.04.06. Тперь нужно. Передёргивать PayedSumm
        DoOnOperation(0);
      except
        on E:Exception do
        begin
          if Fds.State in [dsEdit, dsInsert] then
            Fds.Cancel;
          if E is EFIBInterBaseError then
          begin
            if EFIBInterBaseError(E).IBErrorCode=isc_lock_conflict then
              ErrorLog.AddToLog('Запись кем-то редактируется. Попробуйте позже');
          end
          else
            ErrorLog.AddToLog(E.Message);
          Fds.UpdateTransaction.Rollback;
        end;
      end;
    end;
end;

procedure TPaymentsListDataFeederAncestor.MarkPrintedRRO;
begin
  try
    Fds.UpdateTransaction.StartTransaction;
    Fds.Edit;
    Fds.FieldByName('PrintedRRO').Value := True;
    Fds.Post;
    Fds.UpdateTransaction.Commit;
  except
    on E:Exception do
    begin
      if Fds.State in [dsEdit, dsInsert] then
        Fds.Cancel;
      if E is EFIBInterBaseError then
      begin
        if EFIBInterBaseError(E).IBErrorCode=isc_lock_conflict then
          ErrorLog.AddToLog('Запись кем-то редактируется. Помните, что чек по этой оплате уже напечатан');
      end
      else
        ErrorLog.AddToLog(E.Message);
      Fds.UpdateTransaction.Rollback;
    end;
  end;
end;

procedure TPaymentsListDataFeederAncestor.OnCreate;
begin
//
end;

procedure TPaymentsListDataFeederAncestor.DoOnOperation(Summa: currency);
begin
  if Assigned(FOnOperation) then
    FOnOperation(Summa);
end;

function TPaymentsListDataFeederAncestor.GetBankAccountsList: TDataSet;
begin
  Result := FBankAccountsList;
end;

function TPaymentsListDataFeederAncestor.GetCassesList: TDataSet;
begin
  Result := FCassesList;
end;

function TPaymentsListDataFeederAncestor.GetOnOperation: TOnOperation;
begin
  Result := FOnOperation;
end;

procedure TPaymentsListDataFeederAncestor.SetOnOperation(const Value: TOnOperation);
begin
  FOnOperation := Value;
end;

procedure TPaymentsListDataFeederAncestor.ShowAllPaymentsByDate;
begin
  SetSQLforAll;
  RecreateListSource2;
end;

procedure TPaymentsListDataFeederAncestor.ShowPaymentsByCurrent;
begin
  SetSQLforCurrent;
  RecreateListSource;
end;

procedure TPaymentsListDataFeederAncestor.SetSQLforAll;
begin
  FReportMode := rm2All;
  Fds.Close;
  Fds.SQLs.SelectSQL.Text :=
    'SELECT PayID, Payments.Narid, Payments.PatID, PayDate, Payments.Summa, Payments.UserID, '+
           'Paysource, PayDirection, Storned, Payments.PayKind, Payments.CassaID, '+
           'coalesce(Casses.CassaName, BankAccounts.BankAccountName, '''') as CassaName, '+
           'Users.USecondName, Users.UFirstName, Users.USurName, Narlist.datecreated, Payments.PrintedRRO, '+
           'Doctors.USecondName as DSecondName, Doctors.UFirstName as DFirstName, Doctors.USurName as DSurName, '+
           'patients.PSecondName, patients.PFirstName, patients.PSurName, partners.partnername, DeAct, Payments.Comment '+
    'FROM Payments '+
    'LEFT JOIN Users ON Payments.UserID=Users.UserID '+
    'LEFT JOIN Narlist ON narlist.narid=payments.narid '+
    'left join Users Doctors ON Doctors.userid=narlist.useridcreated '+
    'left join patients on patients.patid=payments.patid '+
    'left join partners on partners.partnerid=payments.patid '+
    'left join casses on (casses.cassaid = Payments.CassaID) '+
    'left join bankaccounts on (bankaccounts.bankaccountid = Payments.CassaID) '+
//    'WHERE PayDate=:pdate '+
    'WHERE @whPayDate '+
          'AND (DeAct=:DeAct or DeAct IS NULL) '+
          'and (Narlist.deleted=:deleted) '+
          'and @whOwner '+
          'and (@whCasses or (PaySource = :pmSrcBank) or (PaySource = :pmSrcNoPay)) '+
    'ORDER BY Payments.PayDate descending, Partners.PartnerName, Partners.PartnerID, PSecondName, Payments.PatID, PayID';
  Fds.ParamByName('DeAct').Value := False;
  Fds.ParamByName('deleted').Value := False;
  Fds.ParamByName('pmSrcBank').Value := pmSrcBank;
  Fds.ParamByName('pmSrcNoPay').Value := pmSrcNoPay;
  if GlobalObj.LoginedUser.CheckAccess(sctViewAllCasses) then
    Fds.ParamByName('whCasses').Value := '(1=1)'
  else
    Fds.ParamByName('whCasses').Value := Format('(Payments.CassaID = %d)', [GlobalObj.LoginedUser.CassaID]);
  OnSetSQLParamOwner;
end;

procedure TPaymentsListDataFeederAncestor.SetSQLforCurrent;
begin
  FReportMode := rm2Current;
  Fds.Close;
  Fds.SQLs.SelectSQL.Text :=
    'SELECT PayID, Payments.Narid, Payments.PatID, PayDate, Payments.Summa, Payments.UserID, '+
           'Paysource, PayDirection, Storned, Payments.PayKind, Payments.CassaID, '+
           'coalesce(Casses.CassaName, BankAccounts.BankAccountName, '''') as CassaName, '+
           'Users.USecondName, Users.UFirstName, Users.USurName, NL.datecreated, Payments.PrintedRRO, '+
           'D.USecondName as DSecondName, D.UFirstName as DFirstName, D.USurName as DSurName, '+
           'patients.PSecondName, patients.PFirstName, patients.PSurName, partners.partnername, NL.DeAct, Payments.Comment '+
    'FROM Payments '+
    'LEFT JOIN Users on (Payments.UserID = Users.UserID) '+
    'LEFT JOIN Narlist as NL on (NL.narid = Payments.narid) '+
    'left join Users as D ON (D.userid = NL.useridcreated) '+
    'left join patients on (patients.patid = Payments.patid) '+
    'left join partners on partners.partnerid=payments.patid '+
    'left join casses on (casses.cassaid = Payments.CassaID) '+
    'left join bankaccounts on (bankaccounts.bankaccountid = Payments.CassaID) '+
    'WHERE (Payments.narid = :MasterID) '+
          'AND ((NL.DeAct = :DeAct) or (DeAct IS NULL)) '+
          'and (NL.deleted=:deleted) '+
    'ORDER BY PayDate Descending, PayID';
  Fds.ParamByName('DeAct').Value := False;
  Fds.ParamByName('deleted').Value := False;
end;

procedure TPaymentsListDataFeederAncestor.RecreateListSource2;
begin
  Fds.DisableControls;
  try
    Fds.DisableScrollEvents;
    try
      Fds.Close;
      SetSQLforAll;
      OnRecreateListSource2;
      Fds.Open;
      // Такое поведение Scroll'а нужно потому что
      // AfterScroll не происходит при пустом DataSet.
      // А так - произойдёт в любом случае.
      if Assigned(Fds.AfterScroll) then
        Fds.AfterScroll(Fds);
    finally
      Fds.EnableScrollEvents;
    end;
  finally
    Fds.EnableControls;
  end;
end;

procedure TPaymentsListDataFeederAncestor.SetMasterID(Value: IDentifier);
begin
  if FState<>omCreating then
    if FMasterID<>Value then
    begin
      FMasterID := Value;
      if FReportMode=rm2Current then
        RecreateListSource;
    end;
end;

procedure TPaymentsListDataFeederAncestor.ProcessDbEvent(EventName: string);
begin
  // 2008.12.29. Этот манс с FUpdTr нужен потому что Refresh выполняется в контексте
  // обновляющей транзакции, а она не активна постоянно.
  FUpdTr.StartTransaction;
  try
    inherited;
  finally
    FUpdTr.Rollback;
  end;
end;


{ TPaymentsList }

constructor TPaymentsList.Create;
begin
  inherited;
  FDbEventName := dbevChangePayments;
end;

procedure TPaymentsList.CreateDataFeeder;
begin
  FDataFeeder := TPaymentsListDataFeeder.Create;
end;

function TPaymentsList.GetInnerListSource: TDataSet;
begin
  Result := (FDataFeeder as IPaymentsListDataFeeder).GetInnerListSource;
end;

function TPaymentsList.GetInnPaymentsProcessor: IInnPaymentsProcessor;
begin
  Result := FDataFeeder as IInnPaymentsProcessor;
end;

function TPaymentsList.GetPaymentsListDataFeeder: IPaymentsListDataFeeder;
begin
  Result := FDataFeeder as IPaymentsListDataFeeder;
end;

function TPaymentsList.GetWorkDateDrivenObject: IWorkDateDrivenObject;
begin
  Result := FDataFeeder as IWorkDateDrivenObject;
end;

{ TPaymentsDataFeeder }

constructor TPaymentsDataFeeder.Create;
begin
  inherited;
  Fds.PrepareOptions := Fds.PrepareOptions - [psAskRecordCount];

  FIdField := 'NARID';
  FDbEventName := dbevChangePayList;
  FWorkDate := Date();
  FReportMode := rmUnpayedData;
  FShowUnpayedOnly := False;
  FShowDeactivated := False;

  FuTr := dbmDental.CreateTr;
  Fds.UpdateTransaction := FuTr;
  Fds.Transaction.StartTransaction;
  Fds.AutoUpdateOptions.KeyFields := 'NARID';
  Fds.AutoUpdateOptions.UpdateTableName := 'NARLIST';

  SetSQLforDate;

  Fds.ParamByName('wdate').AsDate := FWorkDate;

  Fds.Open;
end;

destructor TPaymentsDataFeeder.Destroy;
begin
  dbmDental.CloseTR(FuTr);
  inherited;
end;

function TPaymentsDataFeeder.GetOnChangeWorkDate: TOnChangeWorkDate;
begin
  Result := FOnChangeWorkDate;
end;

function TPaymentsDataFeeder.GetShowDeactivated: boolean;
begin
  Result := FShowDeactivated;
end;

function TPaymentsDataFeeder.GetWorkDate: TDateType;
begin
  Result := FWorkDate;
end;

procedure TPaymentsDataFeeder.SetOnChangeWorkDate(const Value: TOnChangeWorkDate);
begin
  FOnChangeWorkDate := Value;
end;

procedure TPaymentsDataFeeder.SetShowDeactivated(Value: boolean);
begin
  if FShowDeactivated<>Value then begin
    FShowDeactivated := Value;
    case FReportMode of
      rmUnpayedLast: RecreateCurrentDateList;
      rmUnpayed: ShowUnpayed;
    end;
  end;
end;

procedure TPaymentsDataFeeder.SetShowUnpayedOnly(AValue: boolean);
begin
  FShowUnpayedOnly := AValue;
end;

procedure TPaymentsDataFeeder.SetSQLforDate;
var
  WhereStr: string;
begin
  case FReportMode of
  rmUnpayedData:
    begin
      Fds.SQLs.SelectSQL.Text :=
      'SELECT P.PatID, P.PSecondName, P.PFirstName, P.PSurName, P.SpecialNotes, U.UserID, '+
             'U.USecondName, U.UFirstName, U.USurName, NarList.RefID, NarList.Printed, NarList.Deact, NarList.NarNum, '+
             'NarList.NarID, NarList.DateCreated, NarList.Summa+coalesce(v_D.discsumm,0) as summa, PayedSumm, '+
             'NarList.Summa as OriginalSumm, coalesce(v_D.discsumm,0) as discsumm, coalesce(v_D.bonussumm,0) as bonussumm '+
      'FROM NarList '+
      'LEFT JOIN Users as U ON (U.UserID = NarList.UserIDCreated) '+
      'LEFT JOIN Patients as P ON (P.PatID = NarList.PatID) '+
      'LEFT JOIN (SELECT coalesce(SUM(case PayDirection when :pdin then Summa when :pdout then -Summa else 0 end),0) as PayedSumm, NarID FROM Payments '+
                 'WHERE Storned=:stor GROUP BY NarID) psumm '+
        'ON psumm.NarID=NarList.NarID '+
      'LEFT JOIN V_Discounts v_D ON (v_D.Narid = NarList.narid) '+
      'WHERE ((psumm.PayedSumm < (NarList.Summa+coalesce(v_D.discsumm,0))) or (psumm.PayedSumm IS NULL)) '+
            'and (NarList.DateCreated=:wdate) '+
            'AND (NarList.DeAct=:DeAct or NarList.DeAct IS NULL) '+
            'and (NarList.deleted = :deleted) '+
            'and (P.PatID is not null) '+ // этим отсекаются наряды партнёров
      'ORDER BY psecondname,narid';
    end;
  rmWorkDate:
    begin
      Fds.SQLs.SelectSQL.Text :=
        'SELECT Patients.PatID, Patients.PSecondName, Patients.PFirstName, Patients.PSurName, Patients.SpecialNotes, Users.UserID, NarList.Deact, '+
        'Users.USecondName, Users.UFirstName, Users.USurName, NarList.NarID, NarList.RefID, NarList.DateCreated, NarList.Summa+coalesce(v_D.discsumm,0) as summa, PayedSumm, '+
        'NarList.Summa as OriginalSumm, coalesce(v_D.discsumm,0) as discsumm, coalesce(v_D.bonussumm,0) as bonussumm, NarList.Printed, NarList.NarNum '+
        'FROM NarList LEFT JOIN Users ON Users.UserID=NarList.UserIDCreated '+
        'LEFT JOIN Patients ON Patients.PatID=NarList.PatID '+
        'LEFT JOIN (SELECT coalesce(SUM(case PayDirection when :pdin then Summa when :pdout then -Summa else 0 end),0) as PayedSumm, NarID FROM Payments '+
                   'WHERE Storned=:stor GROUP BY NarID) psumm '+
          'ON psumm.NarID=NarList.NarID '+
        'LEFT JOIN V_Discounts v_D ON v_D.Narid=narlist.narid '+
        'WHERE DateCreated=:wdate AND (DeAct=:DeAct or DeAct IS NULL) AND '+
              'and (Narlist.deleted=:deleted) '+
              'and (Patients.PatID is not null) '+ // этим отсекаются наряды партнёров
        'ORDER BY psecondname,narid';
    end;
  rmUnpayedLast:
    begin
      if FShowUnpayedOnly then begin
        WhereStr := '(NarList.Unpayed=1)';
      end else begin
        WhereStr := '(psumm.PayedSumm<(NarList.Summa+coalesce(v_D.discsumm,0)) or (psumm.PayedSumm IS NULL))'
      end;
      Fds.SQLs.SelectSQL.Text :=
      'SELECT Patients.PatID, Patients.PSecondName, Patients.PFirstName, Patients.PSurName, Patients.SpecialNotes, Users.UserID, NarList.Deact, '+
      'Users.USecondName, Users.UFirstName, Users.USurName, NarList.NarID, NarList.RefID, NarList.DateCreated, NarList.Summa+coalesce(v_D.discsumm,0) as summa, PayedSumm, '+
      'NarList.Summa as OriginalSumm, coalesce(v_D.discsumm,0) as discsumm, coalesce(v_D.bonussumm,0) as bonussumm, NarList.Printed, NarList.UserIDCreated, NarList.NarNum '+
      'FROM NarList '+
      'LEFT JOIN Users ON Users.UserID=NarList.UserIDCreated '+
      'LEFT JOIN Patients ON Patients.PatID=NarList.PatID '+
      'LEFT JOIN (SELECT coalesce(SUM(case PayDirection when :pdin then Summa when :pdout then -Summa else 0 end),0) as PayedSumm, NarID FROM Payments '+
                 'WHERE Storned=:stor GROUP BY NarID) psumm '+
        'ON psumm.NarID=NarList.NarID '+
      'LEFT JOIN V_Discounts v_D ON v_D.Narid=narlist.narid '+
      'WHERE '+WhereStr+' '+
            'and (NarList.DateCreated>=(:wdate-30)) '+
            'AND (DeAct=:DeAct or DeAct IS NULL) '+
            'and (Narlist.deleted=:deleted) '+
            'and (Patients.PatID is not null) '+ // этим отсекаются наряды партнёров
            'and @@whDeact%1=1@ '+
      'ORDER BY psecondname,narid';
      if not FShowDeactivated then begin
        Fds.ParamByName('whDeact').Value := '(coalesce(DeAct,0)=0)';
      end;
    end;
  end;
  if Fds.ParamByName('DeAct')<>nil then begin
    Fds.ParamByName('DeAct').Value := False;
  end;
  Fds.ParamByName('deleted').Value := False;
  Fds.ParamByName('stor').Value := False;
  Fds.ParamByName('pdin').Value := pmDirectIn;
  Fds.ParamByName('pdout').Value := pmDirectOut;
end;

procedure TPaymentsDataFeeder.SetSQLforUnPayed;
var
  WhereStr1, WhereStr2: string;
begin
  if FShowUnpayedOnly then begin
    WhereStr1 := '(NarList.Unpayed=1)';
  end else begin
    WhereStr1 := '(psumm.PayedSumm<(NarList.Summa+coalesce(v_D.discsumm,0)) or (psumm.PayedSumm IS NULL))'
  end;
  if FShowDeactivated then begin
    WhereStr2 := '';
  end else begin
    WhereStr2 := 'and (coalesce(NarList.DeAct,0)=0) ';
  end;

  Fds.SQLs.SelectSQL.Text :=
    'SELECT Patients.PatID, Patients.PSecondName, Patients.PFirstName, Patients.PSurName, Patients.SpecialNotes, Users.UserID, '+
    'Users.USecondName, Users.UFirstName, Users.USurName, NarList.NarID, NarList.RefID, NarList.DateCreated, NarList.Summa+coalesce(v_D.discsumm,0) as summa, PayedSumm, DeAct, '+
    'NarList.Summa as OriginalSumm, coalesce(v_D.discsumm,0) as discsumm, coalesce(v_D.bonussumm,0) as bonussumm, NarList.Printed, NarList.UserIDCreated, NarList.NarNum '+
    'FROM NarList '+
    'LEFT JOIN Users ON Users.UserID=NarList.UserIDCreated '+
    'LEFT JOIN Patients ON Patients.PatID=NarList.PatID '+
    'LEFT JOIN (SELECT coalesce(SUM(case PayDirection when :pdin then Summa when :pdout then -Summa else 0 end),0) as PayedSumm, NarID FROM Payments '+
    '           WHERE Storned=:stor GROUP BY NarID) psumm '+
    '  ON psumm.NarID=NarList.NarID '+
    'LEFT JOIN V_Discounts v_D ON v_D.Narid=narlist.narid '+
    'WHERE '+WhereStr1+' '+
          'and (Narlist.deleted=:deleted) '+
          'and (Patients.PatID is not null) '+ // этим отсекаются наряды партнёров
          WhereStr2 +
    'ORDER BY psecondname,narid';
  Fds.ParamByName('stor').Value := False;
  Fds.ParamByName('deleted').Value := False;
  Fds.ParamByName('pdin').Value := pmDirectIn;
  Fds.ParamByName('pdout').Value := pmDirectOut;
end;

procedure TPaymentsDataFeeder.SetWorkDate(const Value: TDateType);
begin
  if FState<>omCreating then
    if (FWorkDate<>Value) then
    begin
      FWorkDate := Value;

      if FReportMode in [rmWorkDate, rmUnpayedData] then
        RecreateCurrentDateList;

      if Assigned(FOnChangeWorkDate) then
        FOnChangeWorkDate(FWorkDate);
    end;
end;

procedure TPaymentsDataFeeder.ShowUnpayed;
begin
  Fds.DisableControls;
  try
    Fds.DisableScrollEvents;
    try
      Fds.Close;
      SetSQLforUnPayed;
      Fds.Open;
      // Такое поведение Scroll'а нужно потому что
      // AfterScroll не происходит при пустом DataSet.
      // А так - произойдёт в любом случае.
      if Assigned(Fds.AfterScroll) then
        Fds.AfterScroll(Fds);
    finally
      Fds.EnableScrollEvents;
    end;
  finally
    Fds.EnableControls;
  end;
end;

procedure TPaymentsDataFeeder.RecreateCurrentDateList;
begin
  Fds.DisableControls;
  try
    Fds.DisableScrollEvents;
    try
      Fds.Close;
      SetSQLforDate;
      Fds.ParamByName('wdate').AsDate := DateTypeToFieldValue(FWorkDate);
      Fds.Open;
      // Такое поведение Scroll'а нужно потому что
      // AfterScroll не происходит при пустом DataSet.
      // А так - произойдёт в любом случае.
      if Assigned(Fds.AfterScroll) then
        Fds.AfterScroll(Fds);
    finally
      Fds.EnableScrollEvents;
    end;
  finally
    Fds.EnableControls;
  end;
end;

function TPaymentsDataFeeder.GetCurrentPatID: IDentifier;
begin
  if CurrentID<>UndefiniteID then
    Result := VariantAsIDentifier(Fds.FieldByName('PatID').Value)
  else
    Result := UndefiniteID;
end;

procedure TPaymentsDataFeeder.MoveToNarid(ANarID: IDentifier);
begin
  Fds.Locate('narid', ANarid, []);
end;

function TPaymentsDataFeeder.GetUnpayedViewMode: integer;
begin
  Result := FReportMode;
end;

procedure TPaymentsDataFeeder.SetUnpayedViewMode(const Value: integer);
begin
  if FReportMode<>Value then
  begin
    FReportMode := Value;
    case FReportMode of
      rmWorkDate, rmUnpayedData, rmUnpayedLast: RecreateCurrentDateList;
      rmUnpayed: ShowUnpayed;
    end;
  end;  
end;

procedure TPaymentsDataFeeder.ForceRefresh(Summa: currency);
begin
  if (Summa=Fds.FieldByName('Summa').Value) and (FReportMode<>rmWorkDate) then begin
    Fds.DisableControls;
    try
      Fds.DisableScrollEvents;
      try
        Fds.FullRefresh;
        if Assigned(Fds.AfterScroll) then
          Fds.AfterScroll(Fds);
      finally
        Fds.EnableScrollEvents;
      end;
    finally
      Fds.EnableControls;
    end;
  end else // 2011.04.06 Это чтобы передёрнуть сумму PayedSumm в списке квитанций
    Fds.Refresh;
end;

procedure TPaymentsDataFeeder.ChangePaymentNarad;
var
  nc: IPaymentNarChanger;
  f: TfrmPayChangeNar;
begin
  if CurrentID<>UndefiniteID then begin
    f := TfrmPayChangeNar.Create(Application);
    try
      f.ds.Database := dbmDental.db;
      f.tr.DefaultDatabase := dbmDental.db;
      f.ds.Transaction.StartTransaction;
      try
        f.ds.ParamByName('pdin').Value := pmDirectIn;
        f.ds.ParamByName('pdout').Value := pmDirectOut;
        f.ds.ParamByName('notdeleted').Value := False;
        f.ds.ParamByName('notstorned').Value := False;
        f.ds.ParamByName('notdeact').Value := False;
        f.ds.ParamByName('patid').Value := Fds.FieldByName('PatID').Value;
        f.ds.ParamByName('CurrentNarID').Value := CurrentID;
        f.ds.Open;
        if (f.ShowModal=mrOk) then begin
          if MessageDlg('Перенести оплату на эту квитанцию?', mtConfirmation, [mbYes, mbNo], 0)=mrYes then begin

            nc := TPaymentNarChanger.Create;
            try
              nc.ID := f.ds.FieldByName('PayID').Value;
              (nc.Props as IPaymentNarChangerProperties).MovedSumm := f.edSumm.Value;
              if f.FMoveBonus then
                (nc.Props as IPaymentNarChangerProperties).BonusSumm := VariantAsPriceType(f.ds.FieldByName('BonusSumm').Value, 0)
              else
                (nc.Props as IPaymentNarChangerProperties).BonusSumm := 0;
              (nc.Props as IPaymentNarChangerProperties).NewNarID := CurrentID;
              (nc.Props as IPaymentNarChangerProperties).SetNewComment;
              nc.Edit;
            finally
              nc := nil;
            end;

          end;
        end;
      finally
        f.ds.Transaction.Rollback;
      end;
    finally
      f.Free;
    end;
  end;
end;

{ TIPaymentsIndicator }

constructor TIPaymentsIndicator.Create;
begin
  inherited;
  FDbEventName := dbevChangePayments;
  Fds.PrepareOptions := Fds.PrepareOptions - [psAskRecordCount];
  Fds.DetailConditions := Fds.DetailConditions + [dcWaitEndMasterScroll] + [dcForceOpen];
  Fds.AfterOpen := OnAfterOpen;
  Fds.SelectSQL.Text :=
    'select patients.PatID, patients.psecondname, patients.pfirstname, patients.psurname, '+
           'coalesce(paysumm.summap,0) as summap, '+
           'coalesce(summainex,0)-coalesce(summaoutex,0) as summapex, '+
           'coalesce(paysumm.summap,0) + coalesce(summainex,0)-coalesce(summaoutex,0) as summaall, '+
           'coalesce(dc.maxpercent,0) as maxpercent, '+
           'coalesce(discardctgr.minpay,0) as minpay, coalesce(discardctgr.maxpay,0) as maxpay, '+
           'summaavans, narsumm, BonusSumm, '+
           '(case '+
             'when (coalesce(narsumm, 0) - coalesce(paysumm.summap,0))<=0 then 0 '+
             'else (coalesce(narsumm, 0) - coalesce(paysumm.summap,0)) '+
           'end) as debetsumm '+
    'from patients '+
    'left join '+
      '(select coalesce(SUM(case P.PayDirection when :pdin then P.Summa when :pdout then -P.Summa else 0 end),0) as summap, P.patid '+
       'from Payments as P '+
       'where (P.Storned = :storned) '+
       'group by P.patid '+
    ') paysumm on paysumm.patid=patients.patid '+

    'left join '+
       '/* потом - аванс */ '+
       '(SELECT NL.patid, sum(coalesce(psumm.PayedSumm, 0) - (NL.summa + coalesce(v_D.discsumm,0))) as summaavans '+
        'from narlist NL '+
        'left join V_Discounts v_D on (NL.narid = v_D.narid) '+
        'LEFT JOIN (SELECT SUM(case PayDirection when :pdin then Summa when :pdout then -Summa else 0 end) as PayedSumm, NarID FROM Payments '+
                   'WHERE (storned = :storned) GROUP BY NarID) psumm ON (psumm.NarID = NL.NarID) '+
        'where (NL.deleted = :deleted) '+
              'and (NL.deact = :DeAct) '+
              'and ((coalesce(psumm.PayedSumm, 0) - (NL.summa + coalesce(v_D.discsumm,0))) > 0) '+
        'group by NL.patid '+
       ') PayAvans on PayAvans.patid=patients.patid '+
    'left join '+
       '/* потом - бонус */ '+
       '(SELECT NL.patid, sum(v_D.BonusSumm) as BonusSumm '+
        'from narlist NL '+
        'left join V_Discounts v_D on (NL.narid = v_D.narid) '+
        'where (NL.deleted = :deleted) '+
              'and (NL.deact = :DeAct) '+
              'and (v_D.BonusSumm <> 0) '+
        'group by NL.patid '+
       ') PayBonus on PayBonus.patid=patients.patid '+
    'left join '+
    '(select payinex.patid, summainex, summaoutex from '+
      '(select discards.patid, sum(payments.summa) as summainex '+
         'from payments '+
         'left join V_Discounts v_D on v_D.narid=payments.narid '+
         'left join discards on discards.cardid=v_D.cardid '+
         'where payments.PayDirection=:pdin and payments.storned=:storned and '+
               'payments.patid<>discards.patid '+
       'group by patid '+
      ') payinex '+
      'full join '+
      '(select discards.patid, sum(payments.summa) as summaoutex '+
         'from payments '+
         'left join V_Discounts v_D on v_D.narid=payments.narid '+
         'left join discards on discards.cardid=v_D.cardid '+
         'where payments.PayDirection=:pdout and payments.storned=:storned and '+
               'payments.patid<>discards.patid '+
       'group by patid '+
      ') payoutex on payoutex.patid=payinex.patid '+
    ') paysummex on paysummex.patid=patients.patid '+
    'left join '+
      '(select max(percent) as maxpercent,patid from discards where (dateend is null) and patid=:MAS_PatID '+
       'group by patid) '+
      'dc on dc.patid=patients.patid '+
    'left join discardctgr on discardctgr.percent=coalesce(dc.maxpercent,0) '+
    'left join (select sum(narlist.summa+coalesce(v_D.discsumm,0)) as narsumm, narlist.patid '+
               'from narlist '+
               'left join V_Discounts v_D on (narlist.narid = v_D.narid) '+
               'where (coalesce(narlist.deact,0) = :deact) '+
                     'and (Narlist.deleted = :deleted) '+
               'group by narlist.patid) narlisted on (narlisted.patid = patients.patid) '+
    'WHERE patients.patid=:MAS_PatID '+
    'ORDER BY patients.psecondname, patients.pfirstname, patients.psurname';

  Fds.ParamByName('pdin').Value := pmDirectIn;
  Fds.ParamByName('pdout').Value := pmDirectOut;
  Fds.ParamByName('storned').Value := False;
  Fds.ParamByName('deleted').Value := False;
  Fds.ParamByName('deact').Value := False;

  Ftr.StartTransaction;
end;

destructor TIPaymentsIndicator.Destroy;
begin
  inherited;
end;

function TIPaymentsIndicator.GetIsOutOfPercentLimit: boolean;
var
  p, mp, mmin, mmax: TPriceType;
begin
  if VariantAsIDentifier(Fds.FieldByName('PatID').Value)<>UndefiniteID then
  begin
    p := VariantAsPriceType(Fds.FieldByName('summaall').Value, 0);
    mp := VariantAsPriceType(Fds.FieldByName('maxpercent').Value, 0);
    mmin := VariantAsPriceType(Fds.FieldByName('MinPay').Value, 0);
    mmax := VariantAsPriceType(Fds.FieldByName('MaxPay').Value, 0);
    if (p>=mmin) and (p<=mmax) then
      Result := False
    else
      Result := True;
  end
  else
    Result := False;
end;

function TIPaymentsIndicator.GetOnIndicate: TOnIndicate;
begin
  Result := FOnIndicate;
end;

function TIPaymentsIndicator.GetSummaBonus: TPriceType;
begin
  if not (VarIsEmpty(Fds.FieldByName('PatID').Value) or VarIsNull(Fds.FieldByName('PatID').Value)) then
    Result := VariantAsPriceType(Fds.FieldByName('BonusSumm').Value, 0)
  else
    Result := 0;
end;

function TIPaymentsIndicator.GetSummaDebet: TPriceType;
begin
  if not (VarIsEmpty(Fds.FieldByName('PatID').Value) or VarIsNull(Fds.FieldByName('PatID').Value)) then
    Result := VariantAsPriceType(Fds.FieldByName('debetsumm').Value, 0)
  else
    Result := 0;
end;

function TIPaymentsIndicator.GetSummaNarlisted: TPriceType;
begin
  if not (VarIsEmpty(Fds.FieldByName('PatID').Value) or VarIsNull(Fds.FieldByName('PatID').Value)) then
    Result := VariantAsPriceType(Fds.FieldByName('narsumm').Value, 0)
  else
    Result := 0;
end;

function TIPaymentsIndicator.GetSummaPay: TPriceType;
begin
  if not (VarIsEmpty(Fds.FieldByName('PatID').Value) or VarIsNull(Fds.FieldByName('PatID').Value)) then
    Result := VariantAsPriceType(Fds.FieldByName('summap').Value, 0)
  else
    Result := 0;
end;

function TIPaymentsIndicator.GetSummaPayAll: TPriceType;
begin
  if not (VarIsEmpty(Fds.FieldByName('PatID').Value) or VarIsNull(Fds.FieldByName('PatID').Value)) then
    Result := VariantAsPriceType(Fds.FieldByName('summaall').Value, 0)
  else
    Result := 0;
end;

function TIPaymentsIndicator.GetSummaPayAvans: TPriceType;
begin
  if not (VarIsEmpty(Fds.FieldByName('PatID').Value) or VarIsNull(Fds.FieldByName('PatID').Value)) then
    Result := VariantAsPriceType(Fds.FieldByName('summaavans').Value, 0)
  else
    Result := 0;
end;

function TIPaymentsIndicator.GetSummaPayEx: TPriceType;
begin
  if not (VarIsEmpty(Fds.FieldByName('PatID').Value) or VarIsNull(Fds.FieldByName('PatID').Value)) then
    Result := VariantAsPriceType(Fds.FieldByName('summapex').Value, 0)
  else
    Result := 0;
end;

procedure TIPaymentsIndicator.OnAfterOpen(Sender: TDataSet);
begin
  if Assigned(FOnIndicate) then
    FOnIndicate;
end;

procedure TIPaymentsIndicator.OnCreateTransaction;
begin
  Ftr := dbmDental.CreateTr(trSingleNoLockTrans);
end;

procedure TIPaymentsIndicator.ProcessDbEvent(EventName: string);
begin
  inherited;

  if Assigned(FOnIndicate) then
    FOnIndicate;
end;

procedure TIPaymentsIndicator.SetMasterSource(ADataSource: TDataSource);
begin
  Fds.DataSource := ADataSource;
end;

procedure TIPaymentsIndicator.SetOnIndicate(const Value: TOnIndicate);
begin
  FOnIndicate := Value;
end;

{ TPaymentNarChangerProperties }

function TPaymentNarChangerProperties.Clone: IProperties;
begin
  Result := TPaymentNarChangerProperties.Create;
  (Result as IPaymentNarChangerProperties).NewNarID   := FNewNarID;
//  (Result as IPaymentNarChangerProperties).NewComment := FNewComment;
  (Result as IPaymentNarChangerProperties).MovedSumm  := FMovedSumm;
  (Result as IPaymentNarChangerProperties).BonusSumm  := FBonusSumm;
end;

constructor TPaymentNarChangerProperties.Create;
begin
  inherited;
  FNewNarID := UndefiniteID;
end;

function TPaymentNarChangerProperties.GetBonusSumm: TPriceType;
begin
  Result := FBonusSumm;
end;

function TPaymentNarChangerProperties.GetMovedSumm: TPriceType;
begin
  Result := FMovedSumm;
end;

function TPaymentNarChangerProperties.GetNewComment: widestring;
begin
  Result := FNewComment;
end;

function TPaymentNarChangerProperties.GetNewNarID: IDentifier;
begin
  Result := FNewNarID;
end;

procedure TPaymentNarChangerProperties.SetBonusSumm(const Value: TPriceType);
begin
  FBonusSumm := Value;
end;

procedure TPaymentNarChangerProperties.SetMovedSumm(const Value: TPriceType);
begin
  FMovedSumm := Value;
end;

procedure TPaymentNarChangerProperties.SetNewComment;
begin
  if FBonusSumm=0 then
    FNewComment := 'аванс израсходован '+DateTypeToStr(Date())
  else
    FNewComment := 'бонус преобразован в скидку ''аванс израсходован '+DateTypeToStr(Date());
end;

procedure TPaymentNarChangerProperties.SetNewNarID(const Value: IDentifier);
begin
  FNewNarID := Value;
end;

{ TPaymentNarChangerDataFeeder }

constructor TPaymentNarChangerDataFeeder.Create;
begin
  inherited;
  Fds.AutoUpdateOptions.UpdateTableName := 'PAYMENTS';
  Fds.AutoUpdateOptions.KeyFields := 'PAYID';
  Fds.PrepareOptions := Fds.PrepareOptions - [psAskRecordCount];
end;

procedure TPaymentNarChangerDataFeeder.InternalDelete(Aid: IDentifier; AProps: IProperties);
begin
end;

procedure TPaymentNarChangerDataFeeder.InternalOpenEdit(var Aid: IDentifier; AProps: IProperties);
begin
  Fds.SelectSQL.Text := 'SELECT * FROM Payments WHERE PayID=:payid FOR UPDATE WITH LOCK';
  Fds.ParamByName('payid').Value := Aid;
  Fds.Open;
end;

procedure TPaymentNarChangerDataFeeder.InternalOpenView(var Aid: IDentifier; AProps: IProperties);
begin
  Fds.SelectSQL.Text := 'SELECT * FROM Payments WHERE PayID=:payid';
  Fds.ParamByName('payid').Value := Aid;
  Fds.Open;
end;

procedure TPaymentNarChangerDataFeeder.InternalReadProps(var Aid: IDentifier; AProps: IProperties);
begin
end;

procedure TPaymentNarChangerDataFeeder.InternalSave(var Aid: IDentifier; AProps: IProperties);
var
  orgNarID, orgPatID, orgCassaID: IDentifier;
  orgPayDate: TDateType;
  orgSumma: TPriceType;
  orgPaySource: integer;
  orgComment: widestring;
  orgPrintedRRO: boolean;
  dsBonus, dsOldDiscount: TpFibDataSet;
  BonusSumm: TPriceType;
begin
  orgNarID   := VariantAsIDentifier(Fds.FieldByName('NarID').Value);

  if (AProps as IPaymentNarChangerProperties).BonusSumm = 0 then begin
    {Если єто не перенос бонуса}
    if (AProps as IPaymentNarChangerProperties).MovedSumm = VariantAsPriceType(Fds.FieldByName('summa').Value, 0) then begin
      Fds.Edit;
      Fds.FieldByName('NarID').Value := (AProps as IPaymentNarChangerProperties).NewNarID;
      Fds.FieldByName('Comment').Value := (AProps as IPaymentNarChangerProperties).NewComment;
      Fds.FieldByName('PayKind').Value := pkUsualPay;
      Fds.Post;
    end else begin
      orgPatID   := VariantAsIDentifier(Fds.FieldByName('PatID').Value);
      orgPayDate := FieldValueToDateType(Fds.FieldByName('PayDate').Value);
      orgSumma   := VariantAsPriceType(Fds.FieldByName('Summa').Value, 0);
      orgPaySource := Fds.FieldByName('PaySource').Value;
      orgComment := Fds.FieldByName('Comment').Value;
      orgCassaID := Fds.FieldByName('CassaID').Value;
      orgPrintedRRO := Fds['PrintedRRO'];

      Fds.Edit;
      Fds.FieldByName('Storned').Value := True;
      Fds.Post;

      Fds.Append;
      Fds.FieldByName('NarID').Value := orgNarID;
      Fds.FieldByName('PatID').Value := orgPatID;
      Fds.FieldByName('UserID').Value := GlobalObj.LoginedUser.UserID;
      Fds.FieldByName('PayDate').Value := DateTypeToFieldValue(orgPayDate);
      Fds.FieldByName('Summa').Value := orgSumma - (AProps as IPaymentNarChangerProperties).MovedSumm;
      Fds.FieldByName('PayDirection').Value := pmDirectIn;
      Fds.FieldByName('PaySource').Value := orgPaySource;
      Fds.FieldByName('PayKind').Value := pkUsualPay;
      Fds.FieldByName('Storned').Value := False;
      Fds.FieldByName('Comment').Value := orgComment;
      Fds.FieldByName('CassaID').Value := orgCassaID;
      Fds['PrintedRRO'] := orgPrintedRRO;
      Fds.Post;

      Fds.Append;
      Fds.FieldByName('NarID').Value := orgNarID; //(AProps as IPaymentNarChangerProperties).NewNarID;
      Fds.FieldByName('PatID').Value := orgPatID;
      Fds.FieldByName('UserID').Value := GlobalObj.LoginedUser.UserID;
      Fds.FieldByName('PayDate').Value := DateTypeToFieldValue(orgPayDate);
      Fds.FieldByName('Summa').Value := (AProps as IPaymentNarChangerProperties).MovedSumm;
      Fds.FieldByName('PayDirection').Value := pmDirectIn;
      Fds.FieldByName('PaySource').Value := orgPaySource;
      Fds.FieldByName('PayKind').Value := pkUsualPay;
      Fds.FieldByName('Storned').Value := False;
      Fds.FieldByName('Comment').Value := orgComment; //(AProps as IPaymentNarChangerProperties).NewComment;
      Fds.FieldByName('CassaID').Value := orgCassaID;
      Fds['PrintedRRO'] := orgPrintedRRO;
      Fds.Post;
      {Тут надо именно изменять ПОСЛЕ добавления, потому что в лог не попадёт запись о ПЕРЕНОСЕ}
      Fds.Edit;
      Fds.FieldByName('NarID').Value := (AProps as IPaymentNarChangerProperties).NewNarID;
      Fds.FieldByName('Comment').Value := (AProps as IPaymentNarChangerProperties).NewComment;
      Fds.Post;
    end;
  end else begin
    {Сбросить бонус. То есть перенести сумму бонуса как скидку на выбранную квитанцию}
    dsBonus := dbmDental.CreateDS;
    dsOldDiscount := dbmDental.CreateDS;
    try
      dsBonus.Transaction := Fds.Transaction;
      dsBonus.UpdateTransaction := Fds.UpdateTransaction;
      dsBonus.AutoUpdateOptions.UpdateTableName := 'DISCOUNTS';
      dsBonus.AutoUpdateOptions.KeyFields := 'DISCID';
      dsBonus.SelectSQL.Text := 'select * from Discounts where (NarID = :NarID) and (IsBonus = 1)';
      dsBonus.ParamByName('NarID').Value := orgNarID;
      dsBonus.Open;

      dsOldDiscount.Transaction := Fds.Transaction;
      dsOldDiscount.UpdateTransaction := Fds.UpdateTransaction;
      dsOldDiscount.AutoUpdateOptions.UpdateTableName := 'DISCOUNTS';
      dsOldDiscount.AutoUpdateOptions.KeyFields := 'DISCID';
      dsOldDiscount.SelectSQL.Text := 'select * from Discounts where (NarID = :NarID) and (IsBonus = 0)';
      dsOldDiscount.ParamByName('NarID').Value := (AProps as IPaymentNarChangerProperties).NewNarID;
      dsOldDiscount.Open;

      if dsOldDiscount.IsEmpty then begin
        dsBonus.First;
        if not dsBonus.Eof then begin
          if VariantAsBoolean(dsBonus.FieldByName('IsBonus').Value) then begin
            dsBonus.Edit;
            dsBonus.FieldByName('NarID').Value := (AProps as IPaymentNarChangerProperties).NewNarID;
            dsBonus.FieldByName('DiscKind').Value := dmSumma;
            dsBonus.FieldByName('IsBonus').Value := False;
            dsBonus.Post;
          end;
        end;
      end else begin
        dsBonus.First;
        if not dsBonus.Eof then begin
          BonusSumm := -Abs(VariantAsPriceType(dsBonus.FieldByName('DiscSumm').Value, 0));
        end else begin
          BonusSumm := 0;
        end;
        dsBonus.Delete;

        dsOldDiscount.Edit;
        dsOldDiscount.FieldByName('DiscKind').Value := dmSumma;
        dsOldDiscount.FieldByName('DiscSumm').Value := dsOldDiscount.FieldByName('DiscSumm').Value + BonusSumm;
        dsOldDiscount.Post;
      end;

    finally
      dbmDental.CloseDS(dsBonus);
      dbmDental.CloseDS(dsOldDiscount);
    end;
  end;
end;

{ TPaymentNarChanger }

procedure TPaymentNarChanger.CreateDataFeeder;
begin
  FDataFeeder := TPaymentNarChangerDataFeeder.Create;
end;

procedure TPaymentNarChanger.CreateProperties;
begin
  FProps := TPaymentNarChangerProperties.Create;
end;

procedure TPaymentNarChanger.EditProps;
begin
  Save(FProps);
end;

end.

