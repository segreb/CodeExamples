The most "scientific" example - collection of objects with external indices. 
Say, objects have a number of scalar properties, whose values are 
unique inside some ranges. For example, color and coordinates in space. 
Indices allow search object with specified color or coordinates.
Searching is based on dichotomy. See uDihotomedCollection.pas. 
TDihotomedCollection - the colection. 
TDihotomedCollection.IndexList - list of indices for various properties.
Say, TDihotomedCollection.IndexList[0] - index for colors, 
TDihotomedCollection.IndexList[1] - for coordinates.

At the second, my 2D-graphics experiments. 
You can see it at https://paving-expert.com. 
In this project I works with GDI+. Transformations, pathes, regions, 
drawing, grafic objects impact, calculations of object's crossing, etc. 
At https://paving-expert.com/2.0/help/index.html?newin22.html
and https://paving-expert.com/2.0/tipsntricks/tipsntricks.html 
you can view application description and evaluate amount of work.

My another works are usual everyday routines. I start develop custom CRM- 
and ERP-like applications in 2003. I use Firebird. And for purposes of 
processing CRUD-operations in Firebird, I developed my own "framework". 
Two main concepts was implemented: the "list" and the "item". 
"List" is a collection of "items", serves as starting point for CRUD of "items". 
1) "List" is dataset, shown in db-grid. It consist of some model and data provider. 
Model stores primary key ID from current record in dataset and calls CRUD methods.
Data provider interacts with database. I can use the same model with 
another data provider. For example, if I have model and data provider for doctors, 
and want to make the same for assistants, I may use doctor's model (ok, successor 
of doctors with minor changes) and new data provider.
You can see it in DentalObjectModels.pas and DentalDataFeeders.pas.
"List" model: TAbstractOM -> TDbAwaredOM -> TListedOM.
"List" data provider: TBaseDataFeeder -> TListedDataFeeder.
2) "Item" is a single record from table, which can be edited in its 
specific window. Model, data provider, and yet another entity - properties. 
Model reads data from data provider, creates window, fills window's controls 
with properties values, controls either user saves or discards changes in
windows, and saves properties in table. 
It is not so good as "list". I can combine model with data providers. 
But, entity "properties" are redundant. It is inseparable from data provider. 
I fixed this "design fault" in later version, but still have opportunities 
for further improvement. See same files DentalObjectModels.pas and DentalDataFeeders.pas.
"Item" model: TAbstractOM -> TDbAwaredOM -> TListedObject.
"Item" data provider: TBaseDataFeeder -> TRWDataFeeder.
"Item" properties: have no base implementation. For every model it is 
succesor of TInterfacesObject
implemented interface IProperties (single method - function Clone: IProperties)
