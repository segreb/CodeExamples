unit DentalIntf;

interface

uses
  DB, Classes,
  //TntWideStrings, TntClasses,
  WideStrings,
  uCommonDefinitions,
//  pFIBDatabase,
  pFibQuery,
  SysUtils,
  VirtualTrees;

type
  TOnChangedCurrentID = procedure (NewID: integer) of object;
  TOnChangingCurrentID = procedure (NewID: integer) of object;
  TOnNotifySuperModel = procedure of object;
  TOnChangedSrcIdx = procedure (NewSrcIdx: integer) of object;

  TPatientChoicedProc = procedure (AData: IInterface);

  ISecurityHolder = interface(IInterface)
  ['{93E4411C-B5D0-492E-9D69-F3EF3196460B}']
    function TokenExists(AToken: integer): boolean;
    procedure AddToken(AToken: integer);
    procedure DeleteToken(AToken: integer);
    function Clone: ISecurityHolder;
    procedure SaveToDb(AID: IDentifier; q: TpFibQuery);
    procedure Clear;
  end;

  IProperties = interface(IInterface)
  ['{4A262547-1150-4661-8C72-4273D2C8E836}']
    function Clone: IProperties;
  end;

  ICompositeProperties = interface(IProperties)
  ['{553F5365-AB7C-45F3-892E-16FF1F6F51E5}']
    function GetProp(Idx: integer): IProperties;
    property Prop[Idx: integer]: IProperties read GetProp;
    function RegisterProp(Prop: IProperties): integer;
    function GetPropCount: integer;
    property PropCount: integer read GetPropCount;
  end;

  ITimeCellPatDescription = interface(IProperties)
  ['{B9FBECF1-5B0D-4CC8-A358-77018081BE06}']
    function GetPatID: IDentifier;
    procedure SetPatID(Value: IDentifier);
    property PatID: IDentifier read GetPatID write SetPatID;
    function GetPatName: widestring;
    procedure SetPatName(Value: widestring);
    property PatName: widestring read GetPatName write SetPatName;
    procedure Setuselok(const Value: widestring);
    function Getuselok: widestring;
    property uselok: widestring read Getuselok write Setuselok;
    function GetPatFullName: widestring;
    property PatFullName: widestring read GetPatFullName;
    function GetFirstName: widestring;
    procedure SetFirstName(Value: widestring);
    property FirstName: widestring read GetFirstName write SetFirstName;
    function GetSurName: widestring;
    procedure SetSurName(Value: widestring);
    property SurName: widestring read GetSurName write SetSurName;
    function GetSecondName: widestring;
    procedure SetSecondName(Value: widestring);
    property SecondName: widestring read GetSecondName write SetSecondName;
  end;

  IPersistPatientProperties = interface(ITimeCellPatDescription)
  ['{125F5FCE-E766-4EB9-B662-E6769F21DF0B}']
    procedure SetSpecID(const Value: IDentifier);
    function GetSpecID: IDentifier;
    property SpecID: IDentifier read GetSpecID write SetSpecID;
  end;

  IEditPropForm = interface;

  IDataFeeder = interface(IInterface)
  ['{B99D8F06-B733-4C77-BFFA-BBB48F69A86C}']
    procedure ProcessDbEvent(EventName: string);
    procedure Init;
    function GetListSource: TDataSet;
  end;

  IObjectDataFeeder = interface(IDataFeeder{IInterface})
  ['{B76ACBEE-9E45-4A51-9468-247705E37D26}']
    function Read(var Aid: IDentifier; AProps: IProperties; AOpenState: TOpenState; var AEditViewState: TEditViewState): dbopState;
    function Save(var Aid: IDentifier; AProps: IProperties): dbopState;
    function Delete(Aid: IDentifier; AProps: IProperties): dbopState;
  end;

  ICompositeDataFeeder = interface(IObjectDataFeeder)
  ['{CFF53415-8F28-49F5-877F-1A9188EAB0A5}']
    function GetDataFeeder(Idx: integer): IDataFeeder;
    property DataFeeders[Idx: integer]: IDataFeeder read GetDataFeeder;
    function RegisterDataFeeder(DF: IDataFeeder): integer;
    function GetDataFeederCount: integer;
    property DataFeederCount: integer read GetDataFeederCount;
  end;

  IListedObject = interface(IInterface)
  ['{42E6DCF9-E5BD-45C0-B03E-6DB7C87B076C}']
    function GetID: IDentifier;
    procedure SetID(Value: IDentifier);
    property ID: IDentifier read GetID write SetID;
    procedure EditProps;
    function Edit(AOpenState: TOpenState = osEditOrView): ObjDbConvState;
    function Delete: ObjDbConvState;
    function GetProperties: IProperties;
    procedure SetProperties(Value: IProperties);
    property Props: IProperties read GetProperties write SetProperties;
    function Save(AProps: IProperties): ObjDbConvState;
    function SaveWithRetry(AProps: IProperties): ObjDbConvState;
    function CreatePropForm: IEditPropForm;
    function GetEditState: TEditViewState;
    procedure SetEditState(Value: TEditViewState);
    property EditState: TEditViewState read GetEditState write SetEditState;
    function OpenedForEdit: boolean;
    function OpenedForView: boolean;
    function ReadProperties(AOpenState: TOpenState = osEditOnly): ObjDbConvState;
    function IsCorrectBeforeSave(AProps: IProperties; var msg: widestring): boolean;
    procedure SetForcedCloseWithSave(const Value: boolean);
    function GetForcedCloseWithSave: boolean;
    property ForcedCloseWithSave: boolean read GetForcedCloseWithSave write SetForcedCloseWithSave;
    procedure SetForcedCloseNoSave(const Value: boolean);
    function GetForcedCloseNoSave: boolean;
    property ForcedCloseNoSave: boolean read GetForcedCloseNoSave write SetForcedCloseNoSave;
  end;

  IEditPropForm = interface(IInterface)
  ['{C8A3EBEC-3FB0-480F-A82F-9D243E6A936B}']
    function GetListedObject: IListedObject;
    procedure SetListedObject(Value: IListedObject);
    function GetEditedProps: IProperties;
    procedure SetEditedProps(Value: IProperties);
    function GetSavedSuccess: boolean;
    property ListedObject: IListedObject read GetListedObject write SetListedObject;
    property EditedProps: IProperties read GetEditedProps write SetEditedProps;
    property SavedSuccess: boolean read GetSavedSuccess;
    procedure PropToForm;
    procedure FormToProp;
    procedure ShowPropForm;
    procedure Terminate;
    procedure OnOpenInViewMode;
  end;

  IListDataFeeder = interface(IDataFeeder)
  ['{ECA1A085-B561-4983-966B-B413F439FB19}']
    function GetCurrentID: IDentifier;
    procedure SetCurrentID(Value: IDentifier);
    property CurrentID: IDentifier read GetCurrentID write SetCurrentID;
    function GetOnChangedCurrentID: TOnChangedCurrentID;
    procedure SetOnChangedCurrentID(Value: TOnChangedCurrentID);
    property OnChangedCurrentID: TOnChangedCurrentID read GetOnChangedCurrentID write SetOnChangedCurrentID;
    procedure PostInit;
  end;

  IAbstractOM = interface(IInterface)
  ['{CD8E28E9-0367-429B-8FD1-417E9591427F}']
    procedure Init;
  end;

  IDbAwaredOM = interface(IAbstractOM)
  ['{641BA72B-0607-48B5-A488-5A0C500E389A}']
    function GetListSource: TDataSet;
    procedure ProcessDbEvent(EventName: string);
  end;

  IListedOM = interface(IDbAwaredOM)
  ['{403D90C0-0FC6-46CF-80FB-B6F482AF05E3}']
    function GetCurrentID: IDentifier;
    procedure SetCurrentID(Value: IDentifier);
    property CurrentID: IDentifier read GetCurrentID write SetCurrentID;
    function IsRecordPointed: boolean;
  end;

  IEditedOM = interface(IDbAwaredOM)
  ['{D1DF4D0A-C6D4-4FF5-99BD-C6703B7446CC}']
    procedure New;
    procedure Edit;
    procedure Delete;
  end;

  IMasterDrivenObject = interface(IInterface)
  ['{70ADDDBB-2497-45BB-A354-E582BA6DCA47}']
    function GetMasterID: IDentifier;
    procedure SetMasterID(Value: IDentifier);
    property MasterID: IDentifier read GetMasterID write SetMasterID;
  end;

  IMasterDrivenDataFeeder = interface(IListDataFeeder)
  ['{55225B8C-C03E-4AE1-9E8E-10B8142333F0}']
    function GetMasterID: IDentifier;
    procedure SetMasterID(Value: IDentifier);
    property MasterID: IDentifier read GetMasterID write SetMasterID;
  end;

  IMasterDrivenList = interface(IDbAwaredOM)
  ['{7E209D77-9EED-45F9-ACBA-79D083E74721}']
    function GetMasterID: IDentifier;
    procedure SetMasterID(Value: IDentifier);
    property MasterID: IDentifier read GetMasterID write SetMasterID;
    procedure MasterIDChanged(NewMasterIDValue: IDentifier);
  end;

  ICompositedList = interface(IListedOM)
  ['{C9223CC2-5069-443A-9BB9-9EDB46670552}']
    function GetOnNotifySuperModelCurrentIDChanged: TOnNotifySuperModel;
    procedure SetOnNotifySuperModelCurrentIDChanged(Value: TOnNotifySuperModel);
    property OnNotifySuperModelCurrentIDChanged: TOnNotifySuperModel read GetOnNotifySuperModelCurrentIDChanged write SetOnNotifySuperModelCurrentIDChanged;
  end;

  IPatientTransfer = interface(IListedObject)
  ['{A3ACF8B0-458D-483B-9706-4741986BB198}']
    procedure AddToPersistList;
  end;

  IVirtualIDList = interface(IInterface)
  ['{718BA033-F8CA-4A48-AA70-7F5421B0EE8D}']
    function GetID: integer;
    property ID: integer read GetID;
    function GetSrcIdx: integer;
    procedure SetSrcIdx(const Value: integer);
    property SrcIdx: integer read GetSrcIdx write SetSrcIdx;
    function GetOnChangedSrcIdx: TOnChangedSrcIdx;
    procedure SetOnChangedSrcIdx(const Value: TOnChangedSrcIdx);
    property OnChangedSrcIdx: TOnChangedSrcIdx read GetOnChangedSrcIdx write SetOnChangedSrcIdx;
    function GetList: TWideStrings;
    procedure Init;
    function GetOnNotifySuperModelIdChanged: TOnNotifySuperModel;
    procedure SetOnNotifySuperModelIdChanged(Value: TOnNotifySuperModel);
    property OnNotifySuperModelIdChanged: TOnNotifySuperModel read GetOnNotifySuperModelIdChanged write SetOnNotifySuperModelIdChanged;
  end;

  IDirectUserData = interface(IInterface)
  ['{5D318AB9-4FBE-41C3-9158-D064E979A627}']
    function GetUserName: widestring;
    property UserName: widestring read GetUserName;
  end;

  ITransiteDataSet = interface(IInterface)
  ['{1E87D9A0-458F-42E1-AB04-8314A0A6D377}']
    procedure Setds(const Value: TDataSet);
    function Getds: TDataSet;
    property ds: TDataSet read Getds write Setds;
  end;

  IOption = interface(IInterface)
  ['{A3003328-4111-42E6-811A-938CE622CF21}']
    function GetName: string;
    procedure SetName(const Value: string);
    property Name: string read GetName write SetName;
    function GetValue: Variant;
    procedure SetValue(const Value: Variant);
    property Value: Variant read GetValue write SetValue;
  end;

  IOptions = interface(IInterface)
  ['{76F5A705-C068-4717-B483-B0972E95D99F}']
    function GetOptionDef(Name: string; Default: Variant): Variant;
    function GetOption(Name: string): Variant;
    procedure SetOption(Name: string; const Value: Variant);
    property Option[Name: string]: Variant read GetOption write SetOption;
    property OptionDef[Name: string; Default: Variant]: Variant read GetOptionDef; default;
    procedure Load;
    procedure Save;
  end;

  TOnAddNode = procedure (const StructID, ParentStructID: IDentifier; const ADeleted: boolean) of object;
  TOnBuildTree = procedure of object;
  TOnUpdateTree = procedure of object;
  TOnGetName = procedure (const StructID: IDentifier; var Name: widestring) of object;
  IAbstractVTAdapter = interface(IInterface)
  ['{BAF8C81C-9960-4734-BF07-89AA08B5A8BD}']
    procedure SetVT(const Value: TVirtualStringTree);
    function GetVT: TVirtualStringTree;
    property VT: TVirtualStringTree read GetVT write SetVT;
    procedure SetOnGetName(const Value: TOnGetName);
    function GetOnGetName: TOnGetName;
    property OnGetName: TOnGetName read GetOnGetName write SetOnGetName;
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
    function FindNodeByData(const StructID: IDentifier): PVirtualNode;
  end;

implementation

end.

