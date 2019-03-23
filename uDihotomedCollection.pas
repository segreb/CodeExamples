unit uDihotomedCollection;

interface
uses
  Classes;

type
  TSortedFindCompare = function (Data1, Data2: Pointer): integer;
  TIndexedProperty = function:pointer of object;

  TIndexStructure=record
    FList : TList;
    GotoBound: integer;
    CompareFunc: TSortedFindCompare;
    IndexedProperty: TIndexedProperty;
  end;

  TDihotomedItem = class(TCollectionItem)
    destructor Destroy; override;
  end;

  TDihotomedCollection = class(TCollection)
  private
    FIndexCount: integer;
  public
    IndexList: array of TIndexStructure;
    property IndexCount: integer read FIndexCount;
    constructor Create(ItemClass: TCollectionItemClass; IdxCount: integer);
    destructor Destroy; override;

    procedure Delete(Index: Integer); virtual;
    procedure Put(item: TDihotomedItem);
//    function Add: TCollectionItem;
    procedure Clear;

    function RemoveFromIndex(Index: Integer; IndexNumber: integer):boolean;
    function Find(Data: Pointer; IndexNumber: integer;
                  var Position: integer; var ItemIndex: integer):boolean;
    function AddToIndex(Index: Integer; IndexNumber: integer):boolean;
    function BuildIndex(IndexNumber: integer): boolean;
  end;

implementation
uses
  SysUtils;

{ TDihotomedCollection }
constructor TDihotomedCollection.Create(ItemClass: TCollectionItemClass;
                                        IdxCount: integer);
var
  i : integer;
begin
  inherited Create(ItemClass);
  SetLength(IndexList, IdxCount);
  FIndexCount := IdxCount;
  if FIndexCount>0 then
    for i:=Low(IndexList) to High(IndexList) do
      IndexList[i].FList := TList.Create;
end;

destructor TDihotomedCollection.Destroy;
var
  i : integer;
begin
  if FIndexCount>0 then
    for i:=Low(IndexList) to High(IndexList) do
      IndexList[i].FList.Free;
  inherited;
end;

procedure TDihotomedCollection.Delete(Index: Integer);
var
  i : integer;
begin
  if FIndexCount>0 then
    for i:=0 to FIndexCount-1 do
      RemoveFromIndex(Index, i);

  inherited Delete(Index);
end;

procedure TDihotomedCollection.Put(item: TDihotomedItem);
var
  i : integer;
begin
  if FIndexCount>0 then
    for i:=0 to FIndexCount-1 do
      AddToIndex(item.Index, i);
end;


function TDihotomedCollection.RemoveFromIndex(Index: Integer; IndexNumber:integer): boolean;
begin
  IndexList[IndexNumber].FList.Remove(Pointer(Items[Index]));
end;

function TDihotomedCollection.Find(Data: Pointer; IndexNumber: integer;
                                   var Position: integer; var ItemIndex:integer):boolean;
var
  L, H, I, C: Integer;
  Idx: TIndexStructure;
begin
  Result := False;
  Position := -1;
  ItemIndex := -1;

  try
    Idx := IndexList[IndexNumber];

    L := 0;
    H := Idx.FList.Count - 1;
    while L <= H do
    begin
      I := (L + H) shr 1;

      TMethod(IndexList[IndexNumber].IndexedProperty).Data := Idx.FList.Items[I];

      C := Idx.CompareFunc(IndexList[IndexNumber].IndexedProperty,
                           Data);

      if C < 0 then
        L := I + 1
      else if C > 0 then
        H := I - 1
      else
      begin
        Result := True;
        case Idx.GotoBound of
        -1:
          H := I - 1;
        0:
          begin
            L := I;
            H := L-1;
          end;
        1:
          L := I + 1;
        end;
      end;
    end;

    if Result then
    begin
      if (Idx.GotoBound=1) then
        L := L - 1;
      ItemIndex := TCollectionItem(Idx.FList.Items[L]).Index;
    end
    else
      ItemIndex := -1;

    Position := L;
    
  except
    Position := -1;
    Result := False;
  end;
end;

function TDihotomedCollection.AddToIndex(Index: Integer; IndexNumber: integer): boolean;
var
  Position, ItemIndex : integer;
begin
  TMethod(IndexList[IndexNumber].IndexedProperty).Data := Items[Index];

  Find(IndexList[IndexNumber].IndexedProperty,
       IndexNumber,
       Position, ItemIndex);

  IndexList[IndexNumber].FList.Insert(
       Position,
       Pointer(Items[Index]));

end;

function TDihotomedCollection.BuildIndex(IndexNumber: integer): boolean;
var
  i, j : integer;
begin
  if IndexNumber>0 then
  begin
    IndexList[IndexNumber].FList.Clear;
    if Count>0 then
      for i:=0 to Count-1 do
        AddToIndex(i, IndexNumber);
  end
  else
  begin
    for j:=0 to FIndexCount-1 do
      IndexList[j].FList.Clear;
      if Count>0 then
        for i:=0 to Count-1 do
          AddToIndex(i, j);
  end;
end;

procedure TDihotomedCollection.Clear;
var
  i: integer;
begin
  for i:=0 to IndexCount-1 do
    IndexList[i].FList.Clear;
  inherited;
end;

{ TDihotomedItem }

destructor TDihotomedItem.Destroy;
var
  i: integer;
begin
  if Collection<>nil then
    for i:=0 to TDihotomedCollection(Collection).IndexCount-1 do
      if TDihotomedCollection(Collection).IndexList[i].FList.Count>0 then
        TDihotomedCollection(Collection).RemoveFromIndex(Index, i);
  inherited;
end;

end.
