{*******************************************************}
{                                                       }
{       Chart4D Library - Editorial data charts         }
{                                                       }
{          Copyright(c) 2026 GDK Software               }
{                All rights reserved                    }
{                                                       }
{             Licensed under MIT License                }
{                                                       }
{*******************************************************}
unit Chart4D.CategoryLabels.Tests;

/// <summary>
/// Tests for the discrete category axis label layout (<c>XAxis.CategoryLabelLayout</c>):
/// which crowded labels are dropped, which move to a second row, and the room the axis
/// reserves for that row, all against a <c>TRecordingCanvas</c>. See SPEC.md 4.28.
/// </summary>

interface

uses
  System.Types,
  DUnitX.TestFramework,
  Chart4D.Canvas.Interfaces,
  Chart4D.Tests.Asserts,
  Chart4D.Tests.RecordingCanvas,
  Chart4D.Types;

type
  [TestFixture]
  TCategoryLabelLayoutTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    function IsOneOf(const Text: string; const Candidates: TArray<string>): Boolean;
    function LowestBarBottomFor(const Categories: TArray<string>;
                                const Layout: TCategoryLabelLayout): Single;
    function LabelCallsFor(const Categories: TArray<string>): TArray<TCanvasCall>;
    function DistinctRowOffsets(const Calls: TArray<TCanvasCall>; const IsHorizontal: Boolean): TArray<Single>;
    function RowCountOf(const Calls: TArray<TCanvasCall>; const IsHorizontal: Boolean): Integer;
    function DrawnLabelCount(const Categories: TArray<string>): Integer;
    function DrawnLabelCountFor(const Categories: TArray<string>;
                                const Layout: TCategoryLabelLayout): Integer;
    function RowOffsetOf(const Categories: TArray<string>; const LabelText: string): Single;
    function LabelCentreOf(const Categories: TArray<string>; const LabelText: string): Single;
    function DrawnTexts(const Calls: TArray<TCanvasCall>): TArray<string>;
    function UniformCategories(const Count: Integer): TArray<string>;
    function ValuesFor(const Categories: TArray<string>): TArray<Double>;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure DefaultOptions_LeaveTheLayoutSingleRow;

    [Test]
    procedure SingleRowLayout_CrowdedCategories_SkipsTheLabelsThatDoNotFit;

    [Test]
    procedure StaggeredLayout_CrowdedCategories_DrawsEveryLabelAcrossTwoRows;

    [Test]
    procedure StaggeredLayout_CrowdedCategories_KeepsTheRowsOneTextLineApart;

    [Test]
    procedure StaggeredLayout_LabelsThatAllFit_StayOnTheFirstRow;

    [Test]
    procedure StaggeredLayout_SecondRowAlsoFull_SkipsTheLabel;

    [Test]
    procedure SingleRowLayout_TenCountryAxis_KeepsOnlyEveryOtherCountry;

    [Test]
    procedure StaggeredLayout_TenCountryAxis_AlternatesRowsAndLabelsThemAll;

    [Test]
    procedure StaggeredLayout_SecondRowLabel_StaysCentredBetweenItsFirstRowNeighbours;

    [Test]
    procedure StaggeredLayout_SecondRowStaysInsideTheChart;

    [Test]
    procedure StaggeredLayout_ReservesTheSecondRowByShorteningThePlotArea;

    [Test]
    procedure StaggeredLayout_HorizontalChart_DrawsEveryLabelAcrossTwoColumns;

    [Test]
    procedure StaggeredLayout_ContinuousXAxis_KeepsEveryBreakOnOneRow;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  Chart4D.Axis,
  Chart4D.Plot,
  Chart4D.Renderer;

const
  { Wide enough that the "nice" band arithmetic below is worth reasoning about, and the
    size every other renderer fixture uses. }
  ChartWidth = 640;
  ChartHeight = 450;

  { The ten countries and the 2020 emissions series of the demo catalogue
    (Examples\Common\Chart4DDemo.Catalog.pas), repeated here rather than imported: they
    are demo data, free to change, while the expected rows below are pinned to these exact
    label widths. }
  TenCountries: TArray<string> = ['Netherlands', 'Belgium', 'France', 'Germany', 'Italy',
                                  'Poland', 'Portugal', 'Romania', 'Spain', 'Sweden'];
  Emissions2020: TArray<Double> = [8.2, 8.0, 4.2, 7.7, 5.0, 7.9, 3.9, 3.9, 4.5, 3.7];

procedure TCategoryLabelLayoutTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TCategoryLabelLayoutTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

function TCategoryLabelLayoutTests.UniformCategories(const Count: Integer): TArray<string>;
begin
  { Every label the same length, so a label either fits its band or does not and the
    expected row pattern follows from the band width alone. }
  SetLength(Result, Count);
  for var Index := 0 to Count - 1 do
  begin
    Result[Index] := Format('Category%.2d', [Index]);
  end;
end;

function TCategoryLabelLayoutTests.ValuesFor(const Categories: TArray<string>): TArray<Double>;
begin
  SetLength(Result, Length(Categories));
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := 10 + Index;
  end;
end;

function TCategoryLabelLayoutTests.IsOneOf(const Text: string; const Candidates: TArray<string>): Boolean;
begin
  Result := False;
  for var Candidate in Candidates do
  begin
    Result := Result or (Text = Candidate);
  end;
end;

/// <summary>
/// Renders the same plot at the given layout on a canvas of its own and returns the
/// bottom edge of its first bar, which sits on the value axis' zero baseline and so
/// tracks the bottom of the plot area.
/// </summary>
function TCategoryLabelLayoutTests.LowestBarBottomFor(const Categories: TArray<string>;
                                                      const Layout: TCategoryLabelLayout): Single;
begin
  const Canvas = TRecordingCanvas.Create;
  const CanvasReference: IChartCanvas = Canvas;
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := Layout;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, CanvasReference, ChartWidth, ChartHeight);

    Result := Canvas.CallsOfKind(TCanvasCallKind.FillRect)[0].Bounds.Bottom;
  finally
    Plot.Free;
  end;
end;

function TCategoryLabelLayoutTests.LabelCallsFor(const Categories: TArray<string>): TArray<TCanvasCall>;
begin
  { A category axis label is the only text a render draws that reads exactly like one of
    the categories: there is no title, no legend with a single series, and the value axis
    labels are numbers. }
  Result := [];
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    if IsOneOf(Call.Text, Categories) then
      Result := Result + [Call];
  end;
end;

function TCategoryLabelLayoutTests.DrawnTexts(const Calls: TArray<TCanvasCall>): TArray<string>;
begin
  SetLength(Result, Length(Calls));
  for var Index := 0 to High(Calls) do
  begin
    Result[Index] := Calls[Index].Text;
  end;
end;

function TCategoryLabelLayoutTests.DistinctRowOffsets(const Calls: TArray<TCanvasCall>;
                                                      const IsHorizontal: Boolean): TArray<Single>;
begin
  Result := [];
  for var Call in Calls do
  begin
    var Offset := Call.TextY;
    if IsHorizontal then
      Offset := Call.TextX;

    var IsKnown := False;
    for var Known in Result do
    begin
      IsKnown := IsKnown or SameValue(Known, Offset, 0.01);
    end;

    if not IsKnown then
      Result := Result + [Offset];
  end;
end;

function TCategoryLabelLayoutTests.RowCountOf(const Calls: TArray<TCanvasCall>;
                                              const IsHorizontal: Boolean): Integer;
begin
  Result := Length(DistinctRowOffsets(Calls, IsHorizontal));
end;

function TCategoryLabelLayoutTests.DrawnLabelCount(const Categories: TArray<string>): Integer;
begin
  Result := Length(LabelCallsFor(Categories));
end;

/// <summary>
/// Renders the same plot at the given layout on a canvas of its own and counts the
/// category labels that survived, so two layouts can be compared on the same data.
/// </summary>
function TCategoryLabelLayoutTests.DrawnLabelCountFor(const Categories: TArray<string>;
                                                      const Layout: TCategoryLabelLayout): Integer;
begin
  const Canvas = TRecordingCanvas.Create;
  const CanvasReference: IChartCanvas = Canvas;
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := Layout;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, CanvasReference, ChartWidth, ChartHeight);

    Result := 0;
    for var Call in Canvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if IsOneOf(Call.Text, Categories) then
        Inc(Result);
    end;
  finally
    Plot.Free;
  end;
end;

function TCategoryLabelLayoutTests.RowOffsetOf(const Categories: TArray<string>;
                                               const LabelText: string): Single;
begin
  for var Call in LabelCallsFor(Categories) do
  begin
    if Call.Text = LabelText then
      Exit(Call.TextY);
  end;

  Assert.Fail(Format('The label "%s" was not drawn', [LabelText]));
  Result := 0;
end;

/// <summary>
/// The anchor a vertical chart's category label is centred on, which is its own band's
/// centre whichever row the label landed on.
/// </summary>
function TCategoryLabelLayoutTests.LabelCentreOf(const Categories: TArray<string>;
                                                 const LabelText: string): Single;
begin
  for var Call in LabelCallsFor(Categories) do
  begin
    if Call.Text = LabelText then
    begin
      Assert.IsTrue(Call.AlignH = TTextAlignH.Center,
        Format('The label "%s" must be centre-aligned on its band', [LabelText]));
      Exit(Call.TextX);
    end;
  end;

  Assert.Fail(Format('The label "%s" was not drawn', [LabelText]));
  Result := 0;
end;

procedure TCategoryLabelLayoutTests.DefaultOptions_LeaveTheLayoutSingleRow;
begin
  const Options = TAxisOptions.Default;

  Assert.IsTrue(Options.CategoryLabelLayout = TCategoryLabelLayout.SingleRow,
    'A chart must keep the single-row axis it always had until a caller opts in');
end;

procedure TCategoryLabelLayoutTests.SingleRowLayout_CrowdedCategories_SkipsTheLabelsThatDoNotFit;
begin
  const Categories = UniformCategories(6);
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const Calls = LabelCallsFor(Categories);
    Assert.IsTrue(Length(Calls) < Length(Categories),
      'These labels are too wide for their bands, so the single-row axis must drop some');
    Assert.AreEqual(1, RowCountOf(Calls, False),
      'The single-row axis must keep every label it does draw on one row');
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_CrowdedCategories_DrawsEveryLabelAcrossTwoRows;
begin
  const Categories = UniformCategories(6);
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const Calls = LabelCallsFor(Categories);
    Assert.AreEqual(Length(Categories), Length(Calls),
      'Each of these labels fits beside the one two bands away, so a second row saves all of them');
    Assert.AreEqual(2, RowCountOf(Calls, False),
      'The saved labels must sit on exactly two rows');
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_CrowdedCategories_KeepsTheRowsOneTextLineApart;
begin
  const Categories = UniformCategories(6);
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const Calls = LabelCallsFor(Categories);
    const Rows = DistinctRowOffsets(Calls, False);
    Assert.AreEqual(2, RowCountOf(Calls, False));

    const LineHeight = FRecordingCanvas.MeasureText('0', Calls[0].TextStyle).Height;
    const RowGap = Abs(Rows[1] - Rows[0]);
    Assert.IsTrue(RowGap >= LineHeight,
      'The second row must clear the first by at least a line of text, or the two would collide');
    Assert.IsTrue(RowGap < 2 * LineHeight,
      'The second row must be the next line down, not a line adrift from the axis');
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_LabelsThatAllFit_StayOnTheFirstRow;
begin
  const Categories: TArray<string> = ['A', 'B', 'C'];
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const Calls = LabelCallsFor(Categories);
    Assert.AreEqual(Length(Categories), Length(Calls));
    Assert.AreEqual(1, RowCountOf(Calls, False),
      'A second row is for labels that need it; roomy labels must not be pushed down');
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_SecondRowAlsoFull_SkipsTheLabel;
begin
  { Twelve of these labels in the same width leaves a band narrower than half a label, so
    even the neighbour two bands away collides and the second row runs out of room too. }
  const Categories = UniformCategories(12);

  const SingleRowCount = DrawnLabelCountFor(Categories, TCategoryLabelLayout.SingleRow);
  const StaggeredCount = DrawnLabelCountFor(Categories, TCategoryLabelLayout.Staggered);

  Assert.IsTrue(StaggeredCount < Length(Categories),
    'A label that fits neither row must be dropped, exactly as the single-row axis drops it');
  Assert.IsTrue(StaggeredCount > SingleRowCount,
    'The second row must still rescue the labels that do fit it, or it earns nothing');
end;

procedure TCategoryLabelLayoutTests.SingleRowLayout_TenCountryAxis_KeepsOnlyEveryOtherCountry;
begin
  { The other half of the worked example of SPEC.md 4.28, which names these five as the
    ones a single row has to drop. Every adjacent pair of these names collides at this
    width, so the walk can never keep two in a row. }
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := TenCountries;
    Plot.AddSeries('2020', Emissions2020);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const Kept = DrawnTexts(LabelCallsFor(TenCountries));
    Assert.AreEqual(5, DrawnLabelCount(TenCountries), 'A single row holds only half of these names');

    for var Index := 0 to High(TenCountries) do
    begin
      const IsKept = IsOneOf(TenCountries[Index], Kept);
      const ShouldBeKept = (Index mod 2 = 0);

      Assert.AreEqual(ShouldBeKept, IsKept,
        Format('%s must be %s by the single-row axis',
               [TenCountries[Index], BoolToStr(ShouldBeKept, True)]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_TenCountryAxis_AlternatesRowsAndLabelsThemAll;
begin
  { The worked example of SPEC.md 4.28: the ten countries the demo catalogue charts. The
    band is 55.7 px and the narrowest pair of neighbours needs 59.4, so every adjacent
    pair collides and one row can hold only every other name; two bands apart the widest
    pair needs 91.8 against 111.4, so the second row takes all five it dropped. The left
    end of that axis, to scale at one character per 11 px:

      Netherlands  France     Italy
             Belgium    Germany                                                        }
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := TenCountries;
    Plot.AddSeries('2020', Emissions2020);

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    Assert.AreEqual(DrawnLabelCount(TenCountries), Length(TenCountries),
      'A second row leaves room for all ten country names');

    const FirstRow = RowOffsetOf(TenCountries, 'Netherlands');
    for var Index := 0 to High(TenCountries) do
    begin
      const Offset = RowOffsetOf(TenCountries, TenCountries[Index]);
      const IsFirstRow = SameValue(Offset, FirstRow, 0.01);
      const BelongsOnFirstRow = (Index mod 2 = 0);

      Assert.AreEqual(BelongsOnFirstRow, IsFirstRow,
        Format('%s must land on row %d', [TenCountries[Index], Ord(not BelongsOnFirstRow)]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_SecondRowLabel_StaysCentredBetweenItsFirstRowNeighbours;
begin
  { A second row moves a label down, never sideways: it stays centred on its own band, so
    it reads as belonging between the two first-row labels on either side of it and not
    as an offset copy of either one. }
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := TenCountries;
    Plot.AddSeries('2020', Emissions2020);

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    for var Index := 1 to High(TenCountries) - 1 do
    begin
      const IsSecondRow = (Index mod 2 = 1);
      if not IsSecondRow then
        Continue;

      const Centre = LabelCentreOf(TenCountries, TenCountries[Index]);
      const LeftNeighbour = LabelCentreOf(TenCountries, TenCountries[Index - 1]);
      const RightNeighbour = LabelCentreOf(TenCountries, TenCountries[Index + 1]);

      Assert.IsTrue((Centre > LeftNeighbour) and (Centre < RightNeighbour),
        Format('%s must sit between %s and %s, not beside either of them',
               [TenCountries[Index], TenCountries[Index - 1], TenCountries[Index + 1]]));

      const DistanceToLeft = Centre - LeftNeighbour;
      const DistanceToRight = RightNeighbour - Centre;
      Assert.AreEqual(DistanceToLeft, DistanceToRight, 0.01,
        Format('%s must sit midway between them, one band from each', [TenCountries[Index]]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_SecondRowStaysInsideTheChart;
begin
  const Categories = UniformCategories(6);
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const Calls = LabelCallsFor(Categories);
    const LineHeight = FRecordingCanvas.MeasureText('0', Calls[0].TextStyle).Height;
    for var Call in Calls do
    begin
      Assert.IsTrue(Call.TextY + LineHeight <= ChartHeight,
        Format('The label "%s" must not run off the bottom of the chart', [Call.Text]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_ReservesTheSecondRowByShorteningThePlotArea;
begin
  const Categories = UniformCategories(6);

  const SingleRowBaseline = LowestBarBottomFor(Categories, TCategoryLabelLayout.SingleRow);
  const StaggeredBaseline = LowestBarBottomFor(Categories, TCategoryLabelLayout.Staggered);

  Assert.IsTrue(StaggeredBaseline < SingleRowBaseline,
    'The extra row is paid for out of the plot area, not drawn over the footer');
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_HorizontalChart_DrawsEveryLabelAcrossTwoColumns;
begin
  { A horizontal chart stacks its categories down the left edge, where the scarce
    dimension is height, so twenty of them crowd on line height alone and the second
    "row" is a column further from the plot. }
  const Categories = UniformCategories(20);
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Orientation := TChartOrientation.Horizontal;
    Plot.Categories := Categories;
    Plot.AddSeries('Only', ValuesFor(Categories));

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const Calls = LabelCallsFor(Categories);
    Assert.AreEqual(Length(Categories), Length(Calls),
      'A second column saves every label a single column had to drop');

    Assert.AreEqual(2, RowCountOf(Calls, True), 'The labels must sit in exactly two columns');
    for var Call in Calls do
    begin
      Assert.IsTrue(Call.TextX > 0, 'A second column must not run off the left of the chart');
    end;
  finally
    Plot.Free;
  end;
end;

procedure TCategoryLabelLayoutTests.StaggeredLayout_ContinuousXAxis_KeepsEveryBreakOnOneRow;
begin
  { A continuous X axis spaces its breaks to fit by construction, so it has nothing to
    stagger and must ignore the setting rather than reserve a row it never uses. }
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Line;
    Plot.AddLineSeries('Only', [1950, 1960, 1970, 1980, 1990], [10, 20, 30, 40, 50]);

    var AxisOptions := Plot.XAxis;
    AxisOptions.CategoryLabelLayout := TCategoryLabelLayout.Staggered;
    Plot.XAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    const BreakLabels: TArray<string> = ['1950', '1960', '1970', '1980', '1990'];
    const Calls = LabelCallsFor(BreakLabels);
    Assert.IsTrue(Length(Calls) > 1, 'The continuous axis must still label its breaks');
    Assert.AreEqual(1, RowCountOf(Calls, False),
      'Every break label stays on the one row a continuous axis has');
  finally
    Plot.Free;
  end;
end;

end.
